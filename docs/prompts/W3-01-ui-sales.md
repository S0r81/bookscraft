# W3-01: UI: sales screens

## Goal

Build the sales screens in `crates/ui/src/pages/sales/` (invoices, estimates, sales receipts, payments received, credit memos, refund receipts, customer refunds) for fast, keyboard-only data entry against the sales API, with an end-to-end test of the main flow.

## Wave and concurrency

- Wave 3, batch B (with W3-02). Paths do not overlap.
- Agent: `ui-engineer`.
- Timebox: two sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/ui/src/pages/sales/**`, `tests/e2e/tests/ui_sales.rs`
- `docs/coordination/CCR/CCR-W3-01-*.md`, `docs/coordination/handoffs/W3-01.md`

Read-only: everything else, including `crates/ui/src/routes.rs`, `crates/ui/src/components/`, `crates/ui/src/shell/` and `tests/e2e/src/` (use them; a missing shared component is a CCR, with a local component in your directory meanwhile).

## Read first

1. `CLAUDE.md` and `.claude/agents/ui-engineer.md`.
2. `docs/architecture/ARCHITECTURE.md` §10 (including the component list and the route table for `pages/sales`) and §11 (terminology).
3. `docs/architecture/API.md` §5.3 (open items), §5.4 (sales endpoints, generic post, approve, void) and §7.1.
4. `docs/architecture/LEDGER_SPEC.md` §4.1–§4.7 and §5 (what the screens let users do, and the rules behind the errors they show).
5. The merged `crates/ui` (routes, components, API client, shell) and `tests/e2e/src/` harness.

## Preconditions

| Precondition | Check |
|---|---|
| Weave 2 is merged | `git log origin/main --format=%s \| grep -q '^Weave 2: '` |
| The sales routes are registered in the UI | `git show origin/main:crates/ui/src/routes.rs \| grep -q 'sales/invoices'` |

## Scope in/out

In:

- **Lists** for each document type with filters (status, customer, date range, number) and keyboard navigation through `DataTable`.
- **Invoice editor:** customer type-ahead, terms to due date, `LineItemsGrid` (item or account, description, quantity, unit price, amount, taxable flag, tags), discount (percent or amount), tax code, live totals with `money::calc` matching the server's totals, memo; save draft (`Ctrl+S`), save and post (`Ctrl+Enter`), repost of a posted invoice, void with a reason, duplicate-number warning, warnings from the API.
- **Estimates** with status changes and "Convert to invoice"; **sales receipts**; **credit memos** with "apply now"; **refund receipts**; **customer refunds** choosing which open credits to pay out.
- **Payment received:** choose a customer, see open invoices and credits, enter applications (with an "apply oldest first" helper), see the unapplied remainder, choose deposit to undeposited funds or a bank account.
- **Drafts created by an API client or agent:** a visible badge and, for users who may post, an "Approve and post" action.
- Labels and messages in BooksCraft's own words (ARCHITECTURE §11), for example "Payment received".
- **`tests/e2e/tests/ui_sales.rs`:** by keyboard only, enter an invoice like INV-1002 (two lines, 5% discount, tax code with 6.25% and 2.00%) and see the total 5,097.70 before saving; post it; record a 2,500.00 payment and see 2,597.70 open; void a test invoice with a reason.

Out: printing and emailing documents (W5-03), new shared components (CCR), routes (fixed in W2-05).

## Tasks

1. Lists.
2. Invoice editor, then the other document editors reusing its parts.
3. Payment received.
4. Draft approval action.
5. Native tests for the view-model logic; the end-to-end test.

## Invariants touched

| Invariant | How |
|---|---|
| I-1 | amounts entered and shown as decimal strings; live totals through `money::calc` (test that UI totals equal the server's for the INV-1002 case) |
| I-10 | approval only offered to users with `documents.post`; agents never see post actions (the API refuses them anyway) |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | The keyboard-only flow works | `cargo xtask e2e --web` passes `ui_sales.rs` |
| AC-2 | Live totals equal the server's | native test: the editor's totals for the INV-1002 lines equal the API's saved totals (5,300.00, 265.00, 62.70, 5,097.70) |
| AC-3 | Payment application helper | native tests: "apply oldest first" by due date; the unapplied remainder; never more than an invoice's open amount |
| AC-4 | API errors show at the right field | native test: a problem response with `applications[0].amount` and `sales.application_exceeds_open` marks that row |
| AC-5 | Every sales route in ARCHITECTURE §10.2 renders a real screen (no placeholder left) | native test over the `pages/sales` components named in `routes.rs` |
| AC-6 | Accessibility basics hold on these screens | the e2e test checks accessible names on every input and `role="grid"` on the line grid |
| AC-7 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W3-01` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-ui --all-targets -- -D warnings
cargo check --locked -p bookscraft-ui --target wasm32-unknown-unknown
cargo test --locked -p bookscraft-ui
cargo xtask ui build
cargo xtask e2e --web
cargo xtask lint
cargo xtask scope W3-01
```

## Deliverables

- Branch: `wp/W3-01-ui-sales`
- PR title: `W3-01: Sales screens`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work (shared components, routes, the API client, the e2e harness).
- The API lacks something a screen needs: raise a CCR naming the endpoint and fields.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
