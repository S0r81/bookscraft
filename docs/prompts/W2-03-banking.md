# W2-03: Banking: deposits, transfers, statement import, review, rules, reconciliation

## Goal

Implement `BankingService` in `crates/banking` (deposits from undeposited funds, transfers, statement import with dedupe, the review queue, bank rules, reconciliation and clearing) and its HTTP routes in `crates/api/src/routes/banking.rs`.

## Wave and concurrency

- Wave 2, batch A (with W2-01 and W2-02). Paths do not overlap. Live feeds come later (W4-05, inside `crates/banking/src/feeds/`): `BankingService`'s bank-feed operations and its `bank_sync` job handler delegate to functions in `feeds/mod.rs` that return `api.not_implemented` for W4-05 to fill in, each taking `&Ctx`, the service's `Stores` and `Infra`, and the operation's command or the job, so W4-05 never needs to change their signatures; `providers()` keeps returning an empty list.
- Agent: `bank-feeds-engineer`.
- Timebox: three sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/banking/src/**`, `crates/banking/tests/**`, `crates/api/src/routes/banking.rs`
- `docs/coordination/CCR/CCR-W2-03-*.md`, `docs/coordination/handoffs/W2-03.md`

Read-only: everything else, including `crates/ofx` (use its parser), `crates/books`, `crates/store` (its write path already enforces the reconciled-line rule).

## Read first

1. `CLAUDE.md` and `.claude/agents/bank-feeds-engineer.md`.
2. `docs/architecture/LEDGER_SPEC.md` §4.14, §4.15, §11, §13 (T-BANK-*, L-2..L-4), and Appendix A steps S05, S11, S21, S23, S24, S27–S29.
3. `docs/architecture/DATA_MODEL.md` §3 (banking tables) and §5.
4. `docs/architecture/API.md` §5.3 (bank rules as a list resource), §5.4 (`deposits`, `transfers`), §5.5.
5. ADR-0009 and ADR-0018.
6. The merged `crates/ofx`, `crates/books` helpers and `crates/api/src/routes/` patterns.

## Preconditions

| Precondition | Check |
|---|---|
| Weave 1 is merged | `git log origin/main --format=%s \| grep -q '^Weave 1: '` |
| The OFX parser is merged | `git log origin/main --format=%s \| grep -q '^W1-04: '` |
| The banking route module is pre-registered | `git show origin/main:crates/api/src/routes/banking.rs > /dev/null` |

## Scope in/out

In:

- **Deposits** (§4.14): `deposit_source` lines for posted customer payments, sales receipts and vendor refunds whose money account is undeposited funds, plus other lines; a source in at most one posted deposit (`banking.already_deposited`).
- **Transfers** (§4.15), including credit card payments.
- **Statement import:** OFX, QFX and QBO through the `ofx` crate; CSV with a column mapping (date, amount or debit and credit, description, optional reference); 10 MB limit; dedupe by FITID or provider id, else by `dedupe_hash` with ordinal (§11); a re-import inserts nothing and reports the duplicates.
- **Review queue:** list with suggestions ranked by amount equality, then date distance (10 days or less), then payee or reference similarity; match (to an existing money-side posting of the same account and amount); add (create and post an expense, deposit or transfer from the line, or a draft when the actor is an agent); exclude; undo (undoing an add voids the created document); every action appended to `bank_txn_action`; match and add append a `cleared` clearing event.
- **Bank rules:** CRUD (the `bank-rules` list resource), ascending priority, first match wins, conditions and actions of §11, `auto_add` executed as the rule's author with `via = job`, preview.
- **Reconciliation:** start (one in progress per account; beginning balance from the last completed one), tick and untick, update, complete only at a zero difference (`reconciliation.difference_not_zero`) with frozen lines and `snapshot_hash`, undo the latest with a reason, discard an in-progress one, unreconcile a single line with a reason.
- **Routes:** `/deposits`, `/transfers`, `/bank-imports`, `/bank-transactions` (with match, add, exclude, undo), `/bank-rules` (with preview), `/reconciliations` (with ticks, complete, undo), `/clearing/unreconcile`, with permissions and OpenAPI metadata.
- **Capabilities:** `Deposits`, `Transfers`, `BankImport`, `BankReview`, `BankRules`, `Reconciliation`, each only when complete and tested.

Out: live bank feeds and credentials (W4-05), UI (W3-02).

## Tasks

1. Deposits and transfers.
2. Statement import with dedupe.
3. Review queue and rules.
4. Reconciliation and clearing.
5. Routes with contract tests; capabilities; spine.

## Invariants touched

| Invariant | Test |
|---|---|
| I-3 | clearing events and reconciliation lines are append-only (store triggers); undo of an add voids by reversal |
| I-6 | T-AUDIT-1 on every mutating command |
| I-7 | T-BANK-1: re-importing an OFX file inserts no lines; CSV lines without an id dedupe by hash and ordinal |
| I-10 | an agent's add creates a draft only; agent match, exclude, undo and reconciliation fail with `auth.agent_forbidden` |
| — | T-BANK-2 (L-2), T-BANK-3 (L-3), T-BANK-4 (L-4) |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | T-BANK-1 | tests: importing `tests/scenarios/fixtures/checking-2026-03.ofx` twice adds nine lines, then zero; a CSV with two identical rows keeps both (ordinals 0 and 1) and a re-import adds none |
| AC-2 | T-BANK-2 (L-2): a deposit's money posting equals its sources plus other lines; a source already in a posted deposit is refused with `banking.already_deposited` | tests |
| AC-3 | T-BANK-3 (L-3): completing needs a zero difference, and the stored `snapshot_hash` recomputes from the frozen lines | tests |
| AC-4 | T-BANK-4 (L-4): reposting a document whose reconciled money line changes is refused with `reconciliation.reconciled_line_changed`; after unreconciling that line with a reason, the repost succeeds and the old reconciliation shows as discrepant | tests |
| AC-5 | The S29 numbers reproduce | test builds Checking's opening balance and March activity from journal entries and transfers with the Appendix A amounts (sales and purchases documents are not available to this WP), imports the spine statement, matches the nine lines and reconciles: beginning 12,500.00, cleared 5,335.00, ending 17,835.00, difference 0.00, and a 1,500.00 payment (check 1044) left outstanding |
| AC-6 | Review actions | tests: suggestion ranking; match; add (posted for a person, draft for an agent); exclude; undo of an add voids the document; each action in `bank_txn_action` |
| AC-7 | Rules | tests: priority order and first match; an `auto_add` rule adds as its author with `via = job`; preview lists the matching lines |
| AC-8 | T-AUDIT-1 | `assert_audited` in each mutating command's test |
| AC-9 | Routes behave per API.md | contract tests per endpoint |
| AC-10 | No spine regression | `cargo xtask spine` reports 0 failed |
| AC-11 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W2-03` exit 0 |
| AC-12 | Feed operations are placeholders for W4-05 | test in `crates/banking/tests/feeds_placeholder.rs` (W4-05 owns and replaces it): each bank-feed operation and a `bank_sync` job return `api.not_implemented`, through functions in `feeds/mod.rs` |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-banking -p bookscraft-api --all-targets -- -D warnings
cargo test --locked -p bookscraft-banking -p bookscraft-api
cargo xtask lint
cargo xtask spine
cargo xtask scope W2-03
```

Do not commit `docs/architecture/openapi.json` or `error-codes.md`: Weave 2 regenerates them.

## Deliverables

- Branch: `wp/W2-03-banking`
- PR title: `W2-03: Banking, statement import, review and reconciliation`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work.
- The store's write path does not enforce the reconciled-line rule as LEDGER_SPEC §11 says: raise a CCR with a failing test.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
