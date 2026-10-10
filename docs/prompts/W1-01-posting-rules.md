# W1-01: Posting rules for every MVP document type

## Goal

Implement version 1 of the posting rule for every remaining MVP document type in the `posting` crate, exactly as the LEDGER_SPEC §4 templates say, each with golden files and the determinism property test.

## Wave and concurrency

- Wave 1, batch A (with W1-02 and W1-05). Paths do not overlap with any other Wave 1 work package.
- Agent: `ledger-engineer`.
- Timebox: two sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/posting/src/rules/**`, `crates/posting/tests/**`, `crates/posting/golden/**`
- `docs/coordination/CCR/CCR-W1-01-*.md`, `docs/coordination/handoffs/W1-01.md`

Read-only: everything else, including the posting framework outside `src/rules/` (W0-05), `crates/domain`, `crates/ledger` and `crates/money`.

## Read first

1. `CLAUDE.md` and `.claude/agents/ledger-engineer.md`.
2. `docs/architecture/LEDGER_SPEC.md` §1–§8 and §13, plus Appendix A (the documents whose postings you will reproduce).
3. `docs/architecture/DATA_MODEL.md` §4.1 (document types, required accounts and contacts, line kinds).
4. ADR-0008 (versioned rules) and ADR-0016 (sales tax).
5. `crates/posting` as merged: the framework, `PostingContext`, the registry in `src/rules/mod.rs` and the journal entry and opening balance rules (the pattern to follow).

## Preconditions

| Precondition | Check |
|---|---|
| Weave 0 is merged | `git log origin/main --format=%s \| grep -q '^Weave 0: '` |
| The registry exists | `git show origin/main:crates/posting/src/rules/mod.rs > /dev/null` |

## Scope in/out

In: one file per rule under `crates/posting/src/rules/`, registered as `<type>@1`:

| Type | LEDGER_SPEC | Notes |
|---|---|---|
| invoice | §4.1 | Tax modes `exclusive`, `inclusive` (post `a_l − tax_l`) and `none`; discount posting; one tax posting per rate |
| sales_receipt | §4.2 | `MONEY` must be bank or undeposited funds |
| customer_payment | §4.3 | Posts `P` only; `P = 0` returns `None` (settlements are written by the store from the applications) |
| credit_memo | §4.4 | Mirror of the invoice |
| refund_receipt | §4.5 | Mirror of the sales receipt |
| customer_refund | §4.6 | |
| bill | §4.8 | No input tax in the US MVP |
| bill_payment | §4.9 | `MONEY` bank or credit card |
| vendor_credit | §4.10 | |
| expense | §4.11 | AR or AP lines need a line contact |
| card_credit | §4.12 | |
| vendor_refund | §4.13 | |
| deposit | §4.14 | `deposit_source` lines credit the source's money account |
| transfer | §4.15 | Exactly one `account` line, the source |

Each rule posts the amounts stored on the document (it never recomputes them), validates what its template requires (account subtypes, required contacts; `posting.invalid_account`, `posting.invalid_contact`), applies the framework's line keys, contact and dimension rules, skips zero postings and non-posting group lines, and supports the import rounding tolerance through the framework.

Out: services, storage, settlement bounds (services and store check them), multi-currency (v1).

## Tasks

1. Implement and register the 14 rules.
2. Write the golden files listed below (insta, stored in `crates/posting/golden/`).
3. Extend the determinism property test to every document type.
4. Add negative tests for each rule's validations.

Goldens, named after the spine documents where one exists (Appendix A numbers):

| Golden | Expected postings |
|---|---|
| `invoice_inv_1001_opening` | AR (Halverson Realty Group) 3,000.00 Dr; Opening Balance Equity 3,000.00 Cr |
| `invoice_inv_1002` | the six postings of LEDGER_SPEC §4.1's worked example (total 5,097.70) |
| `invoice_inv_1003_dimensions` (T-POST-4) | AR 6,000.00 Dr; Design Income 6,000.00 Cr carrying Class = Web and Project = Tallgrass website |
| `invoice_inclusive_tax` | a two-line tax-inclusive invoice where each income posting is `a_l − tax_l` and the tax postings equal the per-rate totals |
| `sales_receipt_sr_01` | Undeposited Funds 1,200.00 Dr; Design Income 1,200.00 Cr |
| `customer_payment_pmt_02` | Checking 2,500.00 Dr; AR (Juniper Lane Bakery) 2,500.00 Cr |
| `customer_payment_zero` | no entry (`None`) |
| `credit_memo_cm_01` | AR (Tallgrass Outfitters) 500.00 Cr; Design Income 500.00 Dr |
| `refund_receipt` | a refund receipt crediting Checking and debiting income |
| `customer_refund_ref_01` | AR (Tallgrass Outfitters) 500.00 Dr; Checking 500.00 Cr |
| `bill_bill_0901_opening` | Opening Balance Equity 1,200.00 Dr; AP (Riverstone Coworking) 1,200.00 Cr |
| `bill_bill_2001` | Hosting 240.00 Dr; AP (Cobaltline Hosting) 240.00 Cr |
| `bill_payment_bp_02` | AP (Cobaltline Hosting) 200.00 Dr; Checking 200.00 Cr |
| `vendor_credit_vc_01` | AP (Cobaltline Hosting) 40.00 Dr; Hosting 40.00 Cr |
| `expense_exp_01_rev1` and `expense_exp_01_rev2` | Office Supplies 186.40 Dr / Studio Visa 186.40 Cr; then 168.40 |
| `expense_with_ar_line` | an expense whose AR line carries its contact |
| `card_credit` | Studio Visa Dr; expense account Cr |
| `vendor_refund` | Checking Dr; AP (vendor) Cr |
| `deposit_dep_01` | Checking 4,200.00 Dr; Undeposited Funds 3,000.00 Cr (PMT-01); Undeposited Funds 1,200.00 Cr (SR-01) |
| `transfer_trf_02` | Studio Visa 450.00 Dr; Checking 450.00 Cr |

## Invariants touched

| Invariant | Test |
|---|---|
| I-1 | amounts only as stored `Minor` values; D-6 lint |
| I-2 | T-POST-1 (determinism across every type), T-POST-3 (golden per type and version) |
| I-3 | every rule returns a `BalancedEntry` (constructor-enforced) |
| I-8 | T-POST-4 (`invoice_inv_1003_dimensions`) |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | Every MVP document type has a registered rule with `rules_version` `<type>@1` (estimate returns `None`) | a test iterates every `DocumentType` and asserts a rule exists and reports the version |
| AC-2 | T-POST-3: every golden in the table exists and matches the expected postings | `cargo test --locked -p bookscraft-posting` passes; the PR shows the INV-1002 and DEP-01 numbers computed by hand |
| AC-3 | T-POST-4: dimensions on INV-1003's line reach its income posting | golden `invoice_inv_1003_dimensions` |
| AC-4 | T-POST-1: posting is deterministic for every type | proptest over 1,000 random documents of all types: byte-identical output across two runs |
| AC-5 | Validation errors fire | one test per rule for a wrong money or AR/AP account (`posting.invalid_account`) and a missing required contact (`posting.invalid_contact`) |
| AC-6 | Zero amounts and group lines never post | tests: a zero-amount payment gives `None`; a group line's own amount does not appear in the entry |
| AC-7 | Import rounding works for document rules | an imported invoice unbalanced by 1 minor unit gets a `{doc}:rounding` posting; by 3 fails with `posting.source_unbalanced` |
| AC-8 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W1-01` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-posting --all-targets -- -D warnings
cargo test --locked -p bookscraft-posting
cargo xtask lint
cargo xtask spine
cargo xtask scope W1-01
```

## Deliverables

- Branch: `wp/W1-01-posting-rules`
- PR title: `W1-01: Posting rules for every MVP document type`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work (for example the framework outside `src/rules/`, or a missing document field in `domain`).
- A golden derived from Appendix A disagrees with the template in §4: raise a CCR with both computations; do not change either number.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
