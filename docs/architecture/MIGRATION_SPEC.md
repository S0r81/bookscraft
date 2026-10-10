# Migration specification

Status: accepted (2026-10-10). Owner: `import-migration-engineer`. Crates: `interchange`, `qbo`, `iif` (MIT, pure) and `migrate` (AGPL). Decision record: [ADR-0017](../adr/0017-qbo-migrator-access.md). MVP exit criterion: a real agency migrates from QuickBooks Online and closes a month with a trial balance that matches QuickBooks to the cent ([ROADMAP.md](../roadmap/ROADMAP.md)).

## 1. Paths

| Path | Source | MVP? | Validation |
|---|---|---|---|
| QBO API | QuickBooks Online REST API (OAuth 2.0), full history | **MVP** (W3-03 mapper, W3-04 pipeline, W4-03 connector) | Trial balance at every month-end and AR/AP aging per contact, to the cent |
| QBO API, cut-over mode | Opening balances at a cut-over date plus the open AR/AP items, then later transactions (G-16 option) | **v1** | Trial balance from the cut-over date |
| CSV / XLSX lists | Accounts, contacts, items; opening trial balance | **MVP** (W3-04) | Row-level validation; opening TB must balance |
| CSV / OFX bank lines | Statement lines | **MVP** (W2-03, banking) | Dedupe (I-7) |
| Interchange bundle | BooksCraft's own export (round trip, or produced by third-party tools) | **MVP** (W3-04) | Round trip: trial balance identical |
| IIF | QuickBooks Desktop lists and transactions | **v1** (parser, writer and import path; the `iif` crate is a stub until then) | Trial balance by month (no reliable links, section 8) |
| Desktop transactions | Journal or General Ledger report exported to CSV or XLSX | **v1** | Trial balance by month |
| QBW files | — | **never** (clean room, C-11) | — |

## 2. Principles

| Principle | Rule |
|---|---|
| Clean room | Mapping is built only from Intuit's public API reference and published file formats. No Intuit UI copy, screenshots or icons. |
| New file by default | A migration creates a new company file. Importing into an existing company is allowed for CSV lists and bank lines only. |
| Lossless | Every imported row keeps its raw source record in `external_ref.payload_json`. Entities BooksCraft does not model are kept verbatim in `import_archive`. |
| Idempotent (I-7) | `external_ref` is unique on `(source, realm, external_type, external_id)`. A re-run creates nothing that already exists (section 9). |
| Same rules as people | Imported documents go through the same service commands and posting rules (`via = import`, actor = the importing user). The only import-only allowances: source amounts are kept as received (LEDGER_SPEC §8.1), tax mode `inclusive` is accepted, and `is_residual` journal entries can be created. |
| Verified | Each run ends with validation (section 6). Its result is stored on `import_run.validation_json` and shown to the user. |
| Reversible | Each run starts with an automatic backup and can be rolled back (section 10). |

## 3. Interchange model and bundle (crate `interchange`, MIT)

The interchange model is the neutral layer between every source and the services. It is also the documented "you can leave" export format (brief §4.3).

| Entity | Key fields |
|---|---|
| `Company` | name, legal name, base currency, fiscal year start month, address |
| `Account` | key, code, name, class, subtype, detail, parent key, currency, system role, archived |
| `Contact` | key, display name, names, roles, parent key, email, phone, addresses, tax id, 1099 flag, taxable, default terms key, currency, archived |
| `Item` | key, name, sku, kind, parent key, sales and purchase descriptions, prices, account keys, taxable, components |
| `Term`, `PaymentMethod`, `TaxAgency`, `TaxRate`, `TaxCode`, `Dimension`, `DimensionValue`, `CustomFieldDef` | fields as in DATA_MODEL.md |
| `Document` | key, doc type, status (posted or voided), number, date, due date, contact key, currency, fx rate, account keys, tax code key, tax mode, discount, totals as received, lines (with keys, amounts, tax), tax lines, dimension values, custom fields, attachments |
| `Settlement` | event document key, charge key, credit key, amount, date |
| `Link` | from key, to key, type |
| `Attachment` | key, file name, content type, sha256, path inside the bundle |
| `SourceRef` | entity key, source, realm, external type, external id, sync token, raw payload |

**Keys** are strings unique within a bundle: the source's id prefixed by its type, for example `qbo:Invoice:145`.

**Amounts** are `money::Money`. **Dates** are ISO strings.

**Bundle file** (`.zip`, written by `export`):

| Entry | Content |
|---|---|
| `manifest.json` | `{"format": "bookscraft-interchange", "version": 1, "created_at", "company", "counts", "sha256" per file}` |
| `<entity>.jsonl` | One JSON object per line, one file per entity type, in import dependency order |
| `csv/<entity>.csv` | Flat CSV copies of lists and a journal CSV (one row per posting) for spreadsheet users |
| `attachments/<sha256>` | Attachment bytes |

The interchange JSON schema is published in `docs/architecture/interchange-v1.md` (written by W1-04). A breaking change requires `version: 2`.

## 4. QBO API import

### 4.1 Access (ADR-0017)

| Topic | MVP rule |
|---|---|
| App credentials | The owner's own Intuit developer app. Its client id and secret live in the server config file, or are pasted once into the desktop app's settings (stored via `SecretStore`). BooksCraft ships no client secret. |
| Server mode | Authorization-code flow with PKCE. Redirect URI `https://<server>/api/v1/companies/{cid}/imports/qbo/callback`, which must be registered in the owner's Intuit app. State and verifier live in `oauth_state` (10 minutes). |
| Desktop mode | Intuit's production keys do not accept a localhost redirect (secondary source, BRIEF_AUDIT §7.4). MVP offers two options. (a) Paste: the user obtains tokens with their own Intuit app (for example from the OAuth playground) and pastes `realm_id`, access token and refresh token into `POST .../imports/qbo/token`. (b) Run the migration in server mode, then open the resulting company file on the desktop. A hosted relay is v1, gated on a human review of Intuit's developer terms. |
| Tokens | Stored through `SecretStore` (purpose `qbo_oauth`). The access token is refreshed with the refresh token when it expires. Tokens are deleted when the import run finishes, unless the user keeps the connection for re-runs. |
| Requests | Base URL `https://quickbooks.api.intuit.com/v3/company/{realmId}/`, `minorversion` pinned in config (default 75, per the brief §4.1; verified against Intuit's docs in W4-03), `Accept: application/json`. Reads use the `query` endpoint (`SELECT * FROM <Entity> STARTPOSITION n MAXRESULTS 1000`) and the Reports API for validation. |
| Rate limits | The client stays under the documented limits (500 requests per minute per realm, 10 concurrent): at most 4 concurrent requests and 300 per minute, retrying 429 and 5xx with exponential backoff (1 s → 32 s, 6 attempts). |
| Metering | Reads are metered by Intuit (CorePlus). Before starting, the wizard estimates the request count from entity counts (`SELECT COUNT(*)`), plus two report calls per month-end, and shows it. |

### 4.2 Import order

Entities are fetched and imported in dependency order. Within one type, rows are processed by `TxnDate`, then `Id` (lists: parents before children).

| Step | Entities | Notes |
|---|---|---|
| 1 | CompanyInfo, Preferences | Company record and settings; refuse multi-currency companies in MVP (`import.multi_currency_unsupported`, LEDGER_SPEC §8.2) |
| 2 | Account | Parents first; system roles (section 4.3) |
| 3 | Term, PaymentMethod | |
| 4 | TaxAgency, TaxRate, TaxCode | Liability accounts per agency (section 4.3) |
| 5 | Class, Department | Dimension values (presets Class and Location) |
| 6 | Customer (parents first), Vendor, Employee | Contacts with role flags |
| 7 | Item | Categories and parents, then items, then groups (bundles) |
| 8 | Estimate | Non-posting |
| 9 | Invoice, CreditMemo, SalesReceipt, RefundReceipt | Charges and their credits; settlements come later from payments |
| 10 | Bill, VendorCredit | |
| 11 | Purchase (expense, check, card charge, card credit) | |
| 12 | JournalEntry | AR/AP lines become open items |
| 13 | Payment, BillPayment | Rebuild settlements (section 5) |
| 14 | Deposit | Link deposit lines to payments and receipts (section 5) |
| 15 | Transfer, CreditCardPayment | Transfers |
| 16 | Attachable | Download bytes, link to entities |
| 17 | PurchaseOrder, TimeActivity, Budget, InventoryAdjustment, and anything else | `import_archive` |
| 18 | Validation | Section 6 |

Each document is imported with the documented service command in the state QBO reports:

- posted;
- voided (QBO voided transactions have zero amounts: imported as posted with no entry, then voided with no reversal, keeping number and date);
- estimates with their status.

### 4.3 Mapping rules that need judgement

| Topic | Rule |
|---|---|
| Account types | The `qbo` crate holds a data table from QBO AccountType and AccountSubType to BooksCraft class, subtype and system role. It is built and verified against Intuit's current API reference in W3-03 (CV-7). Unknown subtypes map by AccountType and keep the raw value in `account.detail`. |
| Several AR or AP accounts | Each is imported. The one QBO lists first with subtype AccountsReceivable or AccountsPayable gets the system role; documents keep their own `ARAccountRef` or `APAccountRef`. |
| Sales tax liability | Each QBO TaxAgency gets its own BooksCraft liability account. If QBO books several agencies' tax to one account, the BooksCraft agency accounts are created as sub-accounts of that account, so the parent's total matches QBO's trial balance line. Tax amounts come from `TxnTaxDetail.TaxLine` as received. |
| Discount lines | DiscountLineDetail becomes the document discount (percent or amount, discount account). A second discount line on one document is imported as a negative item line on that discount account, with warning `import.discount_lines_merged`. |
| Group (bundle) lines | GroupLineDetail becomes a group line plus its component lines (`group_line_no`); components post. |
| Inventory items | Imported as kind `inventory` with their asset account. COGS and inventory postings that QBO computes, and that are not visible on the documents, surface as month-end trial balance differences and become residual journal entries (section 6). Native FIFO inventory is "later". |
| Customer refunds paid by check | A Purchase with an AR line for a customer, linked from a Payment, is imported as an `expense` with an AR account line (a charge on AR, LEDGER_SPEC §5) plus the settlement, whose event is the linking payment. The native `customer_refund` document is for refunds entered in BooksCraft. |
| Vendor refunds | A Deposit line linked to a VendorCredit is imported as a `vendor_refund` document (date = the deposit's date, money account = undeposited funds, settlement with the vendor credit, event = the refund) plus a `deposit_source` line for it in the imported deposit. The deposit's total and the trial balance therefore match QBO, and undeposited funds nets to zero. |
| Credit card payments | QBO CreditCardPayment (or a Transfer to a card account) becomes a `transfer` into the card account. |
| Projects | Sub-customers flagged as projects keep the contact hierarchy. The Project dimension mapping is v1. |
| Employees | Imported as contacts with the employee role. Payroll transactions (if the API exposes them as journal entries) import as journal entries; otherwise they appear as residuals (G-17). |
| Custom fields | Definitions matched by name; values on documents kept. |
| Attachments | Downloaded from the Attachable temporary download URL and stored in the company file (deduplicated by SHA-256). |
| Names | Display names are unique across contacts. A clash, which QBO itself prevents, gets the suffix ` (2)` and warning `import.name_suffixed`. |

## 5. Link reconstruction

| QBO structure | BooksCraft result |
|---|---|
| `Payment.Line[]`, each with one `LinkedTxn` to an Invoice, JournalEntry or CreditMemo, and an Amount | The payment's credit lines (CreditMemo, or a JournalEntry credit) and charge lines (Invoice, or a JournalEntry debit) are paired greedily in line order. Credits are applied first, then the payment's own amount. One `settlement` row is written per pair, with event = payment and date = the payment's TxnDate. `UnappliedAmt` remains the payment's open credit. Pairing order does not change any document's open amount or recognition date, so aging and cash basis are unaffected. |
| `BillPayment.Line[]` with `LinkedTxn` to a Bill, VendorCredit or JournalEntry | Same algorithm on AP |
| `Deposit.Line[]` with `LinkedTxn` to a Payment, SalesReceipt or RefundReceipt (or a transfer from undeposited funds) | `deposit_source` lines pointing at the imported source documents (a refund receipt paid from undeposited funds is a negative source, LEDGER_SPEC §4.14) |
| `Deposit.Line[]` with `LinkedTxn` to a VendorCredit | a `vendor_refund` document plus its `deposit_source` line (section 4.3) |
| `Deposit.Line[]` without a link | account lines (cash back is a negative line) |
| `Invoice.LinkedTxn` to an Estimate | `document_link (converted_from)` |
| `CreditMemo` applied on its own (no payment) | QBO records credit memo applications through payments. A credit memo that QBO reports as fully applied with no linking payment gets a settlement whose event is the credit memo, paired with invoices of the same customer by oldest due date, and warning `import.application_inferred`. |
| Payment dated before the invoice it pays | Accepted with warning `sales.payment_before_charge` (LEDGER_SPEC §5 rule 5) |

After links are rebuilt, each imported document's open amount must equal QBO's `Balance` field: error `import.balance_mismatch` lists every difference.

## 6. Validation

| Check | Method | Pass condition | Gating |
|---|---|---|---|
| Month-end trial balance | For every month-end `M` from the first imported month to the last, fetch QBO `Reports/TrialBalance?end_date=M&accounting_method=Accrual` and compare each account (mapped through `external_ref`) with BooksCraft's trial balance as of `M` | Every account equal to the cent, every month | **yes** |
| AR and AP aging per contact | Fetch QBO `Reports/AgedReceivables` and `Reports/AgedPayables` as of the last imported date; compare the total per contact | Every contact equal to the cent | **yes** |
| Document balances | QBO `Balance` field vs BooksCraft open amount (section 5) | Equal | **yes** |
| Cash-basis P&L | QBO `Reports/ProfitAndLoss?accounting_method=Cash` per month vs BooksCraft cash basis | Reported with differences per account and month | no (MVP measures it; R-3) |
| Counts | Entities fetched vs created vs archived vs skipped (with reasons) | Every fetched row accounted for | **yes** |

**Residual reconstruction (G-17).** If the trial balance differs after the entity import, BooksCraft computes for each month `M` the change in difference: `delta_M(account) = diff_M − diff_{M−1}` (with `diff_{first−1} = 0`). It posts one journal entry dated the last day of `M`, with `is_residual = 1` and one line `−delta_M` per account. Each entry balances, because both trial balances balance. Validation then reruns and must pass.

Each residual is listed in the import report with likely causes:

- QBO-computed inventory and COGS postings;
- payroll not exposed as entities;
- archived entity types dated in that month.

Residual journal entries carry the reason in their private note and appear flagged in the GL and journal reports. The import status is `succeeded` with residuals, and the UI requires the user to acknowledge them before the first close.

**Report endpoint verification.** Report names and parameters above come from the QBO API reference. W4-03 verifies them before relying on them.

## 7. CSV and XLSX import (MVP)

| Kind | Required columns (after mapping) | Rules |
|---|---|---|
| Accounts | name, class or subtype | Optional: code, parent (by name or code), detail, description, archived. Subtype names accept BooksCraft names and common synonyms. |
| Contacts | display name, role(s) | Optional: names, email, phone, addresses, tax id, 1099, terms, notes |
| Items | name, kind | Optional: sku, description, price, cost, income account, expense account, taxable |
| Opening trial balance | account (name or code), debit, credit, as-of date | Debits must equal credits. Creates one `opening_balance` document; AR and AP rows are refused (use opening invoices and bills, LEDGER_SPEC §4.17). |
| Bank lines | date, amount (or debit and credit columns), description | Handled by banking statement import (W2-03) with dedupe |

Column mapping:

- The UI previews the first 50 rows and saves the mapping by name.
- The CLI takes a TOML mapping file (`bookscraft import csv --map mapping.toml`).
- XLSX uses the first sheet unless one is named.

Encoding is UTF-8, with Windows-1252 accepted when detected. Each row's external id is the value of a column chosen as key, or else `sha256(file name ‖ row number ‖ row content)`. Re-imports therefore skip rows already imported.

## 8. IIF import (v1)

| Topic | Rule |
|---|---|
| Format | Tab-delimited text. Header rows start with `!` (`!ACCNT`, `!CUST`, `!VEND`, `!INVITEM`, `!CLASS`, `!TRNS`, `!SPL`, `!ENDTRNS`), each followed by its data rows. Encoding is Windows-1252 unless the file is valid UTF-8. |
| Lists | `ACCNT` → accounts (ACCNTTYPE mapping table in `iif`), `CUST` and `VEND` → contacts, `INVITEM` → items, `CLASS` → Class values |
| Transactions | `TRNS` + `SPL`… + `ENDTRNS` blocks. TRNSTYPE maps to a document type (INVOICE, CREDIT MEMO, CASH SALE, PAYMENT, DEPOSIT, BILL, BILL REFUND, BILLPMT, CHECK, CREDIT CARD, GENERAL JOURNAL, TRANSFER). The splits must sum to zero with the TRNS line (`iif.unbalanced_transaction`). |
| Links | IIF carries no payment-to-invoice links. Payments are applied first-in-first-out per customer, by due date, with warning `import.application_inferred`. Aging may therefore differ from QuickBooks Desktop, so validation is by trial balance only (C-11). |
| External ids | `realm` = SHA-256 of the file; `external_id` = TRNSID or REFNUM when present, else the block's ordinal |
| Writer | `iif::write` exports lists and journal-style transactions for users moving to Desktop-compatible tools (v1 feature) |

## 9. Re-runs (idempotency and refresh)

| Situation on re-run | Action |
|---|---|
| Source row with an existing `external_ref` and the same `sync_token` | Skip; counted as `duplicate` |
| Existing ref, different `sync_token` (changed in QBO) | If BooksCraft has not changed the entity since import (its version equals the version recorded at import) and the period is open: update or repost with reason `source changed`. Otherwise report a conflict and leave it unchanged. |
| New source row | Create |
| Row deleted in QBO since the last run | Report as `missing_at_source`; never delete locally |
| Validation | Rerun for all months |

This gives one-way refresh for parallel running during cut-over. Two-way sync is not planned.

## 10. Rollback

| Case | Procedure |
|---|---|
| Migration into a new company file (default) | Rollback means discarding the new file. BooksCraft archives the registry entry and leaves the file in place for the user to delete (BooksCraft never deletes a user file). |
| Import into an existing company, no other activity since | If no audit event exists after `import_run.last_audit_seq`, restore the automatic pre-import backup under the company lock, and mark the run `rolled_back` in the restored file's registry and a new audit event. |
| Import into an existing company, with later activity | Void every document the run posted, in reverse order (append-only reversals, I-3), with reason `import rollback <run id>`; archive the list rows it created; mark the run `rolled_back` |

## 11. Export (MVP)

`POST .../exports {format: interchange}` writes the bundle (section 3). `format: csv` writes only the CSV directory. Round-trip test T-MIG-3: export the spine company, import the bundle into a new company, and compare trial balances, agings and document counts (they must be equal).

## 12. Test plan

| Test | What | WP |
|---|---|---|
| T-MIG-1 | Import the same QBO-sourced data twice: the second run creates nothing and reports all duplicates. W3-04 uses an interchange bundle carrying QBO source refs; W4-03 repeats it end to end with the recorded QBO API fixture | W3-04, W4-03 |
| T-MIG-2 | Synthetic QBO fixtures (hand-written from the public API reference: every entity type in section 4.2, discount, group, tax-inclusive, voided, unapplied, multi-AR) → golden interchange output | W3-03 |
| T-MIG-3 | Interchange round trip of the spine company | W3-04 |
| T-MIG-4 | Source rounding ±2 → rounding account; ±3 → failure | W3-04 |
| T-MIG-5 | Residual reconstruction: a fixture with a hidden COGS posting yields one residual JE per affected month, and validation passes afterwards | W3-04 |
| T-MIG-6 | Rollback in all three cases (section 10) | W3-04 |
| T-MIG-7 | QBO connector against a recorded HTTP fixture (pagination, 429 retry, token refresh) | W4-03 |
| T-MIG-8 | IIF parser: every list and transaction type; unbalanced block refused; Windows-1252 | v1 |
| Pilot | The owner migrates the agency's QBO company (sandbox first, then production) using the playbook's pilot checklist, closes one month, and compares TB and aging with QuickBooks | W5-04 |
