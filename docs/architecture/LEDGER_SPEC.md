# Ledger specification

Status: accepted (owner approved the Step 1 recommendations on 2026-10-10). Owners: `ledger-engineer` (rules), `storage-engineer` (enforcement), `qa-verifier` (tests).

This document defines how BooksCraft turns source documents into ledger postings and how every report-time derivation works. It is normative. The tables and triggers it relies on are in [`schema.sql`](schema.sql), explained in [DATA_MODEL.md](DATA_MODEL.md). The crates are in [ARCHITECTURE.md](ARCHITECTURE.md).

## Contents

1. [Notation](#1-notation)
2. [Accounts and system roles](#2-accounts-and-system-roles)
3. [From document to journal entry](#3-from-document-to-journal-entry)
4. [Posting templates](#4-posting-templates)
5. [Settlements: the application graph](#5-settlements-the-application-graph)
6. [Edits, voids, reversals and approvals](#6-edits-voids-reversals-and-approvals)
7. [Cash-basis derivation](#7-cash-basis-derivation)
8. [Rounding, FX and revaluation](#8-rounding-fx-and-revaluation)
9. [Period locks and closing](#9-period-locks-and-closing)
10. [Audit chain](#10-audit-chain)
11. [Reconciliation, clearing and bank review](#11-reconciliation-clearing-and-bank-review)
12. [Reports derived from the ledger](#12-reports-derived-from-the-ledger)
13. [Invariants as testable statements](#13-invariants-as-testable-statements)
14. [Appendix A: scenario spine](#appendix-a-scenario-spine-copperline-studio-march-2026)

## 1. Notation

| Symbol | Meaning |
|---|---|
| Dr / Cr | A posting's signed amount: debit is positive, credit is negative. "Dr X" means `+X`, "Cr X" means `-X`. |
| `AR`, `AP` | The document's `ar_ap_account_id` (subtype `accounts_receivable` or `accounts_payable`) |
| `MONEY` | The document's `money_account_id`: a bank, credit card, undeposited funds or other asset account |
| `INC(l)` | Income-side account of line `l`: the item's `income_account_id` for item lines, `account_id` for account lines |
| `EXP(l)` | Expense-side account of line `l`: the item's `expense_account_id` for item lines, `account_id` for account lines |
| `DISC` | `discount_account_id`, defaulting to the account with system role `discounts_given` |
| `TAX(r)` | Liability account of the agency that owns tax rate `r` (`tax_agency.liability_account_id`) |
| `OBE` | Account with system role `opening_balance_equity` |
| `ROUND` | Account with system role `rounding` |
| `a_l` | Line amount in minor units (`document_line.amount_minor`); may be negative |
| `S`, `D`, `t_r`, `T` | Subtotal, discount, tax for rate `r`, total of the document (minor units) |
| `{doc}` | The document id; used to build stable posting line keys |

All amounts are integers in minor units (I-1). A posting with a zero amount is never written. Templates are listed in the order postings are numbered (`line_no` 1, 2, 3, ...).

## 2. Accounts and system roles

BooksCraft uses its own five-class taxonomy (ADR-0013). Special behaviour keys off `system_role`, never off an account's name or an imported QBO detail type.

| Class | Subtypes | Normal balance |
|---|---|---|
| asset | bank, accounts_receivable, other_current_asset, fixed_asset, other_asset | Dr |
| liability | accounts_payable, credit_card, other_current_liability, long_term_liability | Cr |
| equity | equity | Cr |
| income | income, other_income | Cr |
| expense | cost_of_sales, expense, other_expense | Dr |

| System role | Subtype or class | Cardinality | Created by | Used by |
|---|---|---|---|---|
| accounts_receivable | accounts_receivable | 1 (default AR; more AR accounts may exist without the role) | company setup | customer documents |
| accounts_payable | accounts_payable | 1 (default AP) | company setup | vendor documents |
| undeposited_funds | other_current_asset | 1 | company setup | payments and receipts awaiting deposit |
| retained_earnings | equity | 1 | company setup | balance sheet: prior years' net income (computed, section 9) |
| opening_balance_equity | equity | 1 | company setup | opening balances (section 4.17) |
| discounts_given | income (contra) | 1 | company setup | document discounts |
| rounding | expense | 1 | company setup | residues (section 8) |
| fx_gain_loss | income or expense | 1 | enabling multi-currency (v1) | realized and unrealized FX |
| uncategorized_income | income | 1 | company setup | bank review default for money in |
| uncategorized_expense | expense | 1 | company setup | bank review default for money out |
| uncategorized_asset | other_current_asset | 1 | company setup | imports with unknown accounts |
| sales_tax_payable | other_current_liability | one per tax agency | creating a tax agency | sales tax liability |

System accounts cannot be deleted. They can be renamed and archived only if they have no postings and another account takes the role in the same command.

## 3. From document to journal entry

1. **Pure function.** `posting::post(document, revision, context) -> Result<Option<BalancedEntry>, PostingError>` lives in the `posting` crate, which has no I/O (I-2). Its inputs are the document's revision snapshot (header, lines, tax lines, settlements) plus a read-only context of the referenced accounts, items, tax rates and agencies, all loaded by the caller. It returns `None` when the document has no ledger effect (estimates, zero-amount documents).
2. **Versioned.** Each document type has its own rules version, for example `invoice@1`. The version is stored on every journal entry (`rules_version`). Changing a template means adding a new version; history is never re-posted under new rules unless the user edits the document (ADR-0008). Golden files exist per version.
3. **Balanced by construction.** `ledger::BalancedEntry` can only be built through `BalancedEntry::new(lines)`, which rejects an empty or one-line entry, a non-zero base sum, and, when every line has the same currency, a non-zero transaction sum (I-3). The storage layer re-checks the same rules at finalize (`journal_entry_finalize` trigger).
4. **Entry date.** The entry date is the document date. A reversal takes the date of the entry it reverses (section 6).
5. **Line keys.** Every posting carries a `line_key` that is stable across revisions of the same document:

   | Posting source | `line_key` |
   |---|---|
   | A document line | that line's `line_key` (UUIDv7, stays the same when the line is edited) |
   | AR or AP slot | `{doc}:ar` (also used for AP) |
   | Money slot | `{doc}:money` |
   | Discount slot | `{doc}:discount` |
   | Tax slot for rate `r` | `{doc}:tax:{tax_rate_id}` |
   | Opening balance offset | `{doc}:ob` |
   | Rounding residue | `{doc}:rounding` |
   | FX difference (v1) | `{doc}:fx` |

   Within one entry a line key appears at most once (storage `UNIQUE (journal_entry_id, line_key)`). If a rule must split one document line across two postings, it suffixes `:a`, `:b`.
6. **Contacts.** Postings to AR or AP carry the contact (storage trigger `posting_ar_ap_requires_contact`). Other postings carry `document_line.contact_id` when present (billable expense lines, JE lines) and no contact otherwise.
7. **Dimensions.** A posting produced from a document line copies that line's dimension values. Document-level dimension values are copied onto every posting of the document, unless the line sets the same dimension, in which case the line wins.
8. **Group (bundle) lines** do not post; their component lines do.

## 4. Posting templates

Each table lists the postings in order. "When" gives the condition for writing a posting; postings with a zero amount are skipped.

### 4.1 Invoice

Tax mode `exclusive` (the default). Validation: `T >= 0`, contact is a customer, `AR` is an AR account, line accounts are not AR, AP, bank or credit card accounts.

| # | Account | Contact | Dr | Cr | When | Line key |
|---|---|---|---|---|---|---|
| 1 | `AR` | customer | `T` | | `T > 0` | `{doc}:ar` |
| 2..n | `INC(l)` for each posting line `l` | line contact | `-a_l` if `a_l < 0` | `a_l` if `a_l > 0` | `a_l ≠ 0` | line key |
| n+1 | `DISC` | | `D` | | `D > 0` | `{doc}:discount` |
| n+2.. | `TAX(r)` for each rate `r` on the tax code | | | `t_r` | `t_r > 0` | `{doc}:tax:{r}` |

Balance: `T = Σa_l − D + Σt_r`.

Amounts are computed at entry time and stored on the document, then posted as stored. Imported documents keep the source's amounts (section 8.1):

- `a_l = round_half_up(qty × unit_price)` when both are given; otherwise the entered amount.
- `S = Σa_l` over posting lines.
- `D = round_half_up(S × pct / 100)` for a percent discount; the entered amount for an amount discount (`0 ≤ D ≤ S`).
- Taxable subtotal `S_tax = Σ a_l` over taxable lines.
- `D_tax = round_half_up(D × S_tax / S)` when `tax_after_discount = 1` and `S > 0`; otherwise `0`.
- Tax base `B = S_tax − D_tax`.
- `t_r = round_half_up(B × rate_percent(r) / 100)` for each rate of the document's tax code. Each component is rounded separately and the tax total is `Σt_r`. One `document_tax_line` row is stored per rate, recording `B` and `t_r`.

**Tax mode `inclusive`** (import fidelity only in MVP; the MVP UI enters exclusive documents). Line amounts include tax. `document_line.tax_minor` holds the tax inside each taxable line: the per-rate tax `t_r` is computed on the tax-inclusive base and allocated to taxable lines with the allocation function (section 8.2). Posting 2..n credits `a_l − tax_l` instead of `a_l`. Postings 1, n+1 and n+2 are unchanged, and `T = Σa_l − D`.

**Tax mode `none`** writes no tax postings.

Worked example (INV-1002 in the spine):

- Lines: 4,500.00 (not taxable) and 800.00 (taxable).
- Discount 5%: `D` = 265.00.
- `D_tax` = 265.00 × 800 / 5,300 = 40.00, so `B` = 760.00.
- Tax: state 6.25% gives 47.50; city 2.00% gives 15.20.
- `T` = 5,300.00 − 265.00 + 62.70 = 5,097.70.

| # | Account | Dr | Cr |
|---|---|---|---|
| 1 | Accounts Receivable (Juniper Lane Bakery) | 5,097.70 | |
| 2 | Design Income | | 4,500.00 |
| 3 | Print Sales | | 800.00 |
| 4 | Discounts Given | 265.00 | |
| 5 | Sales Tax Payable - State Revenue Agency | | 47.50 |
| 6 | Sales Tax Payable - City Tax Office | | 15.20 |

### 4.2 Sales receipt

Same as the invoice, with the money account in place of AR. No settlement is created. Validation: `MONEY` is a bank or undeposited funds account.

| # | Account | Contact | Dr | Cr | When | Line key |
|---|---|---|---|---|---|---|
| 1 | `MONEY` | | `T` | | `T > 0` | `{doc}:money` |
| 2.. | as invoice postings 2..n+2 | | | | | |

### 4.3 Customer payment

The payment's amount is `P`. The applications are `A_j`, from this payment to charge documents. Credit applications `C_k` from other credit documents (credit memos, earlier overpayments) to charge documents can be made in the same event.

| # | Account | Contact | Dr | Cr | When | Line key |
|---|---|---|---|---|---|---|
| 1 | `MONEY` (undeposited funds or bank) | | `P` | | `P > 0` | `{doc}:money` |
| 2 | `AR` | customer | | `P` | `P > 0` | `{doc}:ar` |

The payment also writes these settlement rows (section 5), all with `event_document_id` = this payment and `settled_on` = its date:

- `(charge = invoice_j, credit = this payment, amount = A_j)` for each application.
- `(charge = invoice_k, credit = credit document_k, amount = C_k)` for each credit applied.

| Case | Rule |
|---|---|
| Partial payment | `A_j` < the invoice's open amount. The invoice stays open for the rest. |
| Overpayment / unapplied | `ΣA_j < P`. The remainder `U = P − ΣA_j` is the payment's open credit on AR, usable later by another payment event or a customer refund. |
| Applying credits only | `P = 0` writes no journal entry. The document is posted (revision increments) and carries only settlement rows. QBO models this as a zero payment with LinkedTxn lines. |
| Over-application | `Σ` settlements touching any document must not exceed that document's open amount: error `sales.application_exceeds_open`. |
| Mismatch | Settled documents must share the payment's AR account, contact and currency: error `sales.application_mismatch`. |

### 4.4 Credit memo

Mirror of the invoice. Validation is the same as the invoice. If "apply now" is chosen, the credit memo is the event document of its own settlements: `(charge = invoice, credit = this credit memo)`.

| # | Account | Contact | Dr | Cr | When | Line key |
|---|---|---|---|---|---|---|
| 1 | `AR` | customer | | `T` | `T > 0` | `{doc}:ar` |
| 2..n | `INC(l)` | line contact | `a_l` if `a_l > 0` | `-a_l` if `a_l < 0` | `a_l ≠ 0` | line key |
| n+1 | `DISC` | | | `D` | `D > 0` | `{doc}:discount` |
| n+2.. | `TAX(r)` | | `t_r` | | `t_r > 0` | `{doc}:tax:{r}` |

### 4.5 Refund receipt

Cash refund of a sale without AR (QBO RefundReceipt). Mirror of the sales receipt.

| # | Account | Contact | Dr | Cr | When | Line key |
|---|---|---|---|---|---|---|
| 1 | `MONEY` (bank or card) | | | `T` | `T > 0` | `{doc}:money` |
| 2.. | as credit memo postings 2..n+2 | | | | | |

### 4.6 Customer refund

Pays out a customer's credit balance (an unapplied payment or credit memo). The refund raises AR, so it is the charge side of its settlements.

| # | Account | Contact | Dr | Cr | When | Line key |
|---|---|---|---|---|---|---|
| 1 | `AR` | customer | `R` | | `R > 0` | `{doc}:ar` |
| 2 | `MONEY` (bank) | | | `R` | `R > 0` | `{doc}:money` |

Settlements: `(charge = this refund, credit = credit document_k, amount = R_k)` with `ΣR_k = R`. Validation: `R` ≤ the total open credit of the referenced documents.

### 4.7 Estimate

Non-posting. `posting::post` returns `None`. Estimate statuses are pending, accepted, closed and rejected. Converting an estimate creates a draft invoice with a `document_link(converted_from)` row.

### 4.8 Bill

Validation: `T >= 0`, contact is a vendor. In the US MVP there is no input tax: tax paid to vendors is part of the expense.

| # | Account | Contact | Dr | Cr | When | Line key |
|---|---|---|---|---|---|---|
| 1..n | `EXP(l)` | line contact (billable customer) | `a_l` if `a_l > 0` | `-a_l` if `a_l < 0` | `a_l ≠ 0` | line key |
| n+1 | `AP` | vendor | | `T` | `T > 0` | `{doc}:ar` |

### 4.9 Bill payment

`MONEY` is a bank or credit card account (QBO BillPayment PayType Check or CreditCard).

| # | Account | Contact | Dr | Cr | When | Line key |
|---|---|---|---|---|---|---|
| 1 | `AP` | vendor | `P` | | `P > 0` | `{doc}:ar` |
| 2 | `MONEY` | | | `P` | `P > 0` | `{doc}:money` |

The bill payment is the event document for these settlements:

- `(charge = bill_j, credit = this bill payment, amount = A_j)`.
- `(charge = bill_k, credit = vendor credit_k, amount = C_k)` for vendor credits applied.

Partial, unapplied and zero-amount cases follow section 4.3, with AP in place of AR. The error codes are `purchases.application_exceeds_open` and `purchases.application_mismatch`.

### 4.10 Vendor credit

| # | Account | Contact | Dr | Cr | When | Line key |
|---|---|---|---|---|---|---|
| 1 | `AP` | vendor | `T` | | `T > 0` | `{doc}:ar` |
| 2..n | `EXP(l)` | line contact | `-a_l` if `a_l < 0` | `a_l` if `a_l > 0` | `a_l ≠ 0` | line key |

### 4.11 Expense

The QBO Purchase entity, with payment types cash, check and card. `MONEY` is a bank, credit card or other current asset (cash on hand) account. The header contact is the payee (vendor, customer or employee) and is not posted on the money line.

| # | Account | Contact | Dr | Cr | When | Line key |
|---|---|---|---|---|---|---|
| 1..n | `EXP(l)` (any non-money account, AR/AP allowed with a line contact) | line contact | `a_l` if `a_l > 0` | `-a_l` if `a_l < 0` | `a_l ≠ 0` | line key |
| n+1 | `MONEY` | | | `T` | `T > 0` | `{doc}:money` |

A line posting to AR or AP creates an open item for its contact that settlements can apply (QBO allows a check to a customer against AR). Recording a sales tax payment in MVP is an expense with a line to the agency's `sales_tax_payable` account (section 4.18).

### 4.12 Card credit

A refund or credit to a credit card (QBO Purchase with `Credit = true`).

| # | Account | Contact | Dr | Cr | When | Line key |
|---|---|---|---|---|---|---|
| 1 | `MONEY` (credit card) | | `T` | | `T > 0` | `{doc}:money` |
| 2..n | `EXP(l)` | line contact | `-a_l` if `a_l < 0` | `a_l` if `a_l > 0` | `a_l ≠ 0` | line key |

### 4.13 Vendor refund

Money received from a vendor for an open vendor credit. It raises AP, so it is the charge side.

| # | Account | Contact | Dr | Cr | When | Line key |
|---|---|---|---|---|---|---|
| 1 | `MONEY` (bank or undeposited funds) | | `R` | | `R > 0` | `{doc}:money` |
| 2 | `AP` | vendor | | `R` | `R > 0` | `{doc}:ar` |

Settlements: `(charge = this refund, credit = vendor credit_k, amount = R_k)`.

### 4.14 Deposit

The bank deposit. It groups undeposited funds into one bank line and may add other lines (interest, owner contributions). A negative other line is cash back or a fee.

| # | Account | Contact | Dr | Cr | When | Line key |
|---|---|---|---|---|---|---|
| 1 | `MONEY` (bank) | | `T` | | `T > 0` | `{doc}:money` |
| 2..k | undeposited funds (the source document's money account) | | | `a_j` | each `deposit_source` line | line key |
| k+1.. | line `account_id` | line contact | `-a_l` if `a_l < 0` | `a_l` if `a_l > 0` | each `account` line, `a_l ≠ 0` | line key |

Validation:

- A source document is a posted customer payment, sales receipt or vendor refund whose money account is undeposited funds.
- The source amount `a_j` equals the source's money posting.
- A source sits in at most one posted deposit (trigger `document_line_single_deposit`).
- `T = Σa_j + Σa_l >= 0`.

### 4.15 Transfer

Moves value between two balance-sheet accounts: bank to bank, or bank to credit card, which is how a credit card payment is recorded. `MONEY` is the destination. The single `account` line names the source.

| # | Account | Dr | Cr | When | Line key |
|---|---|---|---|---|---|
| 1 | `MONEY` (to) | `X` | | `X > 0` | `{doc}:money` |
| 2 | source account | | `X` | `X > 0` | line key |

### 4.16 Journal entry

Postings equal the lines. Each line is an account, an optional contact, a signed amount and dimensions. Validation:

- At least two non-zero lines.
- `Σa_l = 0`.
- AR and AP lines need a contact.

A line to AR or AP is an open item for its contact.

**Reversing journal entry.** The option "reverse on date X" creates, at posting time, a second journal entry document dated X. Its lines are negated, it is linked to the first, and it is posted in the same transaction (or queued as a `reversing_entry` job when X is in the future, then posted by the job as the same actor).

**Migration residual.** A journal entry with `is_residual = 1` is created only by the migrator. It closes a month-end trial balance difference against the source system (MIGRATION_SPEC section 6) and is flagged in every report that lists documents.

### 4.17 Opening balance

An `opening_balance` document dated on the cut-over date. Its lines are account, signed amount and optional contact (no AR or AP lines; see below). One offset posting balances it.

| # | Account | Dr | Cr | When | Line key |
|---|---|---|---|---|---|
| 1..n | line account | `a_l` if `a_l > 0` | `-a_l` if `a_l < 0` | `a_l ≠ 0` | line key |
| n+1 | `OBE` | `-Σa_l` if `Σa_l < 0` | `Σa_l` if `Σa_l > 0` | `Σa_l ≠ 0` | `{doc}:ob` |

**Opening AR and AP** are entered as individual invoices and bills dated on or before the cut-over. Each has one `account` line to `OBE` and carries the original number and due date. This gives each open item its own document, so it can be settled and aged per contact; posting a bank line through an opening invoice would double-count. Example: INV-1001 posts Dr AR 3,000.00 (Halverson Realty Group) and Cr Opening Balance Equity 3,000.00.

**Opening bank balances** are reconciled once with an opening reconciliation: statement date = cut-over date, ending balance = the opening line. Later statements then start from it.

### 4.18 Sales tax

| Topic | MVP rule |
|---|---|
| Rates | Manual: agencies, rates (percent) and tax codes, which are groups of rates. Automated rates sit behind `TaxRateProvider` (later). |
| Computation | Section 4.1. Each rate is computed and rounded separately; rounding mode per section 8.1. |
| Liability | Each agency has its own `sales_tax_payable` account. Tax postings credit it on sales and debit it on credit memos and refund receipts. |
| Payment | Recorded as an expense (or check) whose line debits the agency's liability account. A dedicated tax payment and filing record arrives in v1. |
| Report | Sales tax liability by agency (section 12): taxable base and tax from `document_tax_line`, payments from debits to the liability account, balance from the ledger. |
| Thresholds and nexus | Data, never code (CV-8). Not used by MVP computation. |

## 5. Settlements: the application graph

The `settlement` table is BooksCraft's form of QBO `LinkedTxn` between AR and AP documents. A row says: on `settled_on`, as part of `event_document_id` at `event_revision`, `amount_minor` of `charge_document_id` was settled by `credit_document_id` on (`ledger`, `account_id`, `contact_id`).

| Ledger | Charge documents (raise the balance) | Credit documents (lower the balance) |
|---|---|---|
| ar | invoice; customer refund; JE or expense line Dr AR | customer payment; credit memo; JE line Cr AR |
| ap | bill; vendor refund; JE line Cr AP | bill payment; vendor credit; expense or JE line Dr AP |

Rules:

1. **Rows are immutable.** A settlement is *active* while its event document is posted and still at `event_revision` (view `active_settlement`). Reposting the event document makes its old rows inactive and writes new ones. Voiding it makes them inactive.
2. **Open amount** of document `X` on (account, contact) as of date `d` = `|Σ X's postings to that account and contact|` minus the active settlements dated on or before `d` in which `X` is the charge or the credit.
3. **Bounds.** When an event document is posted, every touched document's open amount stays `>= 0`. Errors are `sales.application_exceeds_open` and `purchases.application_exceeds_open`.
4. **Same key.** Both sides share account, contact and currency.
5. **Dates.** `settled_on` is the event document's date. Applying a payment dated before the invoice is allowed with warning `sales.payment_before_charge`; QBO data contains such pairs.
6. **Voiding a charge or credit that others have settled** is refused (`document.has_active_settlements`) until those event documents are edited to drop the application. Voiding an event document is allowed and reopens what it settled.
7. **Editing a charge document** (for example an invoice total) must keep its open amount `>= 0` (`sales.applied_amount_exceeds_total`).

## 6. Edits, voids, reversals and approvals

| Action | Precondition | Ledger effect | Document effect |
|---|---|---|---|
| Save draft | none | none | `status = draft`, `revision = 0`, lines at revision 0 (mutable) |
| Delete draft | draft only | none | rows deleted (trigger `document_delete_draft_only`); audited |
| Post | draft; actor may post (an `agent` never may, I-10) | original entry `E1` | lines copied to revision 1; `status = posted`, `revision = 1` |
| Approve | draft created by `api` or `agent`; approver is a user with post permission | as Post | sets `approved_by_user_id`, `approved_at`; audit actions `approval.approve` then `document.post` |
| Edit posted (repost) | posted; both the old and new dates pass the lock rules; reconciled money lines unchanged (section 11) | reversal `R_n` of `E_n`, dated `E_n`'s date, then original `E_{n+1}` dated the new document date | new lines at revision n+1; header updated; `revision = n+1` in the same transaction |
| Void | posted; no other document's active settlement involves it; not in a posted deposit; reconciled money lines first unreconciled | reversal `R_n` dated `E_n`'s date | `status = voided`, `voided_at`, `void_reason`; content frozen |

Rules:

1. A reversal posting has the same account, contact, currency, dimensions and line key as the original, with negated amounts. Storage refuses a reversal whose postings do not cancel the original exactly, are dated differently, or target a non-final entry (`ledger.reversal_mismatch`, `ledger.reversal_target_not_final`). An entry is reversed at most once.
2. Documents that write no entry (zero amounts) still move through the same statuses and revisions.
3. A document dated in a hard-locked period cannot be edited or voided. The correction is a new document in an open period, for example a journal entry. Soft-locked periods need an override (section 9).
4. Every state change appends an audit event in the same transaction (section 10).
5. Imports post with `source = import`. The actor is the importing user and `via = import`.

## 7. Cash-basis derivation

BooksCraft stores one accrual ledger (I-4). Cash basis is computed at report time from the final postings and the active settlements. No cash-basis table exists.

**Allocation function.** Used here and in section 8. `allocate(target, w[1..n])` splits integer `target` across integer weights with `W = Σw ≠ 0`:

1. `exact_i = target × w_i / W` (exact rational).
2. `base_i = floor(exact_i)` (toward negative infinity).
3. `R = target − Σbase_i` (always `0 <= R < n`).
4. Add 1 to the `R` entries with the largest `exact_i − base_i`. Ties go to the lower index (posting `line_no`).
5. The result sums exactly to `target`.

**Classification of a non-voided posted document:**

| Class | Definition | Cash-basis treatment |
|---|---|---|
| Cash document | No postings to AR or AP accounts (sales receipt, refund receipt, expense without AR/AP lines, card credit, deposit, transfer, JE without AR/AP lines, opening balance) | Every posting is recognized at its entry date, unchanged. |
| Cash settlement document | Customer payment, bill payment, customer refund, vendor refund | Money postings are recognized at the entry date. AR/AP postings are never recognized. For payments, the unapplied credit is recognized as a report line: **Unapplied customer payments** (income section, credit) or **Unapplied vendor payments** (expense section, debit). It is recognized at the payment date for the full amount and reduced by each settlement in which the payment is the credit, on that settlement's date. |
| Accrual document | Any other document with AR or AP postings (invoice, credit memo, bill, vendor credit, JE or expense with AR/AP lines) | AR/AP postings are never recognized. Its other postings (the recognizable postings, weights `w`) are recognized only through the settlements in which it is a charge or a credit. |

**Accrual-document recognition.** For accrual document `X` with recognizable postings `w`, take its active settlements in `(settled_on, id)` order. Let `cum_k` be the running total of settled amounts through settlement `k`. The recognized amount of each posting at settlement `k` is:

```
target(c) = -c if Σw < 0 else c
recognized_k = allocate(target(cum_k), w) − allocate(target(cum_{k−1}), w)     (cum_0 = 0)
```

The result is recognized on `settled_on` of settlement `k`. Using cumulative allocation means a fully settled document recognizes exactly its accrual amounts, and the cents never drift.

Consequences:

- An invoice settled by a credit memo recognizes both the invoice's income and the credit memo's contra-income on the application date. They net to the credited amount.
- Credit card charges are cash documents, recognized when charged.
- Sales tax on invoices is recognized in proportion to payments.
- On a cash-basis balance sheet, AR and AP are zero and every bank, card and other balance-sheet account matches accrual. Equity includes cash-basis net income. The balance sheet balances because every recognized amount is half of a balanced pair: the money side was recognized at its date and the income side through settlements, or both sides at the same date.

Cash-basis parity with QuickBooks is measured, not promised, in MVP (MIGRATION_SPEC section 6). Spine example: INV-1002 (5,097.70), paid 2,500.00 on 2026-03-13, recognizes Design Income 2,206.88, Print Sales 392.33, Discounts Given (129.96), state tax 23.30 and city tax 7.45. Together these are 2,500.00.

## 8. Rounding, FX and revaluation

### 8.1 Rounding

| Quantity | Rule |
|---|---|
| Line amount from qty × unit price | `round_half_up` to minor units. The stored line amount is authoritative. |
| Percent discount | `round_half_up(S × pct / 100)` |
| Taxable share of a discount | `round_half_up(D × S_tax / S)` |
| Tax per rate component | Company setting `rounding.tax`: `half_up` (default, away from zero) or `half_even`, applied to `B × rate / 100` |
| Splitting one amount across lines (inclusive tax, cash basis, FX base amounts) | `allocate` (section 7), which leaves no residue |
| Imported documents | The source's amounts are stored as received and never recomputed. If an imported document's postings do not balance by up to ±2 minor units (source-side rounding), the difference posts to `ROUND` with line key `{doc}:rounding` and warning `import.rounding_adjusted`. A larger difference fails the document (`import.unbalanced_source`). |

Computation uses exact decimals (`rust_decimal`) and integer minor units. `f32` and `f64` never appear in the money path (I-1).

### 8.2 Multi-currency (v1; the schema and money types are ready in MVP)

| Topic | Rule |
|---|---|
| Rates | `document.fx_rate` = base units per 1 unit of the document currency, a decimal with up to 10 fractional digits. NULL when the currency is the base currency. Rates come from the user or a rate provider (v1). |
| Base amounts | Each posting's `base_amount_minor = round_half_up(amount_minor × fx_rate × 10^(base_digits − txn_digits))`. If the base amounts do not sum to zero, the residue (a few minor units) posts to `ROUND` as a base-only posting (`amount_minor = 0`, currency = base, line key `{doc}:rounding`). |
| Realized gain or loss | On settlement of a foreign charge, the event document's AR or AP posting uses the charge's carrying rate for the applied part. Its money posting uses the event's own rate. The difference posts to `fx_gain_loss` (line key `{doc}:fx`). |
| Unrealized revaluation | A period-end `fx_revaluation` document (v1) revalues open foreign AR/AP and foreign bank and card balances at the period-end rate, posting the difference to `fx_gain_loss`. A linked reversal dated the first day of the next period is posted with it. |
| Enabling | `company.multi_currency_enabled` can be switched off again while no document or account uses a non-base currency (brief §2.6: reversible where safe). The base currency never changes once any document is posted. |
| MVP behaviour | All documents use the base currency. The QBO migrator refuses a multi-currency company with `import.multi_currency_unsupported`, listing the foreign-currency entities. |

## 9. Period locks and closing

| Rule | Detail |
|---|---|
| State | `company.hard_locked_through` ≤ `company.soft_locked_through` (either may be NULL). A date `d` is hard-locked if `d <= hard_locked_through`, soft-locked if not hard-locked and `d <= soft_locked_through`, otherwise open. Because both are single dates, a locked period can never follow an open one. |
| Hard lock | No journal entry may be finalized with `entry_date` in a hard-locked period, with or without an override (trigger `period.hard_locked`). Documents dated there cannot be posted, edited or voided. |
| Soft lock | An entry dated in a soft-locked period is finalized only if a `lock_override` row (reason of 5 or more characters, actor) exists for it. The service writes the override, and the audit event `period.override`, only for users with the `period.override` permission (owner, admin, accountant). |
| Moving dates | `PUT period-locks` sets both dates in one audited command (`period.set_locks`, before and after values, reason required). Moving `hard_locked_through` earlier (unlocking) requires the owner role and a reason (I-5: overrides are audited). |
| Closing | No closing entries. Net income of prior fiscal years is presented as Retained Earnings on the balance sheet at report time, and the current fiscal year's net income as "Net income" (brief §2.1; C-9). The trial balance therefore matches QuickBooks's, which also posts no closing entries. |
| Fiscal year | `company.fiscal_year_start_month`. The year containing date `d` starts on the first day of that month on or before `d`. |

## 10. Audit chain

| Topic | Rule |
|---|---|
| What is audited | Every mutating command on the company file: create, update, archive, post, void, delete-draft, approve, settle (as part of its event), lock changes, overrides, reconciliation start, complete and undo, clearing changes, bank review actions, imports (one summary event per import run plus per-document events), settings, attachment links. Reads are not audited. System-file commands (users, memberships, tokens, company registry) are audited in the system file. |
| Row | `seq` (gapless from 1), `id`, `occurred_at`, `actor_type` (user, api, agent), `actor_id`, `actor_name`, `via`, `action`, `entity_type`, `entity_id`, `before_json`, `after_json`, `reason`, `request_id`, `prev_hash`, `hash` |
| Canonical form | JSON object of every column except `hash`. Keys are sorted, there is no insignificant whitespace, strings are UTF-8, integers are bare, and decimals and money are strings. `before_json` and `after_json` are embedded as parsed JSON. |
| Hash | `hash = hex(SHA-256(prev_hash ‖ "\n" ‖ canonical_json))`. For `seq = 1`, `prev_hash` is 64 zeros. |
| Ledger link | The `document.post` audit event's `after_json` includes each new journal entry's id and `content_hash`. `content_hash` = SHA-256 of the canonical JSON of the entry header plus its postings in `line_no` order. One chain therefore covers documents and ledger (C-4). |
| Enforcement | Storage refuses update, delete, gaps and broken `prev_hash` links. The writer computes `hash`. `bookscraft verify` recomputes every hash and every journal entry `content_hash` and reports the first mismatch. It runs on every company open (quick mode checks the last 1,000 events) and in full on demand. |
| Limits | The chain is tamper-evident, not tamper-proof: whoever holds the file can rewrite it entirely (R-5). |

## 11. Reconciliation, clearing and bank review

| Topic | Rule |
|---|---|
| Accounts | Bank and credit card accounts are reconcilable; so is any balance-sheet account the user marks reconcilable (setting). |
| Clearing state | Per (account, line key) on money-side postings: uncleared, cleared or reconciled. The latest `clearing_event` wins; no event means uncleared. Keyed by line key, so the state survives reposts (G-6). |
| Start | One in-progress reconciliation per account. Beginning balance = ending balance of the last completed reconciliation for the account, or 0. |
| Tick | Ticking adds a `reconciliation_line` (posting, amount, date) to the in-progress reconciliation and appends a `cleared` clearing event; unticking removes the line and appends `uncleared`. Candidate lines: final postings to the account dated on or before the statement date whose state is not reconciled. |
| Complete | Allowed only when `beginning + Σticked = ending` exactly. The statement-date lines are frozen: `snapshot_hash` = SHA-256 of the canonical JSON of the sorted lines. Each line gets a `reconciled` clearing event. The reconciliation becomes immutable. |
| Undo | Only the most recent completed reconciliation of an account. Requires a reason. Status becomes undone, and each of its lines gets a `cleared` clearing event. Audited. |
| Editing a reconciled line | A repost or void that changes the account, base amount or entry date of a posting whose line key is reconciled is refused (`reconciliation.reconciled_line_changed`). The user may first unreconcile that single line with a reason, which appends an `uncleared` event and an audit event. The completed reconciliation then shows as discrepant (frozen lines ≠ current state) until a later reconciliation absorbs it. |
| Cleared line edited | A cleared but unreconciled line whose amount, account or date changes on repost gets an `uncleared` event with reason `document edited`. |
| Bank review | Imported lines start `for_review`. Actions are: match (to an existing money-side posting of the same account and amount, sign-adjusted; suggestions rank by amount equality, then date distance ≤ 10 days, then payee or reference similarity); add (create and post a document from the line, or a draft when the actor is an agent, I-10); exclude; undo. Match and add append a `cleared` clearing event for the money line. Undoing an add voids the created document. All actions are appended to `bank_txn_action`. |
| Rules | `bank_rule` rows evaluated by ascending priority; first match wins. Conditions: payee, memo or amount with contains, equals, starts with, between, greater than or less than, against all or any. Actions: document type (expense, deposit, transfer), account, contact, memo, dimensions. With `auto_add = 1` the add is applied immediately (actor = the rule's author, `via = job`); otherwise it is a suggestion. |
| Dedupe | `UNIQUE (account_id, external_id)` for FITID or provider ids. Lines without an id use `dedupe_hash = SHA-256(account_id ‖ posted_date ‖ amount ‖ normalized payee ‖ normalized memo ‖ ordinal)`, where `ordinal` is the occurrence index of an identical tuple within the file. A re-import inserts nothing (I-7). |

## 12. Reports derived from the ledger

Every report is a query over `ledger_line` (final postings), `active_settlement` and the document tables, run on accrual or cash basis (section 7). Nothing derived is stored.

| Report | Definition |
|---|---|
| Trial balance (as of `d`) | Per account, `Σ base_amount_minor` of postings with `entry_date <= d`, shown in debit and credit columns. Prior-years' income and expense are folded into Retained Earnings at report time (section 9). |
| Profit and loss (`from`..`to`) | Income and expense accounts. Income is shown as `−Σ`. Net income = income − expenses. Grouping by month or by dimension value; comparison columns. |
| Balance sheet (as of `d`) | Asset, liability and equity accounts as of `d`. Equity adds Retained Earnings (net income of fiscal years before the one containing `d`) and Net income (year to date). Assets = liabilities + equity is asserted on every run. |
| General ledger and journal | Postings with running balance per account; entries grouped by document. Voided documents are shown with their reversal. |
| AR and AP aging (as of `d`) | Open items per contact (section 5 rule 2) in buckets by days past due: current, 1-30, 31-60, 61-90, 91+. Charge documents use `due_date`, or the document date when there is none. Credits are shown as negative open amounts bucketed by document date. Summary and detail. |
| Sales tax liability (`from`..`to`) | Per agency: taxable base and tax from `document_tax_line` of posted documents in the period (credit memos and refund receipts negative); payments = debits to the liability account from other documents; balance = ledger balance of the liability account. Cash basis uses section 7 recognition of the tax postings. |
| Audit log | `audit_event` filtered by time, actor, entity and action |

## 13. Invariants as testable statements

Each statement is failable. The **Test** column names the planned test, its crate and the work package (WP) that writes it ([docs/prompts/00-INDEX.md](../prompts/00-INDEX.md)). The `T-` identifiers are used in prompts and PRs.

| Inv. | Testable statement | Test | Crate / WP |
|---|---|---|---|
| I-1 | Every money amount is `i64` minor units plus a currency; overflow returns an error, never wraps. | T-MONEY-1 proptest: checked add, sub and neg over random pairs including `i64::MIN`/`MAX` | money / W0-02 |
| I-1 | `f32`/`f64` do not appear in `money`, `ledger` or `posting`. | T-MONEY-2 `clippy::disallowed_types` (CI clippy job) plus `cargo xtask lint` token scan; W0-01 demonstrates a failing case | xtask / W0-01 |
| I-1 | `allocate` always sums exactly to the target, for random targets and weights including negatives. | T-MONEY-3 proptest | money / W0-02 |
| I-1 | Money serializes as `{"amount":"<decimal with exactly the currency's minor digits>","currency":"<ISO>"}` and round-trips losslessly. | T-MONEY-4 proptest | money / W0-02 |
| I-1 | A source-rounding difference of ±1..2 minor units on import posts to the rounding account; ±3 fails. | T-MIG-4 golden | migrate / W3-04 |
| I-2 | `posting::post` is deterministic: the same input gives byte-identical output across 1,000 random documents. | T-POST-1 proptest | posting / W0-05, W1-01 |
| I-2 | `posting` and `ledger` have no I/O dependencies (no tokio, rusqlite, reqwest, std::fs or std::net use). | T-POST-2 `cargo xtask lint` pure-crate rule | xtask / W0-01 |
| I-2 | Every MVP document type has a golden file per rules version, and every journal entry stores a `rules_version`. | T-POST-3 insta golden suite plus schema NOT NULL | posting / W1-01 |
| I-3 | `BalancedEntry` cannot be constructed from unbalanced or one-line input. | T-LEDGER-1 proptest plus the constructor being the only public way to build one | ledger / W0-05 |
| I-3 | Storage refuses to finalize an unbalanced entry, to update or delete final postings or entries, or to add postings to a final entry. | T-STORE-1..4 (DATA_MODEL.md §6 cases 1–4; every other case there is T-STORE-n for case n) | store / W0-04 |
| I-3 | A reversal exactly cancels its original; an entry is reversed at most once. | T-LEDGER-2 proptest at the type level plus T-STORE-6 trigger test | ledger, store / W0-05, W0-04 |
| I-3 | Random sequences of documents, edits and voids keep the trial balance at 0 and the balance sheet balanced. | T-PROP-1 property test over the full service stack | tests/scenarios / W0-03 harness, active from W2 |
| I-3 | A void is a reversal; posted documents are never deleted. | T-STORE-9 delete and status triggers plus T-SALES-1 void test | store, sales / W0-04, W2-01 |
| I-4 | No table stores cash-basis amounts; the cash-basis trial balance balances; a fully settled document recognizes exactly its accrual amounts. | T-REP-1 schema scan plus proptest | reports / W2-04 |
| I-4 | The spine's cash-basis P&L equals Appendix A. | T-SPINE-CASH golden | tests/scenarios / W0-03 |
| I-5 | Entries dated on or before the hard-lock date are refused even with an override; soft-locked dates need an override row. | T-STORE-12 trigger tests | store / W0-04 |
| I-5 | Lock changes and overrides each append an audit event; moving the hard lock earlier requires owner role plus reason. | T-BOOKS-1 | books / W1-02 |
| I-6 | Audit rows cannot be updated or deleted; sequence gaps and broken links are refused. | T-STORE-13 | store / W0-04 |
| I-6 | `verify` detects a modified `after_json`, a modified posting amount (with triggers dropped) and a removed event. | T-STORE-19 | store / W0-04 |
| I-6 | Every mutating service command appends at least one audit event with the correct actor type and `via`. | T-AUDIT-1 harness assertion used by every service test | test-support / W0-03 |
| I-7 | Importing the same QBO data, IIF or CSV twice creates no duplicates and reports the second run as all-duplicate. | T-MIG-1 | migrate / W3-04 |
| I-7 | Re-importing an OFX file inserts no bank lines; CSV lines without FITID dedupe by hash and ordinal. | T-BANK-1 | banking / W2-03 |
| I-8 | 200 dimensions can be created, and a dimension can hold 1,000 values (each created through the service, with its audit event); no count limit exists anywhere; line dimensions propagate to postings. | T-BOOKS-2, the `count-limits` lint, and T-POST-4 golden | books, xtask, posting / W1-02, W0-01, W1-01 |
| I-9 | 2,000 accounts, 100 users, 200 dimensions and 200 custom fields can be created with no limit error; no `MAX_*` count limit exists. | T-LIMIT-1 integration test plus lint | books, identity / W1-02, W1-03 |
| I-10 | An `agent` token cannot post, void, approve, delete or change locks: every such endpoint returns 403 `auth.agent_forbidden`; agent-created documents are drafts. | T-API-1 | api / W1-05 |
| I-10 | No MCP tool posts, voids, approves, deletes or moves money; agent tokens cannot be granted `books:write`. | T-MCP-1 tool-list snapshot plus T-ID-2 | mcp, identity / W5-02, W1-03 |
| I-10 | Approval stores the approver and appends `approval.approve`. | T-BOOKS-3 | books / W1-02 |
| I-11 | No API operation or MCP tool processes payroll, moves money or files taxes; payment SDK crates are banned in `deny.toml`. | T-SCOPE-1 OpenAPI path denylist test plus cargo-deny bans | api, xtask / W1-05, W0-01 |
| I-12 | `cargo deny check licenses` passes; MIT crates depend only on MIT workspace crates and permissive externals; every source file has the right SPDX header. | T-LIC-1, T-LIC-2, T-LIC-3 | xtask, CI / W0-01 |
| I-13 | CI runs build and tests on Linux, Windows and macOS. | T-PLAT-1 CI matrix (required checks) | CI / W0-01 |
| I-13 | `cfg(target_os)`, `cfg(windows)`, `cfg(unix)` and `cfg(target_family)` appear only in `crates/platform`; `std::process::Command` appears only in `xtask`. | T-PLAT-2, T-PLAT-3 `cargo xtask lint` | xtask / W0-01 |
| I-13 | `.gitattributes` pins line endings; `git ls-files --eol` shows no CRLF in text files. | T-PLAT-4 lint | xtask / W0-01 |
| I-13 | Company files named `Acme` and `acme` conflict on every OS; tests use temp dirs and `Path` joins only. | T-PLAT-5 store test plus lint (no `/tmp` or `C:\` literals in tests) | store, xtask / W0-04, W0-01 |

Derived ledger rules used by tests:

| ID | Statement | Test |
|---|---|---|
| L-1 | For every posted document, the sum of its current entry's AR/AP postings per contact equals its open amount plus its active settlements. | T-PROP-1 |
| L-2 | A deposit's money posting equals the sum of its source postings plus other lines. | T-BANK-2 |
| L-3 | Completing a reconciliation requires a zero difference, and its `snapshot_hash` recomputes. | T-BANK-3 |
| L-4 | The reconciled-line edit rule refuses a changed reconciled posting and allows an unchanged one. | T-BANK-4 |
| L-5 | A zero-amount payment applying a credit writes no journal entry and moves both open amounts. | T-SALES-2 |

## Appendix A: scenario spine (Copperline Studio, March 2026)

The scenario spine is a QA-owned end-to-end suite in `tests/scenarios/` (ADR-0029). It drives the real services (no HTTP) through one month of a fictional design agency. Each step declares the capabilities it needs (`domain::Capability`) and runs once every needed capability is registered by a merged crate. Until then it reports `pending`, not failed. The expected values below were computed with a reference model of sections 4, 5, 7 and 12, and are the golden files' source of truth.

**Company.** Copperline Studio LLC, base currency USD, fiscal year starting January, template `agency`, time zone America/Denver. Opening balances are as of 2026-02-28; the period is March 2026.

**Accounts used.** Checking and Savings (bank), Undeposited Funds, Accounts Receivable, Equipment and Accumulated Depreciation (fixed asset), Accounts Payable, Studio Visa (credit card), Sales Tax Payable - State Revenue Agency and Sales Tax Payable - City Tax Office, Opening Balance Equity, Retained Earnings, Design Income, Print Sales, Discounts Given, Hosting, Office Supplies, Contract Labor, Depreciation and Bank Fees.

**Tax.** Agencies State Revenue Agency (rate State 6.25%) and City Tax Office (rate City 2.00%); tax code "Local 8.25%" = both rates.

**Contacts.** Customers Halverson Realty Group, Juniper Lane Bakery and Tallgrass Outfitters. Vendors Riverstone Coworking, Cobaltline Hosting, Fernwood Office Supply and Ampersand Freelance Studio (1099).

**Dimensions.** Class (values Brand, Web), Project (value Tallgrass website).

| Step | Date | Action | Capabilities |
|---|---|---|---|
| S01 | | Create the company from template `agency`; create the tax agencies, rates and code, the contacts and the dimensions | `Company`, `Accounts`, `Contacts`, `Tax`, `Dimensions` |
| S02 | 2026-02-28 | Opening balance OB-1: Checking 12,500.00 Dr, Savings 20,000.00 Dr, Equipment 6,000.00 Dr, Studio Visa 450.00 Cr; offset to OBE 38,050.00 Cr | `OpeningBalances` |
| S03 | 2026-02-15 | Opening invoice INV-1001, Halverson Realty Group, 3,000.00 to OBE, due 2026-03-17 | `Invoices` |
| S04 | 2026-02-20 | Opening bill BILL-0901, Riverstone Coworking, 1,200.00 from OBE, due 2026-03-06 | `Bills` |
| S05 | 2026-02-28 | Opening reconciliation of Checking: statement ending 12,500.00, tick OB-1's Checking line, complete | `Reconciliation` |
| S06 | 2026-03-02 | INV-1002 Juniper Lane Bakery: "Brand identity package" 4,500.00 (not taxable, class Brand) and "Printed brochures" 800.00 (taxable, class Brand); discount 5%; tax code Local 8.25%; terms Net 30 (due 2026-04-01). Total 5,097.70 (section 4.1 example) | `Invoices`, `SalesTax`, `Dimensions` |
| S07 | 2026-03-03 | BILL-2001 Cobaltline Hosting, Hosting 240.00, terms Net 15 (due 2026-03-18) | `Bills` |
| S08 | 2026-03-05 | PMT-01 Halverson Realty Group, 3,000.00 to Undeposited Funds, applied to INV-1001 | `CustomerPayments` |
| S09 | 2026-03-06 | BP-01 Riverstone Coworking, check 1041 from Checking, 1,200.00 applied to BILL-0901 | `BillPayments` |
| S10 | 2026-03-09 | SR-01 Tallgrass Outfitters, "Logo refresh" 1,200.00 (Design Income), paid by check to Undeposited Funds | `SalesReceipts` |
| S11 | 2026-03-10 | DEP-01 to Checking: PMT-01 + SR-01 = 4,200.00 | `Deposits` |
| S12 | 2026-03-12 | EXP-01 Fernwood Office Supply on Studio Visa, Office Supplies 186.40 | `Expenses` |
| S13 | 2026-03-12 | Edit EXP-01 to 168.40 (typo). Expect three entries for EXP-01: original 186.40, reversal, revision 2 at 168.40 | `Expenses` |
| S14 | 2026-03-13 | PMT-02 Juniper Lane Bakery, 2,500.00 deposited directly to Checking, applied to INV-1002 (partial) | `CustomerPayments` |
| S15 | 2026-03-16 | INV-1003 Tallgrass Outfitters, "Website build" 6,000.00, class Web, project Tallgrass website, terms Net 15 (due 2026-03-31) | `Invoices`, `Dimensions` |
| S16 | 2026-03-18 | CM-01 Tallgrass Outfitters, "Website build" credit 500.00, applied now to INV-1003 | `CreditMemos` |
| S17 | 2026-03-19 | INV-1004 Tallgrass Outfitters 250.00 entered in error, then voided the same day | `Invoices` |
| S18 | 2026-03-20 | VC-01 Cobaltline Hosting, Hosting credit 40.00 | `VendorCredits` |
| S19 | 2026-03-20 | BP-02 Cobaltline Hosting: check 1042 from Checking 200.00 plus VC-01 40.00, both applied to BILL-2001 | `BillPayments` |
| S20 | 2026-03-23 | PMT-03 Tallgrass Outfitters 6,000.00 to Undeposited Funds: 5,500.00 applied to INV-1003, 500.00 unapplied | `CustomerPayments` |
| S21 | 2026-03-24 | DEP-02 to Checking: PMT-03 6,000.00 | `Deposits` |
| S22 | 2026-03-25 | REF-01 customer refund to Tallgrass Outfitters, check 1043 from Checking, 500.00 against PMT-03's unapplied credit | `CustomerRefunds` |
| S23 | 2026-03-26 | TRF-01 Checking to Savings 5,000.00 | `Transfers` |
| S24 | 2026-03-27 | TRF-02 Checking to Studio Visa 450.00 (card payment) | `Transfers` |
| S25 | 2026-03-27 | EXP-02 Ampersand Freelance Studio, check 1044 from Checking, Contract Labor 1,500.00 | `Expenses` |
| S26 | 2026-03-30 | JE-01 Depreciation 100.00 Dr / Accumulated Depreciation 100.00 Cr | `JournalEntries` |
| S27 | 2026-03-31 | Import an OFX statement for Checking with 9 lines (below). Import it again: 0 new lines | `BankImport` |
| S28 | 2026-03-31 | Match the 8 known lines. For the 15.00 bank fee, an `agent` actor creates draft EXP-03 (Bank Fees 15.00 from Checking). Agent post attempt → 403 `auth.agent_forbidden`. TB unchanged while it is a draft. Owner approves → posted; audit shows `approval.approve` by the owner. Match the fee line to EXP-03 | `BankReview`, `Expenses`, `Approvals` |
| S29 | 2026-03-31 | Reconcile Checking: statement ending 17,835.00, tick the 9 lines, difference 0.00, complete. EXP-02 stays outstanding | `Reconciliation` |
| S30 | | Set `hard_locked_through = 2026-02-28`, `soft_locked_through = 2026-03-31`. Posting a JE dated 2026-03-15 without an override → `period.soft_locked`; with an override reason → posts (then void it with an override). A JE dated 2026-02-27 with an override → `period.hard_locked` | `PeriodLocks` |
| S31 | | Run every report below and compare with the golden files; run `verify` → chain intact | `Reports`, `Verify` |

S30's test entries post and then void within March, so they net to zero and leave the totals below unchanged.

**S27 OFX lines for Checking** (FITID `CL-0001`..`CL-0009`, ledger balance 17,835.00):

| FITID | Date | Amount | Payee or memo | Matches |
|---|---|---|---|---|
| CL-0001 | 2026-03-06 | -1,200.00 | CHECK 1041 | BP-01 |
| CL-0002 | 2026-03-10 | 4,200.00 | DEPOSIT | DEP-01 |
| CL-0003 | 2026-03-13 | 2,500.00 | JUNIPER LANE BAKERY ACH | PMT-02 |
| CL-0004 | 2026-03-20 | -200.00 | CHECK 1042 | BP-02 |
| CL-0005 | 2026-03-24 | 6,000.00 | DEPOSIT | DEP-02 |
| CL-0006 | 2026-03-25 | -500.00 | CHECK 1043 | REF-01 |
| CL-0007 | 2026-03-26 | -5,000.00 | ONLINE TRANSFER TO SAVINGS | TRF-01 |
| CL-0008 | 2026-03-27 | -450.00 | PAYMENT STUDIO VISA | TRF-02 |
| CL-0009 | 2026-03-31 | -15.00 | MONTHLY SERVICE FEE | EXP-03 (added in S28) |

**Expected trial balance, 2026-03-31, accrual:**

| Account | Debit | Credit |
|---|---|---|
| Checking | 16,335.00 | |
| Savings | 25,000.00 | |
| Accounts Receivable | 2,597.70 | |
| Equipment | 6,000.00 | |
| Accumulated Depreciation | | 100.00 |
| Studio Visa | | 168.40 |
| Sales Tax Payable - State Revenue Agency | | 47.50 |
| Sales Tax Payable - City Tax Office | | 15.20 |
| Opening Balance Equity | | 39,850.00 |
| Design Income | | 11,200.00 |
| Print Sales | | 800.00 |
| Discounts Given | 265.00 | |
| Hosting | 200.00 | |
| Office Supplies | 168.40 | |
| Contract Labor | 1,500.00 | |
| Depreciation | 100.00 | |
| Bank Fees | 15.00 | |
| **Total** | **52,181.10** | **52,181.10** |

Undeposited Funds, Accounts Payable and Retained Earnings have zero balances and are omitted.

**Expected profit and loss, March 2026:**

| Line | Accrual | Cash basis |
|---|---|---|
| Design Income | 11,200.00 | 8,906.88 |
| Print Sales | 800.00 | 392.33 |
| Discounts Given | (265.00) | (129.96) |
| **Total income** | **11,735.00** | **9,169.25** |
| Hosting | 200.00 | 200.00 |
| Office Supplies | 168.40 | 168.40 |
| Contract Labor | 1,500.00 | 1,500.00 |
| Depreciation | 100.00 | 100.00 |
| Bank Fees | 15.00 | 15.00 |
| **Total expenses** | **1,983.40** | **1,983.40** |
| **Net income** | **9,751.60** | **7,185.85** |

The cash-basis Unapplied customer payments line is 0.00 for March: PMT-03's 500.00 was recognized on 2026-03-23 and released on 2026-03-25 by REF-01. Cash-basis sales tax recognized is State 23.30 and City 7.45.

**Expected balance sheet, 2026-03-31:**

| Line | Accrual | Cash basis |
|---|---|---|
| Checking | 16,335.00 | 16,335.00 |
| Savings | 25,000.00 | 25,000.00 |
| Undeposited Funds | 0.00 | 0.00 |
| Accounts Receivable | 2,597.70 | 0.00 |
| Equipment | 6,000.00 | 6,000.00 |
| Accumulated Depreciation | (100.00) | (100.00) |
| **Total assets** | **49,832.70** | **47,235.00** |
| Accounts Payable | 0.00 | 0.00 |
| Studio Visa | 168.40 | 168.40 |
| Sales Tax Payable - State Revenue Agency | 47.50 | 23.30 |
| Sales Tax Payable - City Tax Office | 15.20 | 7.45 |
| **Total liabilities** | **231.10** | **199.15** |
| Opening Balance Equity | 39,850.00 | 39,850.00 |
| Retained Earnings | 0.00 | 0.00 |
| Net income | 9,751.60 | 7,185.85 |
| **Total equity** | **49,601.60** | **47,035.85** |
| **Total liabilities and equity** | **49,832.70** | **47,235.00** |

**Expected AR aging, 2026-03-31:**

| Contact | Current | 1-30 | 31-60 | 61-90 | 91+ | Total |
|---|---|---|---|---|---|---|
| Juniper Lane Bakery (INV-1002, due 2026-04-01) | 2,597.70 | | | | | 2,597.70 |
| **Total** | **2,597.70** | | | | | **2,597.70** |

**Expected AP aging, 2026-03-31:** no open items (total 0.00).

**Expected sales tax liability, March 2026 (accrual):**

| Agency | Taxable base | Tax | Payments | Balance |
|---|---|---|---|---|
| State Revenue Agency | 760.00 | 47.50 | 0.00 | 47.50 |
| City Tax Office | 760.00 | 15.20 | 0.00 | 15.20 |

**Expected reconciliation (S29):** beginning balance 12,500.00, cleared 5,335.00, ending balance 17,835.00, difference 0.00, book balance 16,335.00, outstanding check 1044 (1,500.00).

**Negative expectations:**

- S27 re-import inserts 0 lines.
- S28 agent post returns 403 `auth.agent_forbidden`.
- S30 lock errors as listed.
- Voided INV-1004 does not appear in the aging.
- EXP-01 shows revision 2 with three journal entries.
- `verify` passes at the end.
