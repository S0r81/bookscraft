# W2-01: Sales service and routes

## Goal

Implement `SalesService` in `crates/sales` (estimates, invoices, sales receipts, customer payments with the application graph, credit memos, refund receipts, customer refunds, open items) and its HTTP routes in `crates/api/src/routes/sales.rs`.

## Wave and concurrency

- Wave 2, batch A (with W2-02 and W2-03). Paths do not overlap.
- Agent: `ledger-engineer`.
- Timebox: three sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/sales/src/**`, `crates/sales/tests/**`, `crates/api/src/routes/sales.rs`
- `docs/coordination/CCR/CCR-W2-01-*.md`, `docs/coordination/handoffs/W2-01.md`

Read-only: everything else, including `crates/api/src/routes/mod.rs` (it already merges your module), `crates/books` (use its helpers), `crates/posting` (use its rules), `crates/store`.

## Read first

1. `CLAUDE.md` and `.claude/agents/ledger-engineer.md`.
2. `docs/architecture/LEDGER_SPEC.md` §4.1–§4.7, §5, §6, §8.1, and Appendix A steps S03, S06, S08, S10, S14–S17, S20, S22.
3. `docs/architecture/DATA_MODEL.md` §4 (types, revisions, write path).
4. `docs/architecture/API.md` §2, §5.3 (contact open items), §5.4 (typed sales endpoints and the agent column) and §7.1.
5. `docs/architecture/ARCHITECTURE.md` §4.6 (you write your SQL; the store writes the ledger; `books` provides draft, approval and void helpers).
6. The merged `crates/books` helpers, `books::tax`, `money::calc`, and `crates/api/src/routes/` (the pattern W1-05 set for routes, permissions and OpenAPI metadata).

## Preconditions

| Precondition | Check |
|---|---|
| Weave 1 is merged | `git log origin/main --format=%s \| grep -q '^Weave 1: '` |
| The books approval helper exists | `git grep -q 'approve_and_post' origin/main -- crates/books/src` |
| The sales route module is pre-registered | `git show origin/main:crates/api/src/routes/sales.rs > /dev/null` |

## Scope in/out

In:

- **Documents:** save draft, update draft, post (`post = true` or the generic post), repost a posted document, void; amounts computed at save with `money::calc` and `books::tax` and stored (LEDGER_SPEC §4.1); number sequences; `posting::post` then `store::ledger::post_revision` in one transaction with the audit event.
- **Estimates:** statuses (pending, accepted, closed, rejected); convert to a draft invoice with a `document_link (converted_from)`.
- **Customer payments:** applications to charges, credits applied in the same event, the unapplied remainder as open credit, zero-amount payments that only apply credits (no journal entry), the bounds rule (`sales.application_exceeds_open`), the same-key rule (`sales.application_mismatch`), and the warning `sales.payment_before_charge`.
- **Credit memos** with "apply now"; **refund receipts**; **customer refunds** settling open credits (refund not above the open credit).
- **Edits and voids:** a repost must keep every open amount at zero or more (`sales.applied_amount_exceeds_total`); voiding a document that other documents settled fails with `document.has_active_settlements`; voiding an event document reopens what it settled.
- **Open items** per customer (LEDGER_SPEC §5 rule 2), serving `GET /contacts/{id}/open-items?ledger=ar`.
- **Agent rule:** agents may create drafts of estimates, invoices, sales receipts and credit memos only; posting goes through approval (`books` helper).
- **Routes:** `/estimates` (plus `convert` and `status`), `/invoices`, `/sales-receipts`, `/customer-payments`, `/credit-memos`, `/refund-receipts`, `/customer-refunds`: list, create, get, replace, with permissions and OpenAPI metadata (`x-bookscraft-permission`, `x-bookscraft-agent`).
- **Capabilities:** `Estimates`, `Invoices`, `SalesReceipts`, `CustomerPayments`, `CreditMemos`, `RefundReceipts`, `CustomerRefunds`, `SalesTax`, each added only when complete and tested.

Out: printing and email (W4-04), UI (W3-01), deposits (W2-03), reports (W2-04).

## Tasks

1. Invoices and sales receipts with totals and tax.
2. Estimates and conversion.
3. Customer payments and settlements; credit memos; refunds.
4. Reposts and voids with their rules; open items.
5. Routes with contract tests.
6. Register capabilities; run the spine.

## Invariants touched

| Invariant | Test |
|---|---|
| I-3 | T-SALES-1: a void writes a reversal and keeps the document; posted documents are never deleted |
| I-3 | T-SALES-2 (L-5): a zero-amount payment applying a credit writes no journal entry and moves both open amounts |
| I-3 | L-1: for each spine sales document, AR postings per contact equal open amount plus active settlements |
| I-6 | T-AUDIT-1 on every mutating command |
| I-10 | agent drafts only; agent post refused (also covered by T-API-1 through the generic routes) |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | INV-1002 saved through the service stores subtotal 5,300.00, discount 265.00, tax lines 47.50 and 15.20 on a 760.00 base, total 5,097.70, and posts the §4.1 entry | service test |
| AC-2 | Settlements follow LEDGER_SPEC §5 | tests: partial payment (PMT-02 leaves 2,597.70 open on INV-1002); over-application refused with `sales.application_exceeds_open`; another customer's invoice refused with `sales.application_mismatch`; PMT-03 leaves 500.00 unapplied; REF-01 refunds it |
| AC-3 | T-SALES-1 and T-SALES-2 | tests |
| AC-4 | Edit and void rules | tests: reposting an invoice below its applied amount fails with `sales.applied_amount_exceeds_total`; voiding a paid invoice fails with `document.has_active_settlements`; voiding the payment reopens the invoice |
| AC-5 | Estimate conversion | test: converting an estimate creates a draft invoice with a `converted_from` link and the estimate's lines |
| AC-6 | Agent rule | tests: an agent creates a draft invoice; creating a customer payment fails with `auth.agent_forbidden`; the owner approves the draft through the `books` helper |
| AC-7 | T-AUDIT-1 | `assert_audited` in each mutating command's test |
| AC-8 | Routes behave per API.md | contract tests per endpoint: create with `Idempotency-Key`, replace with `If-Match`, validation errors, a viewer's write refused |
| AC-9 | The spine progresses without failures | `cargo xtask spine` reports 0 failed and at least 3 passed (S03 needs only `Invoices` beyond Wave 1) |
| AC-10 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W2-01` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-sales -p bookscraft-api --all-targets -- -D warnings
cargo test --locked -p bookscraft-sales -p bookscraft-api
cargo xtask lint
cargo xtask spine
cargo xtask scope W2-01
```

Do not commit `docs/architecture/openapi.json` or `error-codes.md`: Weave 2 regenerates them.

## Deliverables

- Branch: `wp/W2-01-sales`
- PR title: `W2-01: Sales service and routes`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work (for example a `books` helper or a port method that is missing).
- A spine step fails and the cause is outside `sales`: raise a CCR with the failing output; do not unregister capabilities to hide it.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
