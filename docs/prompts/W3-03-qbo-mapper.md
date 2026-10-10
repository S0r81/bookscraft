# W3-03: QBO mapper (MIT)

## Goal

Build the pure MIT `qbo` crate: serde types for the QuickBooks Online API entities BooksCraft imports, built from Intuit's public API reference, and their mapping to the `interchange` model, including account classification, tax lines, discounts, groups, voids and the reconstruction of payment applications.

## Wave and concurrency

- Wave 3, batch A (with W3-04 and W3-05). Paths do not overlap. W3-04 builds the pipeline on interchange input and does not need this crate.
- Agent: `import-migration-engineer`.
- Timebox: two sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/qbo/src/**`, `crates/qbo/tests/**`, `crates/qbo/fixtures/**`
- `docs/coordination/CCR/CCR-W3-03-*.md`, `docs/coordination/handoffs/W3-03.md`

Read-only: everything else, including `crates/interchange` and `docs/architecture/interchange-v1.md`.

## Read first

1. `CLAUDE.md` and `.claude/agents/import-migration-engineer.md` (clean-room rules).
2. `docs/architecture/MIGRATION_SPEC.md` §2, §4.2, §4.3 and §5.
3. `docs/architecture/DATA_MODEL.md` §8 (field-level mapping summary).
4. `docs/architecture/interchange-v1.md` and the merged `crates/interchange`.
5. ADR-0005, 0012, 0013, 0017.
6. Intuit's public QuickBooks Online Accounting API reference for each entity (fetch it if your tools can; otherwise see the stop conditions).

## Preconditions

| Precondition | Check |
|---|---|
| Weave 2 is merged | `git log origin/main --format=%s \| grep -q '^Weave 2: '` |
| The interchange crate is merged | `git log origin/main --format=%s \| grep -q '^W1-04: '` |

## Scope in/out

In:

- **Types:** serde types for CompanyInfo, Preferences, Account, Term, PaymentMethod, TaxAgency, TaxRate, TaxCode, Class, Department, Customer, Vendor, Employee, Item, Estimate, Invoice, CreditMemo, SalesReceipt, RefundReceipt, Bill, VendorCredit, Purchase, JournalEntry, Payment, BillPayment, Deposit, Transfer, CreditCardPayment and Attachable, with unknown fields tolerated; every mapped record also keeps its raw JSON for `SourceRef.payload`.
- **Account classification:** a data table from AccountType and AccountSubType to BooksCraft class, subtype and system role (ADR-0013); unknown subtypes map by AccountType and keep the raw value as the account's detail.
- **Mapping to interchange** per DATA_MODEL §8 and MIGRATION_SPEC §4.3: lists, documents and lines (sales item, group with components, description only, discount, subtotal, account-based and item-based expense, journal entry, deposit lines), tax lines from `TxnTaxDetail` as received, `GlobalTaxCalculation` to tax mode, a second discount line as a negative item line with an issue, voided transactions (zero amounts), estimate status and links, multi-AR and multi-AP documents keeping their own account refs, sub-customers as contact parents, Class and Department as dimension values.
- **Link reconstruction** (MIGRATION_SPEC §5): greedy pairing of a payment's credit and charge lines into interchange settlements (credits first, then the payment's own amount), bill payments likewise, deposit lines linked to payments and receipts as deposit sources, vendor refunds as deposit lines to AP plus a settlement, credit memos applied without a payment as inferred applications with an issue.
- **Issues** are typed values (for example multi-currency company, merged discount lines, inferred application, suffixed name); the `migrate` crate turns them into `import.*` codes. This crate defines no error-code strings.
- **Fixtures:** hand-written JSON, one per entity type plus the special cases (discount, group, tax-inclusive, voided, unapplied payment, multiple AR accounts, multi-currency preferences), with invented names and amounts.

Out: HTTP, OAuth and the Reports API (W4-03), the import pipeline and validation (W3-04), any I/O.

## Tasks

1. Types and the account classification table, checked against the reference.
2. List and document mapping.
3. Link reconstruction.
4. Fixtures and goldens.

## Invariants touched

| Invariant | Test |
|---|---|
| I-1 | amounts parsed exactly into `money`; source amounts never recomputed |
| I-7 | every mapped record carries a `SourceRef` (source `qbo`, realm, type, id, sync token, raw payload) |
| I-12 | D-1: depends only on MIT workspace crates and permissive externals |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | T-MIG-2: every fixture maps to the expected interchange output | insta goldens in `crates/qbo/tests/` |
| AC-2 | The classification table covers every AccountType in the reference | test against `crates/qbo/fixtures/account_types.json`, transcribed from the public reference (each value present in the table) |
| AC-3 | Greedy pairing follows MIGRATION_SPEC §5 | test: a payment with a credit memo line and two invoice lines yields the expected settlements, and every document's open amount equals its `Balance` |
| AC-4 | Special cases | tests: second discount line becomes a negative item line plus an issue; group lines keep components; voided transactions keep number and date with zero amounts; a multi-currency company yields the multi-currency issue and no documents |
| AC-5 | Every record keeps its source | test: each mapped entity has a `SourceRef` whose payload equals the input JSON |
| AC-6 | Output is deterministic | property test: mapping the same fixtures twice gives equal bundles |
| AC-7 | Lints pass (D-1, D-2) and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W3-03` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-qbo --all-targets -- -D warnings
cargo test --locked -p bookscraft-qbo
cargo xtask lint
cargo xtask spine
cargo xtask scope W3-03
```

## Deliverables

- Branch: `wp/W3-03-qbo-mapper`
- PR title: `W3-03: QBO entity types and mapping to interchange`
- PR description: the template plus a list of the reference pages used, and any facts you could not check (see stop conditions).

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work.
- Intuit's reference pages cannot be fetched from your session: write each entity fact you relied on into the PR as an owner checklist ("verify against the reference: …"), and continue; the Weave does not merge until the owner has ticked it.
- The reference contradicts MIGRATION_SPEC on something that changes stored data: raise a CCR quoting the reference.
- Any temptation to use real or Intuit sample data in a fixture: do not; write invented data.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
