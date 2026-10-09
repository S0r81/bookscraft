# BooksCraft Research Brief: Reverse-Engineering QuickBooks for an Open-Source, Community-Built Alternative (October 2026)

BooksCraft has a real opening. Intuit raised QuickBooks Online (QBO) prices sharply during 2026: Plus now lists at $140/month and Advanced at $340/month. Desktop is closed to new US buyers, and its renewals keep climbing. Meanwhile, no open-source tool combines a correct double-entry ledger, a modern multi-user web interface, affordable US bank feeds, and a clean migration path off QuickBooks. The way to win is not to match every QuickBooks feature. It is to ship the parts of QBO Plus that most small businesses use (ledger, AR/AP, bank feeds and reconciliation, classes/projects, reports, accountant access), without tier gating, plus a lossless "leave QuickBooks" migrator.

## TL;DR
- **QuickBooks pricing and tiers (US, Oct 2026):** Simple Start $38, Essentials $85, Plus $140, Advanced $340 per month. Essentials, Plus and Advanced went up for renewals on or after August 1, 2026. Key features are gated by tier: bills and multi-currency need Essentials, inventory, POs, budgets and classes need Plus, and unlimited accounts and custom fields need Advanced. Intuit stopped selling new Desktop Pro Plus/Premier Plus/Mac Plus subscriptions to US customers after September 30, 2024, but in August 2026 it dropped its planned 2027 end date for Desktop 2024. Desktop is shrinking, not dying.
- **The gap BooksCraft can fill:** among existing open-source options, GnuCash is single-user desktop software. Akaunting is source-available under the BSL, not truly open source. ERPNext and Odoo are heavy ERPs, and bank sync is Enterprise-only in Odoo. Bigcapital (AGPL-3.0; 3.9k stars and 537 forks on its GitHub repo) is the closest QBO-shaped app but still immature. Invoice Ninja is invoicing only, and Frappe Books is midway through a platform change. None offers affordable US bank feeds plus a QuickBooks migrator plus accountant workflows.
- **Recommended build:** an AGPL-licensed web app (TypeScript + PostgreSQL) with an append-only, integer-cents double-entry ledger. Bank feeds via SimpleFIN, Teller or Plaid, with file import (OFX/QFX/CSV) as the always-available fallback. A QBO-API-shaped schema and importers for QBO API, IIF and CSV. An MCP/CLI "agent-ready" interface, borrowing the ArtCraft playbook. Leave payroll and sales-tax filing to partners or later versions.

---

## Key Findings

1. **Price is the top grievance, and 2026 made it worse.** For renewals on or after August 1, 2026, Essentials went from $75 to $85, Plus from $115 to $140, and Advanced from $275 to $340.\[1\] Simple Start ($38), Free, Lite and Ledger did not change.\[2\] Some secondary sources report a second increase earlier in 2026 (on May 1), and their figures conflict. One competitor's blog puts Plus at $90 in January 2026 and Advanced at $200, which would be +55% and +70% for the year.\[3\] Treat the year-over-year percentages as contested. The August list prices are confirmed on Intuit's own subscription page.\[4\]
2. **Intuit is consolidating up-market.** Advanced now bundles Bill Pay Elite and, according to several secondary sources, Workforce Elite payroll. It also gets exclusive features such as "Books Upkeep."\[5\]\[6\] Plus got a price increase with no new features to offset it.\[3\] Small businesses with simple books are being asked to pay more for features they don't use. That segment is BooksCraft's beachhead.
3. **Desktop users are the most motivated switchers.** Desktop 2023 lost connected services (bank feeds, payroll, payments, support) after May 31, 2026. Desktop Pro Plus renewals rose from $999 to $1,149 a year on February 1, 2026, and rise to $1,351 for renewals on or after October 1, 2026, per Business Solutions Inc. (bsi-dc.com), which cites Intuit's notice to ProAdvisors. Desktop users also dislike QBO's workflow, and Intuit's own community forum has threads such as "Longtime Customer Deeply Disappointed by QuickBooks Pricing and Forced Migration."\[7\]
4. **Intuit's growth engine is QBO, not Desktop.** According to Intuit's Form 10-Q for the quarter ended April 30, 2026, QBO Accounting revenue in the first nine months of fiscal 2026 was $3,732M (up 24% year over year) versus $1,271M (up 10%) for Desktop Accounting. Expect continued pressure on Desktop and continued price increases on QBO.
5. **Bank feeds are both the most-loved and the most-complained-about feature.** G2's review summary praises "automatic bank feeds" but also cites "occasional disconnection or miscategorization of bank feeds," along with high cost and "slow or inconsistent customer support."\[8\] Open-source projects have historically failed here because good aggregator access was expensive. That has improved: SimpleFIN Bridge costs $15/year, Teller has a free 100-connection tier, and Plaid has a free 10-connection trial.\[9\]\[10\]\[11\]
6. **Compliance is lighter than it looks for an MVP.** Under Section 70433 of the One Big Beautiful Bill Act (signed July 4, 2025), the 1099-NEC/MISC threshold rose from $600 to $2,000 for payments made after December 31, 2025, with inflation indexing from 2027, and the 1099-K threshold went back to $20,000 and 200 transactions. Sales-tax *calculation* is the hard part: the Tax Foundation, citing Vertex, counts over 11,000 standard sales tax jurisdictions in the US. That calls for a pluggable rate provider, not an in-house engine.

---

## 1. QuickBooks Product Lineup and Tiers (US, as of October 2026)

### 1.1 QuickBooks Online plans

| Plan | List price/mo (post-Aug 1, 2026) | Prior price | Billable users | Accountant firms | Key gated features |
|---|---|---|---|---|---|
| Solopreneur (successor to Self-Employed) | ~$20 (secondary source) | — | 1 | — | Income/expense, mileage, estimated tax; no full double-entry user experience |
| Simple Start | $38 | $38 (unchanged in Aug) | 1 | 2 | Unlimited estimates, invoices and sales receipts; bank feeds; receipt capture; automated sales tax; mileage (mobile, master admin only); 20+ reports\[4\] |
| Essentials | $85 | $75 | 3 (+ time-tracking-only users) | 2 | + Bills/AP, bill pay via Bill.com (fees), recurring transactions, multi-currency, audit log, billable time, 40+ reports\[4\] |
| Plus | $140 | $115 | 5 (+ reports-only users) | 2 | + FIFO inventory, purchase orders, project profitability, billable expenses, budgets, classes/locations (up to 40 combined), 65+ reports\[4\] |
| Advanced | $340 | $275 | 25 | 3 | + Unlimited accounts and classes/locations, up to 10 custom fields, batch invoicing (1,000 lines), detailed permissions, Fathom reporting, Priority Circle support, Bill Pay Elite included (Aug 2026), "Books Upkeep"\[4\]\[5\] |

Notes:
- **Chart-of-accounts cap:** Simple Start, Essentials and Plus allow up to 250 accounts; Advanced is unlimited.\[4\] This hard limit frustrates accountants. BooksCraft should have no limit.
- **Promotions:** Intuit routinely offers 50% off for 3 months, and new subscribers keep their price until their seventh invoice.\[4\]\[12\] The low first-year cost hides the long-term cost.
- **Intuit Enterprise Suite (IES)** sits above Advanced as an "AI-native ERP" for multi-entity businesses.\[4\] It is out of scope for BooksCraft.
- **Whether Advanced now includes payroll is disputed.** Certum Solutions and BizBooks say Workforce Elite payroll is now bundled into Advanced.\[3\]\[6\] Intuit's Advanced page still shows "Add payroll (optional)."\[13\] Treat the payroll bundle as unconfirmed.

### 1.2 Payroll, payments and other add-ons
- **Payroll was rebranded "QuickBooks Workforce."** Core, Premium and Elite became Workforce Payroll ($50 + $6.50/employee/month), Workforce Premium ($88 + $10) and Workforce Elite ($134 + $12), per FitSmallBusiness.\[14\] Some aggregators list different per-employee fees ($15/$19); treat those as unverified.\[15\] Elite includes tax-penalty protection up to $25,000 per year.\[4\]
- **QuickBooks Payments** (card/ACH on invoices) requires a separate account, subject to approval. Money movement goes through Intuit Payments Inc., which is a licensed money transmitter. **QuickBooks Checking** is provided through Green Dot Bank.\[4\]
- **1099 e-file:** preparing 1099s is free. The E-File Service costs a $14.99 minimum for 3 forms, $3.99 each for forms 4–20, and nothing for 21 and up. State filing is not included.\[4\]
- **Other paid add-ons:** QuickBooks Time (formerly TSheets), Live Bookkeeping, Bill Pay tiers.

### 1.3 QuickBooks Desktop status
- **Stop-sell:** after September 30, 2024, Intuit stopped selling new Desktop Pro Plus, Premier Plus, Mac Plus and Enhanced Payroll subscriptions to US customers. Existing subscribers can renew.\[16\] Enterprise is still sold (scales to 40 users).\[4\] Accountant editions are available through the accountant sales channel.\[17\]
- **Version sunsets:** Desktop 2023 (Pro Plus, Premier Plus, Mac Plus, Enterprise 23.0) lost connected services after May 31, 2026.\[18\] Desktop 2024 is the last Pro/Premier release.\[19\] In August 2026, Intuit said Desktop 2024 will *not* be discontinued in May 2027 and that it is moving away from the three-year lifecycle, with no announced sunset.\[18\]\[20\]
- **Renewal prices:** Pro Plus went from $999 to $1,149 a year (Feb 1, 2026). For renewals on or after Oct 1, 2026, Business Solutions Inc. (bsi-dc.com), citing Intuit's notice to ProAdvisors, lists Pro Plus/Mac Plus at $1,351 (extra seats $230→$270), Premier Plus at $1,891 (up from $1,609) and Desktop Accountant at $2,249 (up from $1,799).
- **International:** the stop-sell applies to the US only.\[16\] The UK QuickBooks edition handles VAT, including Irish and South African VAT.\[21\] International editions differ in tax handling. BooksCraft should design tax as a pluggable module from day one.

**What this means for BooksCraft:** Desktop users value local data, perpetual-feeling ownership and speed. They are the group most offended by forced cloud subscriptions. A self-hostable or local-first BooksCraft with an IIF/QBW-export importer speaks directly to them.

---

## 2. Functional Breakdown: How QuickBooks Works (and How BooksCraft Should)

### 2.1 Accounting core
- **Double-entry engine:** every transaction (invoice, bill, check, deposit, journal entry) generates balanced debit/credit postings to the general ledger. Users rarely see the postings directly. Each form has an implied posting template; for example, an invoice debits A/R and credits income and sales-tax payable for each line. **BooksCraft:** separate *source documents* (Invoice, Bill...) from *ledger entries*. Document → posting is a pure, versioned function. Posting must be idempotent and fully reproducible.
- **Chart of accounts:** QBO uses a two-level classification, *Account Type* plus *Detail Type*. The API's AccountType values include Bank, Accounts Receivable, Other Current Asset, Fixed Asset, Other Asset, Accounts Payable, Credit Card, Other Current Liability, Long Term Liability, Equity, Income, Cost of Goods Sold, Expense, Other Income and Other Expense. Detail types (e.g., Checking, Savings, UndepositedFunds, Inventory, RetainedEarnings) drive special behavior. System accounts such as Undeposited Funds ("Payments to deposit"), A/R, A/P, Retained Earnings, Opening Balance Equity and Sales Tax Payable are auto-created; QBO will recreate Undeposited Funds if deleted.\[22\] Up to 250 accounts below Advanced. Sub-accounts are supported.
- **Journal entries:** a manual multi-line JE where debits must equal credits. A/R and A/P lines require a customer or vendor name.
- **General ledger and trial balance:** reports derived from postings.
- **Closing the books:** QBO doesn't create year-end closing entries. Net income rolls into Retained Earnings when reports are calculated. "Close the books" sets a closing date with either a warning or a required password before anyone edits earlier transactions. This is the equivalent of Desktop's "closing date password."\[23\]\[24\] **BooksCraft:** implement real period locks (open, soft-locked, hard-locked) and allow corrections only through dated reversing entries in an open period. That is stronger than QBO's warning-plus-password model.
- **Accrual vs cash:** QBO stores accrual data and renders cash-basis reports by recognizing income and expenses when the payment that settles them occurs. **BooksCraft:** store one accrual ledger and compute cash basis through payment-application links (the same LinkedTxn graph described below). Don't keep two ledgers.

### 2.2 Sales / AR
- **Customers** (with sub-customers/projects), **Products & Services items** (Service, Non-inventory, Inventory, Bundle/Group, Category), **Estimates** (convertible to invoices, optionally partial), **Invoices**, **Sales receipts** (sale and payment in one step), **Credit memos**, **Refund receipts**, **Receive payment** (applied to invoices and credits), **Bank deposits** (grouping payments out of Undeposited Funds so they match the bank's single deposit line),\[25\]\[26\] **Recurring transactions** (scheduled, reminder or unscheduled templates; Essentials and up), **Payment links and online invoice payments** (require QuickBooks Payments).
- **Linking:** in the API, payments link to invoices through `Payment.Line.LinkedTxn` (TxnId + TxnType). A single payment can be applied across several invoices and credit memos.\[27\]\[28\] This application graph is the most important structure to get right, because AR aging, cash-basis reporting and the "open balance" all depend on it.

### 2.3 Expenses / AP
- **Vendors**, **Bills** (Essentials and up), **Bill payments** (check or credit card), **Bill Pay** (ACH/check via Bill.com/Melio partnerships; Bill Pay Elite bundled in Advanced), **Purchase orders** (Plus and up; non-posting documents that convert to bills), **Expenses** (the API's `Purchase` entity, covering cash, check or card), **Checks**, **Vendor credits**, **Receipt capture/OCR** (mobile and email-in; creates a draft expense that is matched against the bank feed), **Mileage** (mobile GPS; only the master admin). **BooksCraft:** POs and estimates are *non-posting* documents. Model them as documents with no ledger impact.

### 2.4 Banking
- **Bank connections:** QBO uses aggregator connections that a bank can break with a security change. A 2026 example is Bank of America's login-security update, which forced users to delete and recreate their feed connection. Transactions typically lag about 24 hours. Manual fallback: upload CSV, QFX, QBO or OFX files.\[29\]\[30\]
- **Bank feed workflow:** imported transactions land in "For review." Each can be **matched** to an existing transaction (e.g., an open invoice payment or a deposit made from Undeposited Funds), **added/categorized** as a new transaction, **transferred**, or **excluded**. **Bank rules** use conditions (description, amount, bank text) to set payee, account and class, and can auto-add. Intuit's Accounting Agent now proposes categories and learns from them ("policy memory").\[31\]
- **Reconciliation:** choose an account and enter the statement ending date and balance. Tick cleared items until the difference is $0. Save a reconciliation report. Editing a reconciled transaction later breaks the reconciliation, which is a common source of accountant pain. **BooksCraft:** keep a cleared/reconciled flag per ledger line and the reconciliation as an immutable record. Warn loudly, and log to the audit trail, whenever someone changes a reconciled line.
- **Undeposited Funds:** an Other Current Asset clearing account that holds received payments until a Bank Deposit groups them. Payments processed through QuickBooks Payments clear automatically.\[22\]

### 2.5 Sales tax, 1099, payroll
- **Sales tax:** QBO's automated sales tax uses the customer's address to calculate rates by jurisdiction, tracks liabilities by agency, and records filings and payments. US complexity: the Tax Foundation, citing Vertex, counts over 11,000 standard sales tax jurisdictions (Texas alone has 1,659). 45 sales-tax states plus DC enforce economic nexus. The usual threshold is $100,000; California, Texas and New York use $500,000, and New York also requires 100 transactions. Alabama and Mississippi use $250,000. Rules keep changing: Illinois dropped its transaction test on January 1, 2026, and Kentucky followed on August 1, 2026.\[32\]\[33\]
- **1099:** tag vendors as 1099-eligible, map expense accounts to 1099 boxes, and run a threshold report. For 2026 payments the NEC/MISC threshold is $2,000, indexed to inflation from 2027. Card and third-party-network payments are excluded because they are reported on the 1099-K ($20,000 *and* 200 transactions).\[34\]\[35\] States differ: a May 19, 2026 Thomson Reuters review says California has adopted the $2,000 threshold beginning with tax year 2026, while Mississippi and Wisconsin remain at $600; Colorado follows the federal figure through rolling conformity to the federal tax code.
- **Payroll:** full-service payroll (gross-to-net, federal/state/local withholding, filings, direct deposit, W-2s) is a regulated, liability-bearing service. **BooksCraft should not build it** before v2. Instead, import payroll journals from Gusto, OnPay or similar via CSV or API.

### 2.6 Operations
- **Inventory:** Plus and up. FIFO valuation only.\[4\] Quantity on hand, reorder points, COGS posted at sale. Inventory adjustments. (Desktop Enterprise has advanced inventory with lots, bins and average cost.)
- **Projects/job costing:** projects are sub-customers. Profitability comes from income, billable expenses and time, and payroll cost allocation by class or project, which requires Workforce Premium/Elite on Plus or above.\[4\]
- **Time tracking:** billable time entries per customer (Essentials+); deeper features in QuickBooks Time.
- **Classes and locations:** two built-in reporting dimensions, at line level (class) or transaction level (location). Up to 40 combined on Plus; unlimited on Advanced; not available on Simple Start or Essentials.\[4\] **BooksCraft:** use generic *dimensions* (tags with hierarchies) with no cap. Class and Location become two preset dimensions.
- **Budgets:** Plus and up; by account, optionally by class/location/customer.
- **Multi-currency:** Essentials and up. Home currency is fixed once enabled; per-transaction exchange rates; realized/unrealized gain/loss. In QBO, turning on multi-currency is irreversible, which is a common complaint. BooksCraft should make it reversible where no foreign-currency transactions exist.

### 2.7 Reporting
- **Reports:** P&L, Balance Sheet, Statement of Cash Flows, AR/AP aging (summary/detail), Trial Balance, General Ledger, Journal, Sales by Customer/Item, Expenses by Vendor, 1099 summary, Sales Tax Liability, Budget vs Actuals, Project profitability. 20+, 40+ and 65+ reports by tier. Advanced adds custom report builder, Fathom and Spreadsheet Sync.
- **BooksCraft:** every report is a query over the postings table, filtered by dimensions and date and run on accrual or cash basis. Build a single report engine (group by account/dimension/period, compare periods), not 65 hand-coded reports.

### 2.8 Users, accountants, audit
- Users by tier: 1/3/5/25, plus unlimited reports-only and time-only users.\[4\] Roles include Primary/Master admin, Company admin, Standard (full or limited), and custom roles on Advanced. **Accountant access:** firms connect through QuickBooks Online Accountant (QBOA), 2 firms (3 on Advanced),\[4\] without using up a user seat. **Audit log** (Essentials+) records who changed what. **Multi-company:** one company per subscription; accountants switch between clients in QBOA.
- **BooksCraft:** unlimited users. Role-based access control with record-level scopes. A first-class "Accountant workspace" for multiple clients. An append-only audit log that records every change.

### 2.9 AI and automation (Intuit's 2025–2026 push)
- Intuit Assist launched in 2023.\[21\] On July 1, 2025, Intuit launched a "virtual team" of AI agents: Accounting (categorization, anomaly detection, reconciliation help), Payments (late-payment prediction, reminders; "paid an average of 5 days faster" per Intuit), Customer (lead capture from email, CRM), Finance (forecasts, variances), Payroll, and Project Management. Intuit claims they save "up to 12 hours a month."\[36\]\[37\]\[38\] In 2026, "Intuit Intelligence" added conversational BI (beta) and agents that carry out tasks, a Business Tax Agent (beta), and QuickBooks access from inside ChatGPT and Claude.\[5\]\[31\]\[39\]
- **Tier gating:** Accounting and Payments agents require Essentials or above, Customer and Sales Tax agents require Plus, and the Finance Agent requires Advanced.\[40\]
- **BooksCraft angle:** expose a typed, permission-scoped tool API (an MCP server) so users can bring *any* model, including local ones. AI should never post directly: it creates *draft* transactions that need human approval, and those approvals are recorded in the audit log.

### 2.10 Mobile
- QBO mobile (iOS/Android) offers invoicing and payments, receipt capture, mileage (GPS), bank-feed review, dashboards, and mobile signatures. **BooksCraft:** a responsive PWA first, with the camera used for receipt capture. Build native apps later.

---

## 3. Feature Matrix

Complexity: S = days, M = weeks, L = 1–3 months, XL = multi-quarter or regulated.

| Feature | Description | QBO tier | Complexity | BooksCraft priority |
|---|---|---|---|---|
| Double-entry ledger (immutable postings, reversals) | Balanced entries enforced in the DB; corrections only by reversal | All | M | **MVP** |
| Chart of accounts (types/detail types, sub-accounts, unlimited) | QBO-compatible type taxonomy + US templates | All (250 cap below Advanced) | S | **MVP** |
| Manual journal entries | Multi-line, attachments, reversing JE | All | S | **MVP** |
| Customers, vendors, items | Contacts + Service/Non-inventory items | All | S | **MVP** |
| Invoices, sales receipts, payments, credit memos | With payment-application graph | All | M | **MVP** |
| Estimates → invoice | Non-posting document conversion | All | S | **MVP** |
| Bills, bill payments, vendor credits | AP subledger | Essentials+ | M | **MVP** (key difference from QBO tiers) |
| Expenses/checks (Purchase) | Cash/check/card spend | All | S | **MVP** |
| Bank file import (OFX/QFX/QBO/CSV) | Dedupe by FITID/hash | All | M | **MVP** |
| Bank feed review: match/add/transfer/exclude + rules | Core daily workflow | All | L | **MVP** |
| Reconciliation | Statement-based, immutable reports | All | M | **MVP** |
| Undeposited funds + bank deposits | Group payments to match bank deposit | All | S | **MVP** |
| Core reports (P&L, BS, TB, GL, AR/AP aging) | Accrual and cash basis | All | M | **MVP** |
| Period close / lock dates | Soft/hard lock, audited overrides | All | S | **MVP** |
| Audit log | Append-only, hash-chained | Essentials+ | S | **MVP** |
| Multi-user + roles + accountant access | Unlimited users, client switcher | Tiered (1/3/5/25) | M | **MVP** (basic roles) / v1 (accountant workspace) |
| QuickBooks migration (QBO API pull, IIF, CSV) | Lossless import of lists + transactions + opening balances | n/a | L | **MVP** (QBO API + CSV), v1 (IIF) |
| Live bank feeds (SimpleFIN / Teller / Plaid adapters) | Pluggable aggregator connectors | All | M per connector | v1 (SimpleFIN in late MVP) |
| Recurring transactions | Scheduled/reminder templates | Essentials+ | S | v1 |
| Classes/locations → generic dimensions | Unlimited tags on lines | Plus+ | M | v1 |
| Projects / job costing | Project dimension + profitability report | Plus+ | M | v1 |
| Time tracking (billable) | Time entries → invoice lines | Essentials+ | M | v1 |
| Budgets + budget vs actual | Per account/dimension/period | Plus+ | M | v1 |
| Cash-flow statement (indirect) | Derived from BS changes + mapping | All | M | v1 |
| Custom report builder / dashboards | Group-by/filter/compare engine | Advanced (custom builder) | L | v1 |
| Online invoice payments (Stripe/PayPal links) | Payment link, webhook → payment + fee | Requires QB Payments | M | v1 |
| Sales tax (manual rates + agency liability) | Tax codes, rates, combined rates, liability report | All | M | v1 |
| Sales tax (automated rates by address) | Pluggable provider (rate APIs/tables) | All (auto) | L | later |
| 1099 tracking + forms (PDF; e-file via partner) | Vendor flag, box mapping, $2,000 rule | All (e-file paid) | M | v1 (tracking), later (e-file) |
| Receipt capture / OCR | Upload/email-in, OCR → draft expense, match to feed | All | M | v1 (BYO OCR/LLM) |
| Multi-currency | FX rates, revaluation, gain/loss | Essentials+ | L | v1 |
| Inventory (FIFO) | Qty, cost layers, COGS at sale, adjustments | Plus+ | L | later (v1.5) |
| Purchase orders | Non-posting, convert to bills | Plus+ | S | later (with inventory) |
| Mileage tracking | Manual + GPS (mobile) | All | S/M | later |
| Custom fields | Typed fields on entities/transactions | Advanced (10) | M | v1 (unlimited) |
| Batch transactions (bulk import/edit) | CSV/grid bulk entry | Advanced | M | v1 |
| Approval workflows | AP/expense approvals | Advanced | M | later |
| AI agents (categorize, reminders, Q&A) | Draft-only, human-approved, BYO model via MCP | Essentials+ (varies) | M | v1 (MCP + rule suggestions), later (agents) |
| Payroll | Full-service payroll + filings | Add-on | XL (regulated) | later / partner import only |
| Bill pay (ACH out) | Money movement | Add-on / Advanced | XL (licensing) | partner integration only |
| Mobile app | Receipt, invoice, feed review | All | M (PWA) / L (native) | v1 (PWA) |
| Multi-entity / consolidation | Intercompany, consolidated reports | IES | XL | later |

---

## 4. Data Model and Interoperability

### 4.1 The QBO API entity model (what to be compatible with)
- **Lists/names:** Account, Customer (with sub-customers/jobs), Vendor, Employee, Item, Class, Department (the API name for *Location*), TaxCode/TaxRate/TaxAgency, Term, PaymentMethod, CompanyInfo, Preferences, Currency/ExchangeRate, Budget, Attachable.
- **Transactions:** Invoice, Estimate, SalesReceipt, CreditMemo, RefundReceipt, Payment, Deposit, Transfer, Bill, BillPayment, VendorCredit, Purchase (expense/check/card charge), PurchaseOrder, JournalEntry, TimeActivity, InventoryAdjustment.
- **Structure:** each transaction has a header (TxnDate, DocNumber, CustomerRef/VendorRef, CurrencyRef, PrivateNote) and a `Line[]` array. Each line has a `DetailType`. Sales types include SalesItemLineDetail, GroupLineDetail, DescriptionOnly, DiscountLineDetail and SubTotalLineDetail.\[41\] Purchase types include AccountBasedExpenseLineDetail and ItemBasedExpenseLineDetail; journal entries use JournalEntryLineDetail.
- **Relationships:** `*Ref` objects (value = Id, name) point to list entities. `LinkedTxn` (TxnId, TxnType) connects transactions, e.g., Payment → Invoice/CreditMemo, Estimate → Invoice, PurchaseOrder → Bill, ReimburseCharge → Invoice.\[42\]
- **Concurrency:** every entity carries `SyncToken` for optimistic locking; a stale token returns error 5010. Requests are pinned to a `minorversion` (e.g., 75).\[43\]\[44\] Custom fields are `CustomField[]` with DefinitionId.\[45\]

### 4.2 Proposed BooksCraft core data model (summary)

```
organization(id, name, base_currency, fiscal_year_start, tax_profile, settings)
user, membership(org_id, user_id, role_id), role(permissions jsonb)   -- unlimited users
account(id, org_id, code, name, type, detail_type, parent_id, currency, is_system, archived)
contact(id, org_id, kind[customer|vendor|employee|other], parent_id, display_name,
        billing/shipping addr, tax_id, is_1099, default_terms, currency)
item(id, org_id, kind[service|non_inventory|inventory|bundle], income_acct, expense_acct,
     asset_acct, price, cost, tax_code_id)
dimension(id, org_id, name[e.g. Class, Location, Project]), dimension_value(id, dimension_id, parent_id)

document(id, org_id, type[invoice|bill|payment|deposit|expense|journal|estimate|po|credit_memo|...],
         number, date, due_date, contact_id, currency, fx_rate, status[draft|posted|void],
         source[ui|import|api|agent], external_ids jsonb {qbo_id, iif_ref}, version)
document_line(id, document_id, line_no, kind, item_id, account_id, qty, unit_price_minor,
              amount_minor, tax_code_id, description, dimensions jsonb/link table)
document_link(from_doc, to_doc, amount_minor, link_type[applies_to|converted_from|reimburses])  -- ≈ LinkedTxn

journal_entry(id, org_id, document_id, posted_at, effective_date, reverses_entry_id, hash, prev_hash)
posting(id, journal_entry_id, account_id, contact_id, amount_minor BIGINT (+debit/−credit),
        currency, amount_base_minor, dimension_values, cleared_state, reconciliation_id)
  -- constraint: SUM(amount_base_minor) = 0 per journal_entry (deferred trigger)
  -- postings are INSERT-only; edits = reversal entry + new entry

period_lock(org_id, lock_date, kind[soft|hard], set_by, set_at)
bank_connection(id, org_id, provider[simplefin|teller|plaid|file], credentials_ref, status)
bank_txn(id, account_id, provider_txn_id/fitid, date, amount_minor, payee_raw, memo, status
         [for_review|matched|added|excluded], matched_document_id, rule_id)
bank_rule(id, org_id, priority, conditions jsonb, actions jsonb, auto_apply)
reconciliation(id, account_id, statement_date, statement_balance_minor, status, closed_at, snapshot)
tax_code/tax_rate/tax_agency; tax_liability view
attachment(id, org_id, document_id, blob_ref, ocr_json)
audit_event(id, org_id, actor[user|api|agent], action, entity, before jsonb, after jsonb, at, hash_chain)
```

Design rules:
1. **Money as integers in minor units (BIGINT)** plus an ISO currency code. FX rates are stored as NUMERIC(20,10). Never use floats. Round each line using banker's rounding or the jurisdiction's tax rounding rule, and record the rounding difference in an explicit rounding account.
2. **Documents are mutable while in draft. Ledger postings are append-only.** Editing a posted document creates a reversing journal entry and a new entry, both linked to the document version. Each audit event is hash-chained to the previous one, which makes tampering detectable.
3. **Store one accrual ledger. Derive cash basis** through the document_link payment graph.
4. **Keep external IDs (QBO Id, IIF refs)** on every imported row. This makes migration idempotent and allows two-way sync during parallel running.
5. **Make dimensions generic.** QBO's Class, Location and Project map onto dimension values.

### 4.3 Import/export formats
| Format | What it is | QuickBooks support | BooksCraft action |
|---|---|---|---|
| **QBO API (JSON)** | REST entities above | Online read/write (OAuth 2.0) | **MVP migrator:** pull all lists + transactions + attachments; map 1:1 |
| **IIF** | Tab-delimited; `!TRNS`/`!SPL`/`ENDTRNS` blocks; `!ACCNT`, `!CUST` lists; splits must sum to zero | Desktop import/export only; QBO cannot import or export IIF\[46\]\[47\] | v1 parser/writer (publish as MIT library) |
| **QBO/QFX/OFX (Web Connect)** | Bank statement formats with FITID | Desktop (QBO ≤3 yrs old) and Online bank upload\[48\] | **MVP** bank import |
| **CSV/XLSX/Google Sheets** | Lists and bank lines | QBO list import; Desktop export\[49\] | **MVP** with column-mapping UI |
| **Report exports (Excel/PDF)** | TB, GL, aging | All | Use TB + GL as migration validators |

**Migration paths:**
- *QBO → BooksCraft:* OAuth into the QBO API. Pull CompanyInfo, the CoA, lists, then transactions in dependency order (invoices before payments). Rebuild links. Validate that the trial balance matches at each month-end, and that AR/AP agings match by contact.
- *Desktop → BooksCraft:* IIF export for lists; for transactions, report exports (GL/Journal) or third-party QBW readers. Validate by trial balance. Intuit's own Desktop→QBO export tool requires a QBO company less than 60 days old,\[50\] so Desktop users who missed that window are stuck with manual workarounds. That is BooksCraft's opening.
- *BooksCraft → anywhere (anti-lock-in):* one-click full export as a documented JSON bundle plus CSVs, IIF writer, and Beancount/ledger text export. Make "you can leave" a published promise.

---

## 5. User Pain Points BooksCraft Can Solve (ranked)

| # | Pain point | Evidence | BooksCraft response |
|---|---|---|---|
| 1 | **Relentless price increases and tier gating** | Plus $115→$140, Advanced $275→$340 for Aug 2026 renewals.\[1\] G2 summary cites "high subscription costs."\[8\] | Free self-host. Flat-priced hosting. No feature gating by tier; unlimited users and accounts. |
| 2 | **Forced migration / Desktop discontinuation** | US stop-sell since Sept 2024. Desktop 2023 services ended May 31, 2026.\[51\] Intuit community thread "...Forced Migration."\[7\] | Local-first/self-host option; IIF + Desktop report importers; Desktop-like keyboard-driven data entry. |
| 3 | **Bank feed reliability** | G2: "occasional disconnection or miscategorization of bank feeds." Bank of America reconnect saga.\[8\]\[29\] | Multiple aggregators behind one interface; file-import fallback; dedupe by FITID; transparent connection health. |
| 4 | **Support quality / upselling** | Capterra reviewer: "Support sometimes acts more like a sales team." G2: "slow or inconsistent customer support."\[8\]\[52\] | Public docs, community forum/Discord, paid support SLAs on hosted plans. |
| 5 | **Lock-in and data portability** | QBO can't export IIF. Integrations break on forced connector migrations (e.g., Shopify connector reviews).\[46\]\[53\] | Documented open schema, full exports, open API, MCP server. |
| 6 | **Workflow designed by "website designers, not accountants"** | Capterra QBO Advanced reviewer quoting their accountant.\[54\] | Accountant-grade features: hard period locks, reversals, unlimited CoA, TB-driven workflows, multi-client workspace. |
| 7 | **Feature bloat and unwanted AI** | Agents rolled out to all QBO users with no opt-out (secondary source).\[37\] | Modular features turned on per company; AI off by default, draft-only. |
| 8 | **Irreversible settings** (multi-currency, home currency) | Known QBO behavior | Reversible where safe; settings changes audited. |

---

## 6. Competitive Gap Analysis: Open-Source and Low-Cost Alternatives

| Project | License | Stack | Adoption (GitHub stars, approx.) | Coverage vs QBO | Why it hasn't displaced QuickBooks |
|---|---|---|---|---|---|
| **GnuCash** | GPL | C + Scheme, GTK desktop | ~4.4k (in development since 1998)\[55\]\[56\] | Strong double-entry ledger, OFX/QFX/CSV import, basic AR/AP and invoicing, multi-currency | Single-user desktop app with a dated UI. No web/multi-user, no payroll, no automated sales tax, weak invoicing. Accountants don't support it.\[57\]\[58\] |
| **Akaunting** | **BSL** (current README; formerly GPLv3). A Hacker News thread reports free-use limits of about 1,000 invoices / 2 users\[59\]\[60\] | PHP (Laravel), Vue, Tailwind\[61\] | ~9.7k–10.1k | Web UI with invoicing, bills, bank accounts, reconciliation, multi-currency, app store | Not truly open source anymore. Key features (bank feeds, payroll, recurring on cloud) are paid add-ons. Users report a rough setup and migration experience.\[60\]\[62\]\[63\]\[64\] |
| **Bigcapital** | AGPL-3.0 | TypeScript (Node + React), Docker\[65\]\[66\] | ~3.9k stars, 537 forks, 173 open issues | Closest QBO-style app: double-entry, invoices/bills, inventory, financial reports\[66\] | Young, small team, no US bank feeds/payroll/sales-tax engine, limited ecosystem.\[65\] |
| **ERPNext (Frappe)** | GPL-3.0 | Python/JS on Frappe, MariaDB | ~39.8k | Full ERP: GL, AR/AP, inventory, HR/payroll, budgeting\[67\]\[68\] | Too heavy for freelancers and agencies; hard to set up and host. US localization is a separate small app (erpnext_usa, 8 stars).\[69\]\[70\] |
| **Frappe Books** | AGPL-3.0 | Was Electron/Vue/SQLite desktop; now moving to a Frappe server app | ~5.0k (original repo **archived Oct 2, 2026**; new repo ~13 stars)\[71\]\[72\]\[73\] | Simple offline invoicing + ledger | No bank feeds/payroll/US tax; platform transition creates uncertainty.\[63\]\[64\] |
| **Odoo Community** | LGPL-3 (Enterprise proprietary)\[74\] | Python, PostgreSQL | Large (not verified) | Invoicing in Community; full accounting app and reports largely Enterprise\[75\] | Odoo's docs say online bank sync is "not included" in Community.\[76\] The open-core model pushes users to paid Enterprise. |
| **LedgerSMB** | GPLv2 | Perl, PostgreSQL | ~518 | Solid GL/AR/AP, multi-user web\[77\]\[78\] | Dated UX, small community, no bank feeds. |
| **Invoice Ninja** | Elastic License 2.0 (source-available) | PHP (Laravel), React, Flutter | ~9.7k\[79\]\[80\] | Invoicing, quotes, time, 50+ payment gateways, client portal | Not a general ledger; the license forbids offering it as a competing hosted service.\[64\]\[80\]\[81\] |
| **Manager.io** | Proprietary freeware (not open source) | .NET | n/a | Broad features; free desktop edition\[82\] | Closed source; multi-user requires the paid Server/Cloud edition (price reports conflict, roughly $39–$59/mo cloud);\[82\]\[83\] no US payroll/sales-tax engine. |
| **Beancount / Fava** | GPLv2 / MIT | Python, plain text | ~6.0k / ~2.6k\[84\] | Rigorous ledger, queries, git-versioned books | Developers only; no invoicing/AP UI, no bank feeds; accountants won't use it. |
| **Actual Budget** (adjacent reference) | MIT | JS, local-first | — | Personal budgeting with SimpleFIN bank sync\[11\] | Not business accounting, but it proves the open-source + SimpleFIN bank-sync model works.\[85\] |

**The gap:** no project combines (a) a truly open license, (b) a modern multi-user web UI, (c) affordable US bank feeds, (d) accountant-grade controls, and (e) a QuickBooks migrator. Most stall for one of three reasons. License drift (Akaunting, Invoice Ninja) erodes community trust. Open-core gating (Odoo) pushes users to paid editions. Or no bank feeds and no accountant ecosystem means no one recommends them. BooksCraft's wedge is to be **"the open QBO Plus" with a one-click QuickBooks exit**, built to win over bookkeepers, because bookkeepers choose software for their clients.

---

## 7. Technical Considerations

### 7.1 Bank-feed options (US-first)
| Option | Coverage | Cost | Fit for BooksCraft |
|---|---|---|---|
| **SimpleFIN Bridge** | US/Canada (mostly) | $1.50/mo or $15/yr plus tax, up to 25 institutions; ~daily refresh; ≤24 requests/day; 90-day history per query\[86\] | **Best default for self-hosters.** The user owns the key; no compliance burden on the project. Already used by Actual Budget.\[11\]\[85\] |
| **Teller** | US only | Free Developer tier with 100 live connections; paid ~$0.30/enrollment/month for transactions\[10\] | Good for the hosted service at small scale |
| **Plaid** | US/CA/EU | Free sandbox; teams created on or after Apr 15, 2026 get a free Trial with up to 10 live Items; production is paid\[9\]\[87\] | Hosted-tier connector with the broadest coverage. Needs contracts and security review. |
| **GoCardless Bank Account Data (ex-Nordigen)** | EU/UK | **Closed to new signups since July 2025**\[88\] | Do not build on it. Use Enable Banking for EU.\[89\]\[90\] |
| **OFX Direct Connect / file import** | Varies by bank; some banks charge or are dropping support | Free | Always ship file import (OFX/QFX/QBO/CSV) as the fallback |

**Regulatory backdrop:** the CFPB's Section 1033 open-banking rule was finalized in October 2024.\[91\] On October 29, 2025, a federal court blocked enforcement pending the CFPB's reconsideration.\[92\] A new proposed rule reportedly went to White House regulatory review in August 2026.\[93\] Whether banks may charge fees for data access is again under discussion.\[94\] Don't build plans on the assumption that free bank-data access is legally guaranteed. Build a connector interface that can absorb pricing changes.

### 7.2 Accounting correctness checklist
- Integer minor units; currency stored on every amount; explicit rounding account.
- Enforce sum = 0 per journal entry in the database (deferred constraint trigger), not only in application code.
- Append-only postings; reversals for corrections; voids are reversals, not deletes.
- Hard and soft period locks; locked periods are immutable even to admins without an audited override.
- A hash-chained audit_event table records actor (user/API/agent), before/after state and timestamp.
- Deterministic posting functions with golden-file tests: given a document, the expected postings.
- Property-based tests: random document sequences must always produce a trial balance of 0, and the Balance Sheet must satisfy A = L + E.
- Idempotent imports keyed by external IDs and bank FITIDs.
- Optimistic concurrency (a version column, equivalent to QBO's SyncToken).

### 7.3 US compliance complexity
- **Sales tax:** MVP supports manual tax codes and combined rates, plus a liability report by agency. Automated, address-based rates go behind a `TaxRateProvider` interface. Options include free state rate tables or commercial APIs. Nexus thresholds change every year (2026 examples: Illinois, Kentucky).\[33\]\[95\] Never hard-code them.
- **1099:** flag vendors as 1099-eligible, map expense accounts to boxes, apply the $2,000 threshold for 2026 (indexed from 2027) as data, not code, and exclude card/PayPal payments (those are 1099-K).\[35\]\[96\] E-filing goes through the IRS IRIS system or a partner; offer it later.
- **Payroll:** out of scope. Import journals from payroll providers.
- **International:** keep tax, CoA templates, date and number formats, and e-invoicing behind locale packs. VAT (UK/EU) is a natural community-contributed module.

### 7.4 Deployment model
- **Self-hosted:** Docker Compose (app + Postgres) and a single-binary/SQLite "solo mode" for freelancers. Encrypted backups by default.
- **Hosted (sustainability engine):** a managed BooksCraft Cloud with flat pricing, bundled bank feeds, backups, and support. This is how comparable projects fund themselves: Odoo, Frappe and Invoice Ninja earn from hosting, and Actual Budget relies on donations and partner hosting.\[11\]
- **Recommended stack:** a TypeScript monorepo (Node API, React UI, shared ledger core package), PostgreSQL, OpenAPI-first REST, and an MCP server plus CLI for agents. Package desktop/local-first builds with Tauri later. (ArtCraft chose pure Rust for performance in creative apps. For CRUD-plus-ledger software, TypeScript maximizes contributors and Claude Code productivity.)

### 7.5 Licensing and sustainability
- **AGPL-3.0 for the application.** It stops a competitor from hosting a closed fork as a service, and it is the norm for open business apps (Bigcapital, Frappe Books).\[65\] **MIT/Apache-2.0 for libraries** (IIF/OFX parsers, QBO mapper, ledger core) to maximize adoption and goodwill.
- **Avoid BSL/Elastic-style licenses.** Akaunting's switch from GPLv3 to BSL drew public backlash ("is not open source").\[60\] For a community-driven project, a trustworthy license is a feature.
- **Use a CLA or DCO.** A DCO plus AGPL keeps the license permanently open, which signals commitment. A CLA leaves room for later dual-licensing. Recommendation: DCO only, published with a "no relicensing" pledge.
- **Revenue:** hosted cloud; paid bank-feed relay; accountant/firm plans (multi-client workspace, white-label); paid migration service; support contracts; sponsorships. Never gate core accounting features.

---

## 8. ArtCraft (getartcraft.com) as a Positioning Reference

- **What it is:** ArtCraft calls itself "the open-source studio for controllable AI image and video," built by the Storyteller.ai team. It ships as a desktop app (Windows, macOS; Linux from source) and a web app. The desktop app is MIT-licensed and written in Rust.\[97\]\[98\]\[99\] In October 2026 it added **"Crafting Apps,"** seven native, open-source reimplementations of professional tools: PhotoCraft, VectorCraft, FilmCraft, LightCraft, PdfCraft, EffectCraft and DesignCraft. They are pitched as Adobe alternatives.\[99\]\[100\]
- **Stated principles** (from getartcraft.com/apps): "Every line is on GitHub under permissive licenses." "Native, not wrapped... No Electron, no web views." "Familiar from day one: layouts, tools and shortcuts that working professionals already know." "Your files, your machine." "Agent-ready: drive every app from a CLI, a JSON control channel or an MCP server." The apps also compile to WebAssembly for in-browser use.\[99\]
- **Distribution and community:** GitHub releases, a download page, a browser workspace, and a Discord where users "tell us what to rebuild next" and test early builds.\[99\]\[101\] Monetization appears to center on the hosted AI generation workspace (there is a pricing page); the apps are free.\[98\]\[99\]
- **Caveat:** Phoronix (Oct 7, 2026) reports that the Crafting Apps were produced "predominantly" with Claude Code and AI agents as "clean-room reimplementations," and flags "potentially pressing legal challenges."\[102\] For BooksCraft, the lesson is to keep clean-room discipline. Don't copy Intuit's UI assets, text or trademarks. Use "QuickBooks" only in factual interoperability statements. Build compatibility from Intuit's public API documentation and file formats.
- **Positioning to borrow:** "Familiar from day one" (QBO-like navigation and terminology mapping), "your books, your machine" (self-host/local-first), "agent-ready" (MCP), a community-voted roadmap, and rapid public releases.

---

## 9. Recommended Phased Roadmap

**Phase 0 — Foundations (weeks 0–4)**
- Repo, AGPL/MIT split, DCO, contribution guide, Discord.
- Ledger core package: accounts, journal entries, postings, invariants, property tests, period locks, audit chain.
- OpenAPI skeleton; Postgres schema per §4.2; Docker Compose.

**Phase 1 — MVP: "Freelancer and agency books" (months 1–4)**
- CoA templates (US service business, agency, freelancer) using a QBO-compatible type taxonomy.
- Customers, vendors, service items; estimates, invoices (PDF + email), payments, credit memos, sales receipts, deposits/Undeposited Funds.
- Bills, bill payments, expenses/checks.
- Bank file import (OFX/QFX/QBO/CSV) with the review/match/add/exclude workflow, bank rules, and reconciliation.
- Reports: P&L, Balance Sheet, Trial Balance, GL, AR/AP aging (accrual and cash).
- Multi-user with basic roles; audit log viewer.
- **QBO migrator** (API pull) and CSV import, validated by trial balance and agings.
- SimpleFIN connector (late MVP). PWA with receipt upload.
- Success metric: a real agency migrates from QBO and closes a month with a TB that matches QuickBooks to the cent.

**Phase 2 — v1: "QBO Plus parity without tiers" (months 4–9)**
- Dimensions (class/location), projects/job costing, billable time and expenses, budgets, cash-flow statement, report builder and dashboards.
- Recurring transactions, custom fields, batch entry.
- Teller/Plaid connectors in hosted mode; Stripe/PayPal payment links that auto-record payments and fees.
- Sales tax: manual codes, combined rates, agency liability, filing records. 1099 tracking + PDF forms.
- Multi-currency. IIF import/export library. Accountant workspace (multi-client, review tools, closing checklist).
- MCP server + CLI (draft-only actions); AI-suggested categorization using rules plus a user-supplied model of their choice.
- Hosted BooksCraft Cloud beta.

**Phase 3 — Later (9–18 months)**
- FIFO inventory, purchase orders, COGS; e-commerce importers (Shopify/Stripe payouts).
- Automated address-based sales-tax provider plugin; 1099 e-file partner.
- Approval workflows, multi-entity/consolidation.
- Payroll *integrations* (journal sync), not payroll processing.
- Native mobile apps; locale packs (UK/EU VAT, Canada GST/HST) contributed by the community.

---

## Caveats
- **Pricing history in 2026 is contested.** The August 1, 2026 list prices ($38/$85/$140/$340) are confirmed on Intuit's subscription page.\[4\] Earlier 2026 prices and the existence and size of a May 1 increase vary across secondary sources, and some of those sources are competitors' blogs (BizBooks Pro, Certum).\[12\]\[103\]
- **Advanced's bundled payroll** (Workforce Elite) is reported by secondary sources but not clearly confirmed by Intuit's Advanced page, which still lists payroll as optional. Desktop October 2026 renewal prices come from Business Solutions Inc. (bsi-dc.com), which cites Intuit's notice to ProAdvisors, rather than from Intuit's public pricing page.
- **Payroll per-employee fees** differ across aggregators. FitSmallBusiness's figures ($50+$6.50 / $88+$10 / $134+$12) are the most consistent.\[14\]\[104\]
- **Open-source stars and licenses are point-in-time snapshots** from GitHub and directories. Akaunting's free-use limits come from a Hacker News discussion, not the license text.\[60\] Odoo Community's accounting limits beyond bank sync come from partner blogs.
- **Manager.io Cloud/Server pricing** was not verified on the vendor's buy page.
- **The QBO AccountType list and several workflow details** (bank-feed tabs, reconciliation steps, multi-currency irreversibility) reflect Intuit's documented, long-standing behavior rather than a 2026-specific source. Verify against current Intuit developer docs when building the compatibility layer.
- **Tax rules change often.** Nexus thresholds and 1099 thresholds must be data-driven and reviewed every year. Nothing here is tax or legal advice.

## Sources

1. [QuickBooks Price Increase 2026: Costs & Options](https://www.mosofin.com/blog/quickbooks-price-increase-2026)
2. [2026 QuickBooks Price Increases](https://www.swktech.com/2026-quickbooks-price-increases-what-they-mean-for-your-renewal/)
3. [QuickBooks Price Increase 2026: Desktop Renewals \$1,351 from Oct 1, Online Plus \$140](https://www.bizbooks.pro/blog/quickbooks-price-increase-2026.html)
4. [QuickBooks Online Subscription Levels \[2025\]](https://quickbooks.intuit.com/subscription/)
5. [What's new in QuickBooks Online Advanced: August 2026](https://quickbooks.intuit.com/r/product-update/whats-new-quickbooks-advanced-august-2026/)
6. [QuickBooks Online Plans Compared 2026: All 5 Tiers Reviewed](https://www.certumsolutions.com/library/quickbooks-online-plans-compared)
7. [Longtime Customer Deeply Disappointed by QuickBooks Pricing and Forced Migration](https://quickbooks.intuit.com/community/other-questions-9/longtime-customer-deeply-disappointed-by-quickbooks-pricing-and-forced-migration-90743)
8. [2026 Best Software Awards are here!See the list](https://www.g2.com/categories/accounting/free)
9. [Can I use Plaid for free?](https://support.plaid.com/hc/en-us/articles/16194695660311-Can-I-use-Plaid-for-free)
10. [Teller - The API for your bank account](https://teller.io/)
11. [Free Budgeting Apps (2026): What Is Free and What It Costs](https://www.simplefinances.co/guides/free-budgeting-apps/)
12. [QuickBooks Price Increase August 2026: What Every Plan Costs Now](https://www.certumsolutions.com/library/quickbooks-price-increase-august-2026)
13. [QuickBooks Online Advanced - Designed to Grow Business](https://quickbooks.intuit.com/online/advanced/)
14. [QuickBooks Workforce Payroll vs Premium vs Elite: 2026 Comparison](https://fitsmallbusiness.com/quickbooks-payroll-core-vs-premium-vs-elite/)
15. [How Much Does QuickBooks Cost in 2026? The Real DTC Number](https://eightx.co/blog/compare/how-much-does-quickbooks-cost)
16. [QuickBooks Desktop to stop selling to new U.S. subscribers - article](https://quickbooks.intuit.com/r/whats-new/quickbooks-desktop-stop-sell/)
17. [QuickBooks Desktop to stop selling to new U.S. subscribers - article](https://www.firmofthefuture.com/product-update/faq-desktop-stopsell/)
18. [QuickBooks Desktop Discontinued 2026: Dates, Options & Migration Guide](https://www.sdocpa.com/quickbooks-desktop-discontinued/)
19. [QuickBooks Desktop Discontinued: Your Options Explained](https://www.certumsolutions.com/library/quickbooks-desktop-2023-service-ending-may-2026)
20. [QuickBooks Desktop discontinued: Next steps for Desktop users (2026) — Method](https://www.method.me/blog/quickbooks-desktop-discontinued/)
21. [QuickBooks](https://en.wikipedia.org/wiki/QuickBooks)
22. [How to Use Undeposited Funds in QuickBooks Online](https://www.nerdwallet.com/business/software/learn/undeposited-funds-in-quickbooks-online)
23. [QuickBooks Desktop Enterprise vs QuickBooks Online vs Intuit Enterprise Suite: A Terminology Translation Guide](https://www.fourlane.com/quickbooks-ies-terminology-guide)
24. [Using a Closing Password](https://www.oreilly.com/library/view/quickbooks-2013-for/9781118461983/a8_24_9781118461983-ch17.html)
25. [Record and make bank deposits in QuickBooks Desktop - Intuit](https://quickbooks.intuit.com/learn-support/en-us/help-article/bank-deposits/record-make-bank-deposits-quickbooks-desktop/L2R3J0uic_US_en_US)
26. [1 tv5fh5od](https://video.byui.edu/media/t/1_tv5fh5od)
27. [Exploring the Quickbooks Online Accounting API](https://www.apideck.com/blog/exploring-the-quickbooks-online-accounting-api)
28. [How to integrate the QuickBooks Invoice API in 2026](https://www.apideck.com/blog/quickbooks-invoice-api-integration)
29. [Bank of America Feed Not Connecting After the Migration? Here's How to Reconnect in QuickBooks Online](https://quickbooks.intuit.com/community/getting-the-most-out-of-quickbooks-11/bank-of-america-feed-not-connecting-after-the-migration-here-s-how-to-reconnect-in-quickbooks-online-375111)
30. [How to Import Bank Transactions Into QuickBooks Online](https://www.nerdwallet.com/business/software/learn/how-to-import-bank-transactions-into-quickbooks-online)
31. [QuickBooks® with Intuit Intelligence - Tax Pro Center](https://accountants.intuit.com/taxprocenter/practice-management/workflow-tools/you-ask-and-quickbooks-with-intuit-intelligence-answers/)
32. [Economic Nexus: State-by-State Handbook for 2026 - Numeral](https://www.numeral.com/blog/economic-nexus)
33. [Economic Nexus by State 2026: Thresholds Guide - Sales Tax by State](https://salestaxstate.com/economic-nexus-by-state-2026-thresholds-guide/)
34. [One Big Beautiful Bill Act changes 1099 thresholds — Avalara](https://www.avalara.com/blog/en/north-america/2025/07/one-big-beautiful-bill-act-1099-reporting-threshold.html)
35. [1099 Reporting Threshold 2026: New IRS Rules ExplainedMeta description:](https://madrasaccountancy.com/blog-posts/2026-1099-reporting-threshold-new-irs-rules-for-1099-nec-1099-misc-and-1099-k)
36. [Intuit Introduces Ground-Breaking Virtual Team of AI Agents to Fuel Growth for Businesses :: Intuit Inc. (INTU)](https://investors.intuit.com/news-events/press-releases/detail/1258/intuit-introduces-ground-breaking-virtual-team-of-ai-agents-to-fuel-growth-for-businesses)
37. [QuickBooks AI: The Agents, the Tiers, and What They Miss (2026)](https://www.usecarly.com/blog/quickbooks-ai/)
38. [QuickBooks AI Agent: Intuit's Agents and What They Do](https://gravity.fast/blog/quickbooks-ai-agent/)
39. [QuickBooks Online Changes 2026: New AI Features & Pricing](https://www.squire.com/resources/blog/quickbooks-online-changes-2026/)
40. [Honest Intuit AI Agents Review 2026: Worth It or Not?](https://aiforesight360.com/intuit-ai-agents-review/)
41. [Quickstart — QuickBooks V3 PHP SDK 4.0.5 documentation](https://intuit.github.io/QuickBooks-V3-PHP-SDK/quickstart.html)
42. [Manage linked transactions](https://developer.intuit.com/app/developer/qbo/docs/workflows/manage-linked-transactions)
43. [How to integrate the QuickBooks Invoice API in 2026 - DEV Community](https://dev.to/apideck/how-to-integrate-the-quickbooks-invoice-api-in-2026-1h8l)
44. [Basic schema and data formats for the QuickBooks Online Accounting REST API · QuickBooks Online](https://developer.intuit.com/app/developer/qbo/docs/learn/rest-api-features)
45. [APIs](https://blogs.intuit.com/wp-content/uploads/2015/10/Invoice)
46. [QuickBooks IIF Files - AAATEX](https://aaatex.com/articles/quickbooks_iif_transactions_13.htm)
47. [What is IIF Format? Intuit Interchange Format Explained · FinanceConvert](https://financeconvert.com/what-is-iif-format)
48. [How to import transactions into Quickbooks](https://www.propersoft.net/howto/import-into-quickbooks/)
49. [How do I import iif files into QuickBooks Online?](https://quickbooks.intuit.com/learn-support/en-us/other-questions/how-do-i-import-iif-files-into-quickbooks-online/00/1157211)
50. [How to Import IIF Files into QuickBooks Desktop & Online?](https://www.bizbooksadvice.com/import-iif-files-into-quickbooks.html)
51. [QuickBooks Desktop Discontinued: What Next](https://www.techvaria.com/blog/quickbooks-desktop-discontinued-what-next.html)
52. [\# Page 2 | QuickBooks Online Reviews 2026. Verified Reviews, Pros & Cons | Capterra](https://www.capterra.com/p/190778/QuickBooks-Online/reviews?page=2)
53. [Reviews (3,038)](https://apps.shopify.com/qbconnector/reviews)
54. [\# Page 11 | QuickBooks Online Advanced Reviews 2026. Verified Reviews, Pros & Cons | Capterra](https://www.capterra.com/p/189398/QuickBooks-Online/reviews/?page=11)
55. [beancount vs GnuCash - compare differences and reviews?](https://www.libhunt.com/compare-beancount-vs-gnucash)
56. [GitHub - Gnucash/gnucash: GnuCash Double-Entry Accounting Program. · GitHub](https://github.com/gnucash/gnucash)
57. [An open-source alternative to QuickBooks](https://news.ycombinator.com/item?id=36118990)
58. [Best Open-Source QuickBooks Alternatives 2026 — OSSAlt Guides](https://ossalt.com/guides/best-open-source-alternatives-to-quickbooks-2026)
59. [GitHub - akaunting/akaunting: Online Accounting Software · GitHub](https://github.com/akaunting/akaunting)
60. [Akaunting is free, open-source online accounting software for small businesses](https://news.ycombinator.com/item?id=40130542)
61. [github.com-akaunting-akaunting\_-\_2022-06-03\_08-28-20 : akaunting : Free Download, Borrow, and Streaming : Internet Archive](https://archive.org/details/github.com-akaunting-akaunting_-_2022-06-03_08-28-20)
62. [FreshBooks Alternatives](https://alternativeto.net/software/freshbooks/?p=2)
63. [GitHub - braedonsaunders/Awesome-Bookkeeping: Top Bookkeeping (Opensource) 🌟 Star if you like it! 🌟](https://github.com/braedonsaunders/Awesome-Bookkeeping)
64. [The Best Open Source QuickBooks Alternatives for Freelancers](https://nimblelancer.com/open-source-quickbooks-alternatives/)
65. [GitHub - bigcapitalhq/bigcapital: 💵 Independent financial accounting with intelligent reporting, alternative to Quickbooks, Xero, Wave.](https://github.com/bigcapitalhq/bigcapital)
66. [Bigcapital - accounting and inventory software - LinuxLinks](https://www.linuxlinks.com/bigcapital-accounting-inventory-software/)
67. [ERPNext: Open-Source ERP System for Accounting & ...](https://dev.co/erp/open-source/erpnext)
68. [Releases · frappe/erpnext](https://github.com/frappe/erpnext/releases)
69. [GitHub - frappe/erpnext\_usa · GitHub](https://github.com/frappe/erpnext_usa)
70. [ERPNext](https://en.wikipedia.org/wiki/ERPNext)
71. [GitHub - frappe/frappe-books: Frappe Books for Frappe Framework (develop) · GitHub](https://github.com/frappe/frappe-books)
72. [GitHub - frappe/books: Free Accounting Software · GitHub](https://github.com/frappe/books)
73. [Open Source Accounting Software](https://frappe.io/books)
74. [ERPNext Review 2026: Free Open-Source ERP](https://www.erpresearch.com/en-us/erpnext)
75. [Odoo Community Vs Enterprise: Full Comparison Guide](https://sdlccorp.com/post/odoo-community-vs-enterprise/)
76. [Bank synchronization — Odoo 17.0 documentation](https://www.odoo.com/documentation/17.0/applications/finance/accounting/bank/bank_synchronization.html)
77. [GitHub - ledgersmb/LedgerSMB at 1.7 · GitHub](https://github.com/ledgersmb/LedgerSMB/tree/1.7)
78. [GitHub - ledgersmb/LedgerSMB at 1.9](https://github.com/ledgersmb/LedgerSMB/tree/1.9)
79. [GitHub - Evolution-Marketing/invoiceninja: Invoices, Expenses and Tasks built with Laravel and Flutter · GitHub](https://github.com/Evolution-Marketing/invoiceninja)
80. [Invoice Ninja](https://www.invoiceninja.org/)
81. [Build Your Own FreshBooks Alternative](https://www.rapidevelopers.com/clone/freshbooks)
82. [Manager Software Pricing, Alternatives & More 2026](https://www.capterra.com/p/122579/Manager/)
83. [Download Manager IO 26.8.4.3664 - MajorGeeks](https://www.majorgeeks.com/files/details/manager.html)
84. [beancount · GitHub](https://github.com/beancount/)
85. [Sync ActualBudget via SimpleFIN](https://github.com/duplaja/actual-simplefin-sync)
86. [SimpleFIN Bridge vs BankBridge: Pricing, Review, MCP](https://bankbridge.money/guides/bankbridge-vs-simplefin)
87. [Free & Indie Open Banking APIs (2026): What Is Actually Free?](https://www.openbankingtracker.com/guides/free-open-banking-apis)
88. [GoCardless Setup](https://actualbudget.org/docs/advanced/bank-sync/gocardless/)
89. [Best Open Banking API Providers for Developers in 2026 |...](https://www.openbankingtracker.com/blog/best-open-banking-api-providers-developers-2026)
90. [bank sync for Actual Budget in Europe & New Zealand](https://synci.io/destinations/actual-budget)
91. [CFPB Issues Final Personal Financial Data Rights Rule](https://uk.practicallaw.thomsonreuters.com/w-044-7825?transitionType=Default&contextData=%28sc.Default%29)
92. [CFPB Enjoined from Enforcing Personal Financial Data Rights Rule 1033: Moore & Van Allen](https://www.mvalaw.com/data-points/cfpb-enjoined-from-enforcing-personal-financial-data-rights-rule-1033)
93. [Where Section 1033 Actually Stands: A Plain-Language Guide for Financial Institutions](https://bloomcredit.io/blog/where-section-1033-actually-stands-a-plain-language-guide-for-financial-institutions/)
94. [Section 1033 Status & Timeline (2026): Is the Open Banking Rule in Effect?](https://openbankingtracker.com/guides/section-1033-status)
95. [Economic Nexus by State: 2026 Thresholds Table](https://trykintsugi.com/sales-tax-guides/usa/economic-nexus)
96. [1099-NEC Instructions 2026: Complete Guide to New \$2000 Threshold](https://www.1099online.com/blog/1099-nec-instructions-guide/)
97. [ArtCraft download](https://sourceforge.net/projects/artcraft.mirror/)
98. [ArtCraft — Text to Image - OOXL](https://ooxl.com/en/app/artcraft)
99. [Crafting Apps: open-source creative tools](https://getartcraft.com/apps)
100. [ArtCraft Crafting Apps is a collection of free Adobe alternative apps, aiming to be an open-source alternative to Photoshop, Illustrator, Premiere, Lightroom, Acrobat, After Effects, and InDesign. - GIGAZINE](https://gigazine.net/gsc_news/en/20261005-artcraft-crafting-apps/)
101. [ArtCraft Open Source: App Ecosystem & Setup Guide - ArtCraft Wiki](https://www.artcraft.wiki/platform/ArtCraft-open-source)
102. [AI Makes "Open-Source, Clean Room" Implementations Of Adobe Photoshop & Premier In Rust - Phoronix](https://www.phoronix.com/news/Photocraft-Filmcraft-AI)
103. [QuickBooks Online Pricing 2026: Plans Explained](https://buyersprint.com/2026/05/07/quickbooks-online-pricing-2026/)
104. [How Much Does QuickBooks Payroll Actually Cost?](https://www.finlens.app/blogs/quickbooks-payroll-cost)
