# W2-04: Reports engine and routes

## Goal

Implement `ReportsService` in `crates/reports`: one engine over the ledger that produces the trial balance, profit and loss, balance sheet, general ledger, journal, AR and AP aging, sales tax liability and the audit log, on accrual and derived cash basis, as JSON-ready results and CSV, with its routes in `crates/api/src/routes/reports.rs`.

## Wave and concurrency

- Wave 2, batch B (with W2-05). Paths do not overlap.
- Agent: `ledger-engineer`.
- Timebox: two sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/reports/src/**`, `crates/reports/tests/**`, `crates/api/src/routes/reports.rs`
- `docs/coordination/CCR/CCR-W2-04-*.md`, `docs/coordination/handoffs/W2-04.md`

Read-only: everything else.

## Read first

1. `CLAUDE.md` and `.claude/agents/ledger-engineer.md`.
2. `docs/architecture/LEDGER_SPEC.md` §5 (open amounts), §7 (cash basis, `allocate`), §9 (retained earnings, fiscal years), §12 (report definitions), §13 (T-REP-1), and Appendix A's expected reports.
3. `docs/architecture/DATA_MODEL.md` §3 (views `ledger_line`, `active_settlement`).
4. `docs/architecture/API.md` §5.6 (parameters and response shapes, CSV by `Accept`).
5. ADR-0010 and ADR-0015.
6. The merged `crates/domain/src/reports.rs` result types and `crates/store` read API.

## Preconditions

| Precondition | Check |
|---|---|
| Weave 1 is merged | `git log origin/main --format=%s \| grep -q '^Weave 1: '` |
| The reports route module is pre-registered | `git show origin/main:crates/api/src/routes/reports.rs > /dev/null` |

## Scope in/out

In:

- **Engine:** queries over `ledger_line`, `active_settlement` and the document tables only; nothing derived is stored. Group by account, month or dimension value; dimension filters (`dim[<id>]=<value>`); comparison columns (previous period, previous year).
- **Accrual reports:** trial balance as of a date (prior fiscal years' income and expense folded into Retained Earnings); profit and loss for a range; balance sheet as of a date with Retained Earnings and Net income computed and `assets = liabilities + equity` asserted on every run; general ledger with running balances; journal grouped by document (voided documents shown with their reversal); AR and AP aging (current, 1–30, 31–60, 61–90, 91+ by due date; credits negative by document date; summary and detail); sales tax liability by agency (base and tax from `document_tax_line`, payments as debits to the liability account, balance from the ledger); audit log query with filters.
- **Cash basis** (LEDGER_SPEC §7): classify documents; recognize accrual documents through their active settlements with cumulative allocation of the signed running total; offsetting documents (`W = 0`) and their report line; the unapplied customer and vendor payment lines; cash-basis versions of the trial balance, profit and loss, balance sheet, general ledger and sales tax liability (the journal and the agings have no basis).
- **CSV** for every report.
- **Routes:** every path in API.md §5.6 with `basis`, dimension filters, `Accept: text/csv`; permission `reports.read` (`audit.read` for audit events); agents may read reports with `reports:read` but never audit events.
- **Capability:** `Reports` when complete and tested.

Out: report builder and dashboards (v1), cash-flow statement (v1), printing reports (W5-03; there is no report PDF endpoint in MVP), UI (W4-01).

## Tasks

1. Engine and the accrual reports.
2. Cash-basis recognition.
3. Aging, sales tax liability, audit log.
4. CSV; routes with contract tests; capability.

Tests build their data through `books` (journal entries, opening balances) and, for documents with AR or AP, through `posting::post` plus `store::ledger::post_revision` with settlement rows (sales and purchases are concurrent work packages, so do not depend on them).

## Invariants touched

| Invariant | Test |
|---|---|
| I-4 | T-REP-1: no table or column stores cash-basis amounts (schema scan); the cash-basis trial balance balances as of every date, including between settlements; a fully settled document recognizes exactly its accrual amounts (proptest whose generator includes mixed AR/AP and `W = 0` documents) |
| I-3 | the balance sheet check `assets = liabilities + equity` runs on every report (tests on random ledgers) |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | T-REP-1 | schema scan test plus a proptest of random documents and settlements (1,000 cases) |
| AC-2 | Cash recognition reproduces the LEDGER_SPEC §7 example | test: INV-1002 (5,097.70) with a 2,500.00 settlement on 2026-03-13 recognizes Design Income 2,206.88, Print Sales 392.33, Discounts Given (129.96), state tax 23.30 and city tax 7.45 |
| AC-3 | Mixed AR/AP documents recognize exactly once | test: a journal entry Dr AR (customer) 100.00 / Cr Income 60.00 / Cr AP (vendor) 40.00, settled 100.00 on the AR side and then 40.00 on the AP side, recognizes 60.00 of income in total and leaves the cash-basis balance sheet balanced on both dates; a journal entry Dr AR (customer) 100.00 / Cr AP (vendor) 100.00 (`W = 0`), settled 100.00 on the AR side and on a later date 100.00 on the AP side, shows 100.00 on the Offsetting AR/AP documents line between the two dates and 0.00 after, with the balance sheet balanced on every date |
| AC-4 | Retained earnings are computed, never posted | test: income in a prior fiscal year appears as Retained Earnings on the balance sheet and is folded in the trial balance; no journal entry is written |
| AC-5 | Aging buckets and credits follow §12 | tests at bucket boundaries (0, 1, 30, 31, 60, 61, 90, 91 days) and a credit shown negative by document date |
| AC-6 | Sales tax liability follows §12 | test: invoice tax and a credit memo's negative tax by agency, and a payment as a debit to the liability account |
| AC-7 | Every report has CSV output, and the bases are offered where §12 says | tests compare CSV header and rows for each report, including the general ledger on cash basis |
| AC-8 | Routes behave per API.md §5.6 | contract tests: `basis`, dimension filter, CSV by `Accept`, `reports.invalid_period` for `from` after `to`, an agent token reading audit events gets 403 |
| AC-9 | No spine regression | `cargo xtask spine` reports 0 failed |
| AC-10 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W2-04` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-reports -p bookscraft-api --all-targets -- -D warnings
cargo test --locked -p bookscraft-reports -p bookscraft-api
cargo xtask lint
cargo xtask spine
cargo xtask scope W2-04
```

Do not commit `docs/architecture/openapi.json` or `error-codes.md`: Weave 2 regenerates them.

## Deliverables

- Branch: `wp/W2-04-reports`
- PR title: `W2-04: Reports engine and routes`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work.
- A report definition in LEDGER_SPEC §12 is ambiguous for a case your tests hit: raise a CCR with the case and both readings.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
