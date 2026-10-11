# W3-02: UI: purchases and banking screens

## Goal

Build the purchases screens (`pages/purchases/`) and the banking screens (`pages/banking/`: review queue, rules, reconcile, deposits, transfers, imports, feeds) for keyboard-first daily bookkeeping, with an end-to-end test from statement import to a finished reconciliation.

## Wave and concurrency

- Wave 3, batch B (with W3-01). Paths do not overlap.
- Agent: `ui-engineer`.
- Timebox: three sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/ui/src/pages/purchases/**`, `crates/ui/src/pages/banking/**`, `tests/e2e/tests/ui_purchases_banking.rs`
- `docs/coordination/CCR/CCR-W3-02-*.md`, `docs/coordination/handoffs/W3-02.md`

Read-only: everything else, including the shared UI modules and the e2e harness.

## Read first

1. `CLAUDE.md` and `.claude/agents/ui-engineer.md`.
2. `docs/architecture/ARCHITECTURE.md` §10 and §11.
3. `docs/architecture/API.md` §5.3 (bank rules), §5.4 (purchase, deposit and transfer endpoints) and §5.5.
4. `docs/architecture/LEDGER_SPEC.md` §4.8–§4.15 and §11.
5. The merged `crates/ui` and `tests/e2e/src/`.

## Preconditions

| Precondition | Check |
|---|---|
| Weave 2 is merged | `git log origin/main --format=%s \| grep -q '^Weave 2: '` |
| The banking routes are registered in the UI | `git show origin/main:crates/ui/src/routes.rs \| grep -q 'banking/reconcile'` |

## Scope in/out

In:

- **Purchases:** lists and editors for bills, bill payments (apply to bills and vendor credits, check number, pay from bank or card), expenses (payee, payment account, account lines with tags, AR or AP lines with a contact), vendor credits, card credits and vendor refunds; save, post, repost, void; draft approval as in sales.
- **To review:** lines awaiting review per account with suggestions; match, add (expense, deposit or transfer with account, contact, memo, tags), exclude and undo, all from the keyboard; the rule suggestion shown with the line.
- **Rules:** list, create and edit conditions and actions, priority, auto-add, preview of matching lines.
- **Reconcile:** start (account, statement date, ending balance), candidates list where `Space` ticks and unticks, running cleared total and difference, complete when the difference is 0.00, undo the latest with a reason, unreconcile a single line with a reason, discrepancy indicator on an older reconciliation.
- **Deposits** (choose undeposited payments and receipts, add other lines) and **transfers**.
- **Imports:** upload OFX, QFX, QBO or CSV; for CSV, a column-mapping step previewing the first 50 rows and saving the mapping by name; the result (imported and duplicate counts, errors).
- **Feeds:** the SimpleFIN connection form and the list of linked accounts; until W4-05 merges, the page shows the API's "not implemented" error gracefully.
- **`tests/e2e/tests/ui_purchases_banking.rs`:** by keyboard only, import the spine statement, match a line to an existing payment, add the 15.00 fee line as an expense, and reconcile Checking to a 0.00 difference.

Out: printing (W5-03), live feed internals (W4-05), new shared components (CCR).

## Tasks

1. Purchases lists and editors.
2. To review and rules.
3. Reconcile.
4. Deposits, transfers, imports, feeds.
5. Native tests and the end-to-end test.

## Invariants touched

| Invariant | How |
|---|---|
| I-1 | amounts as decimal strings; reconciliation difference computed with `money` (native test) |
| I-7 | the import result shows duplicates instead of re-adding them (e2e re-import shows 0 new lines) |
| I-10 | approval offered only to users who may post |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | The keyboard-only banking flow works | `cargo xtask e2e --web` passes `ui_purchases_banking.rs` |
| AC-2 | The reconcile screen's difference is exact | native test: ticking the nine March lines from 12,500.00 toward 17,835.00 ends at 0.00 |
| AC-3 | Re-import shows duplicates | the e2e test imports the same file twice; the second result shows 0 imported and 9 duplicates |
| AC-4 | CSV mapping preview | native test of the mapping view model: column choices, debit and credit columns, a saved mapping reapplied |
| AC-5 | Every purchases and banking route in ARCHITECTURE §10.2 renders a real screen | native test over the components named in `routes.rs` |
| AC-6 | Accessibility basics hold on these screens | the e2e test checks accessible names on inputs and `role="grid"` on the candidates table |
| AC-7 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W3-02` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-ui --all-targets -- -D warnings
cargo check --locked -p bookscraft-ui --target wasm32-unknown-unknown
cargo test --locked -p bookscraft-ui
cargo xtask ui build
cargo xtask e2e --web
cargo xtask lint
cargo xtask scope W3-02
```

## Deliverables

- Branch: `wp/W3-02-ui-purchases-banking`
- PR title: `W3-02: Purchases and banking screens`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work.
- The API lacks something a screen needs: raise a CCR naming the endpoint and fields.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
