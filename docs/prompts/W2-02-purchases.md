# W2-02: Purchases service and routes

## Goal

Implement `PurchasesService` in `crates/purchases` (bills, bill payments with the application graph, vendor credits, expenses and checks, card credits, vendor refunds, open items) and its HTTP routes in `crates/api/src/routes/purchases.rs`.

## Wave and concurrency

- Wave 2, batch A (with W2-01 and W2-03). Paths do not overlap.
- Agent: `ledger-engineer`.
- Timebox: two sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/purchases/src/**`, `crates/purchases/tests/**`, `crates/api/src/routes/purchases.rs`
- `docs/coordination/CCR/CCR-W2-02-*.md`, `docs/coordination/handoffs/W2-02.md`

Read-only: everything else, including `crates/books`, `crates/posting`, `crates/store` and `crates/api/src/routes/mod.rs`.

## Read first

1. `CLAUDE.md` and `.claude/agents/ledger-engineer.md`.
2. `docs/architecture/LEDGER_SPEC.md` §4.8–§4.13, §5, §6, §8.1, and Appendix A steps S04, S07, S09, S12, S13, S18, S19, S25, S28.
3. `docs/architecture/DATA_MODEL.md` §4.
4. `docs/architecture/API.md` §5.3 (contact open items), §5.4 (typed purchase endpoints and the agent column), §7.1.
5. `docs/architecture/ARCHITECTURE.md` §4.6.
6. The merged `crates/books` helpers and `crates/api/src/routes/` patterns.

## Preconditions

| Precondition | Check |
|---|---|
| Weave 1 is merged | `git log origin/main --format=%s \| grep -q '^Weave 1: '` |
| The purchases route module is pre-registered | `git show origin/main:crates/api/src/routes/purchases.rs > /dev/null` |

## Scope in/out

In:

- **Documents:** bills, bill payments (by check from a bank account, or from a credit card; check number in `reference_number`), vendor credits, expenses (cash, check or card; AR or AP lines allowed with a line contact), card credits, vendor refunds; save, update, post, repost and void through `posting::post` and `store::ledger::post_revision`, with number sequences and audit.
- **Bill payments:** applications to bills, vendor credits applied in the same event, unapplied remainder, zero-amount payments that only apply credits, `purchases.application_exceeds_open`, `purchases.application_mismatch`.
- **Vendor refunds** against open vendor credits.
- **Edit and void rules** as in sales: open amounts stay at zero or more; `document.has_active_settlements` when others settled the document.
- **Open items** per vendor, serving `GET /contacts/{id}/open-items?ledger=ap`.
- **Agent rule:** agents may create drafts of bills, vendor credits, expenses and card credits only (API.md §5.4); bill payments and vendor refunds never.
- **Routes:** `/bills`, `/bill-payments`, `/vendor-credits`, `/expenses`, `/card-credits`, `/vendor-refunds` with permissions and OpenAPI metadata.
- **Capabilities:** `Bills`, `BillPayments`, `VendorCredits`, `Expenses`, `CardCredits`, `VendorRefunds`, each only when complete and tested.

Out: purchase orders (later), bill pay or any money movement (I-11), UI (W3-02).

## Tasks

1. Bills and vendor credits.
2. Bill payments with settlements; vendor refunds.
3. Expenses (including AR/AP lines) and card credits.
4. Reposts, voids, open items.
5. Routes with contract tests; capabilities; spine.

## Invariants touched

| Invariant | Test |
|---|---|
| I-3 | voids are reversals; the EXP-01 edit writes original, reversal and revision 2 |
| I-6 | T-AUDIT-1 on every mutating command |
| I-10 | agent drafts only; agent post refused |
| I-11 | no payment-sending feature exists (reviewed; T-SCOPE-1 covers the routes) |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | BP-02 applies a 200.00 check and VC-01's 40.00 to BILL-2001 (240.00), leaving it fully paid, and posts AP 200.00 Dr / Checking 200.00 Cr | service test |
| AC-2 | The EXP-01 typo fix (spine S13) leaves three entries: original 186.40, its reversal, revision 2 at 168.40 | service test |
| AC-3 | Settlement rules | tests: over-application refused with `purchases.application_exceeds_open`; another vendor's bill refused with `purchases.application_mismatch`; a zero-amount payment applying a vendor credit writes no journal entry |
| AC-4 | An expense line to AP without a contact is refused | test |
| AC-5 | Agent rule | tests: an agent creates a draft expense (as in S28); its post fails with `auth.agent_forbidden`; creating a bill payment fails with `auth.agent_forbidden`; the owner approves the draft |
| AC-6 | T-AUDIT-1 | `assert_audited` in each mutating command's test |
| AC-7 | Routes behave per API.md | contract tests per endpoint |
| AC-8 | No spine regression | `cargo xtask spine` reports 0 failed |
| AC-9 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W2-02` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-purchases -p bookscraft-api --all-targets -- -D warnings
cargo test --locked -p bookscraft-purchases -p bookscraft-api
cargo xtask lint
cargo xtask spine
cargo xtask scope W2-02
```

Do not commit `docs/architecture/openapi.json` or `error-codes.md`: Weave 2 regenerates them.

## Deliverables

- Branch: `wp/W2-02-purchases`
- PR title: `W2-02: Purchases service and routes`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work.
- A spine step fails and the cause is outside `purchases`: raise a CCR with the failing output.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
