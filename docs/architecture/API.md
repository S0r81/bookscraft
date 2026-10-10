# API surfaces: HTTP, MCP and CLI

Status: accepted (2026-10-10). Owner: `api-engineer`. Wire types live in `crates/api-types` (W0-02); handlers in `crates/api` (W1-05 framework, one route module per area); MCP tools in `crates/mcp` (W5-02); CLI in `crates/cli` (W4-02). The OpenAPI document is generated from the code into `docs/architecture/openapi.json` by `cargo xtask docs`. This file is the contract the code must match.

## 1. Who uses which surface

| Surface | Clients | Transport | Authentication |
|---|---|---|---|
| HTTP API `/api/v1` | The BooksCraft UI (desktop and browser), integrations, `bookscraft --server` | Desktop: custom protocol in-process. Server: HTTPS | Desktop principal; session cookie; bearer token |
| MCP | Agents (any MCP client, any model) | stdio (local) or streamable HTTP at `/mcp` (server) | Agent token (`actor_type = agent`) |
| CLI | Humans and scripts | In-process on a company file, or HTTP to a server | Desktop principal (local) or bearer token (remote) |

All three call the same `domain::ports` services. No surface can do something the permission matrix (section 6) forbids for its principal.

## 2. HTTP conventions

| Topic | Convention |
|---|---|
| Base path | `/api/v1`. Company resources are under `/api/v1/companies/{company_id}/...`. |
| Media type | `application/json; charset=utf-8`. Problem responses use `application/problem+json`. Reports also offer `text/csv`, chosen by `Accept`. Uploads use `multipart/form-data`. |
| Field names | `snake_case`. Enum values are `snake_case` strings. Unknown request fields are rejected (`validation.unknown_field`). |
| Identifiers | UUIDv7 strings, lowercase. |
| Dates | `"YYYY-MM-DD"` (civil, no time zone). Timestamps are RFC 3339 UTC with `Z`, for example `"2026-03-02T15:04:05.123Z"`. |
| Money | Object `{"amount": "<decimal>", "currency": "<ISO 4217>"}`. `amount` is a string with exactly the currency's minor digits: `"5097.70"` for USD, `"500"` for JPY, and `"-15.00"` where negative values are allowed. JSON numbers, thousands separators, exponents and missing or extra digits are rejected (`validation.money_format`). A document's money values must use the document currency. |
| Decimals (qty, unit price, rates, percents) | Strings, for example `"1.5"`, `"6.25"`. Up to 28 significant digits; no exponent. |
| Absent vs null | Optional fields may be omitted or `null` with the same meaning. A `PATCH` sets only the fields present. |
| Pagination | Cursor-based: `?limit=50&cursor=<opaque>`; `limit` defaults to 50, maximum 500. Response `{"items": [...], "next_cursor": "..." \| null}`. Order is stable: the endpoint's sort key, then `id`. |
| Filtering and sorting | Query parameters named after fields (`status=posted&status=draft`, `from=2026-03-01&to=2026-03-31`, `q=juniper`); `sort=date` or `sort=-date`. Each endpoint lists its filters in OpenAPI. |
| Idempotency | Every `POST` that creates or changes state requires `Idempotency-Key: <8–200 chars>`, unique per principal. Same key and same body: the stored status and body are replayed with header `Idempotent-Replayed: true`. Same key, different body: 422 `idempotency.key_reused`. Same key still running: 409 `idempotency.in_progress`. Keys expire after 24 hours. Missing key: 400 `idempotency.key_required`. |
| Optimistic concurrency | Every mutable resource has an integer `version` and is returned with `ETag: W/"<version>"`. `PUT`, `PATCH`, `DELETE` and state-changing `POST .../{id}/<action>` require `If-Match: W/"<version>"`. Stale: 412 `concurrency.version_mismatch` (QBO's SyncToken error 5010 is the analogue). Missing: 428 `concurrency.if_match_required`. |
| Creation | 201 with `Location` and the full resource. |
| Long work | Imports, exports, backups, verify, bulk sends, bank syncs: 202 with `Location: /api/v1/jobs/{id}` and a `Job` body. Clients poll the job (no server push in MVP; ARCHITECTURE.md §5). |
| Request id | Every response carries `X-Request-Id` (a UUIDv7; echoed if the client sent one). The id appears in problem `instance`, logs and audit events. |
| CSRF (server mode, cookie auth) | `SameSite=Strict` cookies; mutating requests must also carry `X-BooksCraft-Client: ui`. Bearer-token requests need neither. |
| Limits | JSON body 2 MB; attachment 25 MB; statement file 10 MB. Too large: 413 `api.payload_too_large`. Login rate limit: 429 `auth.rate_limited`. |
| Versioning | Additive changes (new optional fields, new endpoints, new enum values documented as such) stay in `v1`. Breaking changes need `/api/v2`. A field is deprecated for at least one minor release before removal. |

## 3. Status codes

| Code | When |
|---|---|
| 200, 201, 202, 204 | success; created; accepted (job); no content |
| 400 | malformed request: JSON syntax, missing idempotency key, bad query parameter |
| 401 | not authenticated (`auth.required`, `auth.invalid_token`, `auth.session_expired`) |
| 403 | authenticated but not permitted (`auth.forbidden`, `auth.agent_forbidden`, `auth.scope_missing`) |
| 404 | not found, or not visible to the principal (`api.not_found`) |
| 409 | state conflict (`idempotency.in_progress`, `store.company_locked`, `document.has_active_settlements`, `reconciliation.in_progress_exists`) |
| 412, 428 | concurrency (section 2) |
| 413, 415 | payload too large; unsupported media type |
| 422 | validation and business rules (`validation.*` and every domain rule code such as `ledger.unbalanced`, `period.soft_locked`, `sales.application_exceeds_open`) |
| 429 | rate limited |
| 500 | unexpected (`api.internal`, with the request id; details only in logs) |
| 501 | the capability is not built yet (`api.not_implemented`, from W0-01 stubs) |

## 4. Errors

Every error is RFC 9457 problem details:

```json
{
  "type": "urn:bookscraft:error:sales.application_exceeds_open",
  "title": "Application exceeds the open amount",
  "status": 422,
  "detail": "INV-1002 has 2,597.70 open; the payment applies 3,000.00.",
  "code": "sales.application_exceeds_open",
  "instance": "urn:bookscraft:request:0192f0c4-7d2a-7c51-9a0e-3e1b6c1f2a11",
  "errors": [
    { "field": "applications[0].amount", "code": "sales.application_exceeds_open", "message": "Exceeds the open amount 2,597.70." }
  ]
}
```

`code` is stable and machine-readable. `title` and `detail` are for people and may change. Codes are `<namespace>.<name>`:

| Namespace | Owner crate | Examples |
|---|---|---|
| `validation` | api | `validation.required`, `validation.unknown_field`, `validation.money_format`, `validation.date_format`, `validation.out_of_range` |
| `api` | api | `api.not_found`, `api.not_implemented`, `api.payload_too_large`, `api.internal` |
| `idempotency`, `concurrency` | api | section 2 |
| `auth` | identity (codes), api (mapping) | `auth.required`, `auth.invalid_credentials`, `auth.forbidden`, `auth.agent_forbidden`, `auth.scope_missing`, `auth.rate_limited` |
| `money` | money | `money.overflow`, `money.currency_mismatch` |
| `ledger`, `document`, `period`, `audit`, `settlement`, `store` | store (trigger codes from schema.sql) and ledger | DATA_MODEL.md §5 |
| `books` | books | `books.account_in_use`, `books.system_account_protected`, `books.duplicate_name`, `books.lock_reason_required`, `books.hard_unlock_requires_owner` |
| `sales`, `purchases` | sales, purchases | `sales.application_exceeds_open`, `sales.application_mismatch`, `sales.applied_amount_exceeds_total`, `sales.payment_before_charge` (warning) |
| `banking`, `reconciliation` | banking (plus store trigger codes) | `banking.already_deposited`, `banking.match_amount_mismatch`, `reconciliation.difference_not_zero`, `reconciliation.reconciled_line_changed` |
| `reports` | reports | `reports.invalid_period` |
| `import`, `export` | migrate | `import.duplicate`, `import.unbalanced_source`, `import.multi_currency_unsupported`, `import.qbo_auth_failed`, `import.parity_failed` |
| `render` | render | `render.template_error`, `render.smtp_failed` |
| `mcp` | mcp | `mcp.tool_not_permitted` |

Warnings (non-blocking) come back in a `warnings` array on the success body, using the same `{field, code, message}` shape. `cargo xtask docs` regenerates the full code table from the constants in the Weave.

## 5. HTTP endpoints

Permission names refer to section 6. "Agent" shows whether an `agent` principal may call the endpoint. Every company-scoped path is under `/api/v1/companies/{cid}`, written below as `/…`.

### 5.1 System, session and identity

| Method | Path | Operation | Request → Response | Permission | Agent |
|---|---|---|---|---|---|
| GET | `/api/v1/health` | health | → `Health {status, version, mode, capabilities[]}` | none | yes |
| GET | `/api/v1/session` | session.get | → `SessionInfo {user, is_admin, memberships[{company, role}], mode}` | authenticated | yes |
| POST | `/api/v1/session` | session.login | `LoginRequest {username, password}` → 204 + cookie | none (server mode) | no |
| DELETE | `/api/v1/session` | session.logout | → 204 | session | no |
| GET | `/api/v1/users` | users.list | → `Paged<User>` | `users.manage` | no |
| POST | `/api/v1/users` | users.create | `CreateUser {username, display_name, email?, password, is_admin}` → `User` | `users.manage` | no |
| GET / PATCH | `/api/v1/users/{uid}` | users.get / users.update | `UpdateUser {display_name?, email?, is_admin?, is_disabled?}` → `User` | `users.manage` or self (own name and email only) | no |
| POST | `/api/v1/users/{uid}/password` | users.set_password | `SetPassword {current_password?, new_password}` → 204 | self (current required) or `users.manage` | no |
| GET | `/api/v1/tokens` | tokens.list | → `Paged<TokenSummary>` (own tokens; all with `users.manage`) | authenticated human | no |
| POST | `/api/v1/tokens` | tokens.create | `CreateToken {name, actor_type: api\|agent, scopes[], company_id?, expires_at?}` → `TokenCreated {token, summary}` (token shown once) | session (a human) | no |
| DELETE | `/api/v1/tokens/{tid}` | tokens.revoke | → 204 | owner of the token or `users.manage` | no |
| GET | `/api/v1/account-templates` | templates.list | → `[CoaTemplateSummary]` | authenticated | yes |
| GET | `/api/v1/jobs/{jid}` | jobs.get | → `Job {id, kind, status, progress?, result?, error?}` | job creator, or `company.read` for the job's company | yes (own jobs) |

### 5.2 Companies

| Method | Path | Operation | Request → Response | Permission | Agent |
|---|---|---|---|---|---|
| GET | `/api/v1/companies` | companies.list | → `Paged<CompanySummary>` (companies where the principal is a member) | authenticated | yes |
| POST | `/api/v1/companies` | companies.create | `CreateCompany {name, legal_name?, base_currency, fiscal_year_start_month, time_zone, template}` → `Company` | `company.create` | no |
| GET / PATCH | `/api/v1/companies/{cid}` | companies.get / companies.update | `UpdateCompany {name?, legal_name?, address?, settings?}` → `Company` | `company.read` / `settings.manage` | read only |
| GET | `/…/members` | members.list | → `Paged<Membership>` | `members.manage` | no |
| PUT / DELETE | `/…/members/{uid}` | members.set / members.remove | `{role}` → `Membership` | `members.manage` | no |
| GET / PUT | `/…/period-locks` | locks.get / locks.set | `SetPeriodLocks {soft_locked_through?, hard_locked_through?, reason}` → `PeriodLocks` | `company.read` / `period.lock` (+ `period.unlock_hard` to move the hard date earlier) | read only |
| POST | `/…/backups` | backups.create | → 202 `Job` | `company.backup` | no |
| GET | `/…/backups` | backups.list | → `[Backup]` | `company.backup` | no |
| POST | `/…/verify` | company.verify | `{mode: quick\|full}` → 202 `Job` (result `VerifyReport`) | `audit.read` | no |
| GET / PUT | `/…/settings/number-sequences` | sequences.list / sequences.set | `{doc_type, prefix, next_value, padding}` | `company.read` / `settings.manage` | read only |
| GET / PUT | `/…/settings/email` | email.get / email.set | `EmailSettings {host, port, username, password?, from, tls}` (password write-only) | `settings.manage` | no |
| POST | `/…/settings/email/test` | email.test | `{to}` → 202 `Job` | `settings.manage` | no |

### 5.3 Lists (books)

The same pattern applies to every list resource:

| Method | Path | Operation | Notes |
|---|---|---|---|
| GET | `/…/{resource}` | list | filters `q`, `archived=true\|false\|any` (default false), plus resource filters below |
| POST | `/…/{resource}` | create | 201 |
| GET | `/…/{resource}/{id}` | get | ETag |
| PATCH | `/…/{resource}/{id}` | update | If-Match |
| POST | `/…/{resource}/{id}/archive`, `/unarchive` | archive / unarchive | If-Match. Hard delete is not offered once referenced (`books.*_in_use`). |

| Resource | Extra filters | Body (create) | Permission (read / write) | Agent |
|---|---|---|---|---|
| `accounts` | `class`, `subtype`, `system_role` | `{code?, name, class, subtype, detail?, parent_id?, description?}` | `books.read` / `books.write` | read only |
| `contacts` | `role=customer\|vendor\|employee` | `{display_name, company_name?, given_name?, family_name?, roles{customer,vendor,employee}, parent_id?, email?, phone?, website?, billing_address?, shipping_address?, tax_id?, is_1099?, is_taxable?, default_tax_code_id?, default_terms_id?, notes?, custom_fields?}` | `books.read` / `books.write` | read only |
| `items` | `kind` | `{name, sku?, kind, parent_id?, sales_description?, sales_price?, income_account_id?, purchase_description?, purchase_cost?, expense_account_id?, is_taxable?, components?[{item_id, qty}], custom_fields?}` | `books.read` / `books.write` | read only |
| `terms` | — | `{name, due_days?, day_of_month_due?, due_next_month_days?, discount_percent?, discount_days?}` | `books.read` / `books.write` | read only |
| `payment-methods` | — | `{name, kind}` | `books.read` / `books.write` | read only |
| `tax-agencies` | — | `{name, registration_number?, filing_frequency?}` (creates its liability account) | `books.read` / `books.write` | read only |
| `tax-rates` | `agency_id` | `{agency_id, name, rate_percent}` | `books.read` / `books.write` | read only |
| `tax-codes` | — | `{name, description?, rate_ids[]}` | `books.read` / `books.write` | read only |
| `dimensions` | — | `{name, applies_to: line\|document}` (presets exist already) | `books.read` / `books.write` | read only |
| `dimensions/{did}/values` | — | `{name, parent_id?}` | `books.read` / `books.write` | read only |
| `custom-fields` | `entity_type` | `{entity_type, doc_type?, name, value_type, options?}` | `books.read` / `books.write` | read only |
| `bank-rules` | `account_id` | `{name, priority, account_id?, conditions, actions, auto_add}` | `books.read` / `bank.review` | read only |

Extra list endpoints:

| Method | Path | Operation | Request → Response | Permission | Agent |
|---|---|---|---|---|---|
| GET | `/…/contacts/{id}/open-items` | contacts.open_items | `?ledger=ar\|ap` → `[OpenItem {document_id, doc_type, number, date, due_date, original, open}]` | `books.read` | yes |
| GET | `/…/contacts/{id}/statement` | contacts.statement | `?from&to` → `Statement` | `books.read` | yes |
| POST | `/…/attachments` | attachments.upload | multipart `file`, optional `entity_type`, `entity_id` → `Attachment` | `books.write` | yes (own drafts only) |
| GET | `/…/attachments/{id}` and `/…/attachments/{id}/content` | attachments.get / content | → `Attachment`; raw bytes with the stored content type | `books.read` | yes |
| POST / DELETE | `/…/attachments/{id}/links`, `/…/attachments/{id}/links/{entity_type}/{entity_id}` | attachments.link / unlink | `{entity_type, entity_id}` | `books.write` | no |

### 5.4 Documents

**Generic endpoints** (any document type):

| Method | Path | Operation | Request → Response | Permission | Agent |
|---|---|---|---|---|---|
| GET | `/…/documents` | documents.search | filters `doc_type[]`, `status[]`, `contact_id`, `from`, `to`, `number`, `q`, `min_total`, `max_total`, `created_by_actor_type`; `sort` → `Paged<DocumentSummary>` | `books.read` | yes |
| GET | `/…/documents/{id}` | documents.get | → `Document` | `books.read` | yes |
| GET | `/…/documents/{id}/journal` | documents.journal | → `JournalView {entries[{id, kind, date, rules_version, postings[]}]}` | `books.read` | yes |
| GET | `/…/documents/{id}/history` | documents.history | → `[AuditEventView]` | `books.read` | yes |
| POST | `/…/documents/{id}/post` | documents.post | `{lock_override_reason?}` → `Document` | `documents.post` | **no** |
| POST | `/…/documents/{id}/approve` | documents.approve | `{lock_override_reason?}` → `Document` (draft created by `api` or `agent` → posted, approver recorded) | `documents.post` | **no** |
| POST | `/…/documents/{id}/void` | documents.void | `{reason, lock_override_reason?}` → `Document` | `documents.post` | **no** |
| DELETE | `/…/documents/{id}` | documents.delete_draft | → 204 (drafts only) | `books.write`; an agent only for drafts it created | own drafts |
| GET | `/…/approvals` | approvals.list | → `Paged<DocumentSummary>` (drafts created by `api` or `agent`) | `books.read` | yes |
| GET | `/…/documents/{id}/pdf` | render.pdf | → `application/pdf` | `books.read` | yes |
| GET | `/…/documents/{id}/preview` | render.preview | → `{pages: ["<svg>...</svg>"]}` | `books.read` | yes |
| POST | `/…/documents/{id}/send` | render.send | `{to[], cc[]?, subject?, message?}` → 202 `Job` | `documents.send` | no |

**Typed endpoints.** Each type has its own collection with the same five operations:

| Method | Path | Operation | Request → Response |
|---|---|---|---|
| GET | `/…/{type-path}` | list | type-specific filters → `Paged<DocumentSummary>` |
| POST | `/…/{type-path}` | create | `<Type>Input` (+ `post: bool`) → 201 `Document` (draft, or posted when `post = true`) |
| GET | `/…/{type-path}/{id}` | get | → `Document` |
| PUT | `/…/{type-path}/{id}` | replace | `<Type>Input`, If-Match. A draft is edited in place; a posted document is reposted (LEDGER_SPEC §6). |
| — | post, void, approve, delete | — | through the generic endpoints above |

| Type path | `doc_type` | Permission to create | Agent may create |
|---|---|---|---|
| `estimates` (+ `POST /…/estimates/{id}/convert` → draft invoice; `PUT /…/estimates/{id}/status {status}`) | estimate | `books.write` | yes (draft) |
| `invoices` | invoice | `books.write` | yes (draft) |
| `sales-receipts` | sales_receipt | `books.write` | yes (draft) |
| `customer-payments` | customer_payment | `books.write` | no |
| `credit-memos` | credit_memo | `books.write` | yes (draft) |
| `refund-receipts` | refund_receipt | `books.write` | no |
| `customer-refunds` | customer_refund | `books.write` | no |
| `bills` | bill | `books.write` | yes (draft) |
| `bill-payments` | bill_payment | `books.write` | no |
| `vendor-credits` | vendor_credit | `books.write` | yes (draft) |
| `expenses` | expense | `books.write` | yes (draft) |
| `card-credits` | card_credit | `books.write` | yes (draft) |
| `vendor-refunds` | vendor_refund | `books.write` | no |
| `deposits` | deposit | `books.write` | no |
| `transfers` | transfer | `books.write` | no |
| `journal-entries` | journal_entry | `books.write` | yes (draft) |
| `opening-balances` | opening_balance | `period.lock` | no |

Saving with `post = true` additionally needs `documents.post` and is refused for agents (403 `auth.agent_forbidden`). Agents never touch documents that move money (payments, refunds, deposits, transfers).

### 5.5 Banking and reconciliation

| Method | Path | Operation | Request → Response | Permission | Agent |
|---|---|---|---|---|---|
| POST | `/…/bank-imports` | bank_imports.create | multipart `file`, `account_id`, `format?` (auto-detected), `csv_mapping?` → `BankImportResult {import_id, imported, duplicates, errors[]}` | `bank.review` | no |
| GET | `/…/bank-imports` | bank_imports.list | → `Paged<BankImport>` | `books.read` | yes |
| GET | `/…/bank-transactions` | bank_txns.list | `account_id`, `status[]`, `from`, `to` → `Paged<BankTxn>` | `books.read` | yes |
| GET | `/…/bank-transactions/{id}` | bank_txns.get | → `BankTxn` with `suggestions[{document_id, score, reason}]` and rule suggestion | `books.read` | yes |
| POST | `/…/bank-transactions/{id}/match` | bank_txns.match | `{document_id}` → `BankTxn` | `bank.review` | no |
| POST | `/…/bank-transactions/{id}/add` | bank_txns.add | `{doc_type: expense\|deposit\|transfer, account_id, contact_id?, memo?, dimensions?}` → `{bank_txn, document}` (posted for humans, a draft linked as a suggestion for agents) | `bank.review` (humans), `drafts.write` (agents) | yes (draft) |
| POST | `/…/bank-transactions/{id}/exclude`, `/undo` | bank_txns.exclude / undo | → `BankTxn` | `bank.review` | no |
| POST | `/…/bank-rules/{id}/preview` | bank_rules.preview | → `[BankTxn]` that would match | `books.read` | yes |
| POST | `/…/reconciliations` | recon.start | `{account_id, statement_date, ending_balance}` → `Reconciliation` | `reconcile` | no |
| GET | `/…/reconciliations` | recon.list | `account_id` → `Paged<ReconciliationSummary>` | `books.read` | yes |
| GET | `/…/reconciliations/{id}` | recon.get | → `Reconciliation {beginning, ending, cleared_total, difference, candidates[], ticked[]}` | `books.read` | yes |
| PATCH | `/…/reconciliations/{id}` | recon.update | `{statement_date?, ending_balance?}` (in progress only) | `reconcile` | no |
| POST | `/…/reconciliations/{id}/ticks` | recon.tick | `{ticks: [{line_key, ticked}]}` → `Reconciliation` | `reconcile` | no |
| POST | `/…/reconciliations/{id}/complete` | recon.complete | → `Reconciliation` (422 `reconciliation.difference_not_zero` if not 0) | `reconcile` | no |
| POST | `/…/reconciliations/{id}/undo` | recon.undo | `{reason}` → `Reconciliation` | `reconcile` | no |
| DELETE | `/…/reconciliations/{id}` | recon.discard | in progress only → 204 | `reconcile` | no |
| POST | `/…/clearing/unreconcile` | clearing.unreconcile | `{account_id, line_key, reason}` → 204 | `reconcile` | no |
| GET / POST | `/…/bank-feeds` | feeds.list / feeds.connect | `{provider: simplefin, setup_token}` → `[ProviderAccount]` | `books.read` / `bank.feeds.manage` | read only |
| POST | `/…/bank-feeds/{id}/link`, `/sync`, `/disable` | feeds.link / sync / disable | `{account_id}` / → 202 `Job` / → `BankFeed` | `bank.feeds.manage` (sync also `bank.review`) | no |

### 5.6 Reports and audit

All reports are `GET`, take `basis=accrual|cash` (default accrual) where relevant, plus dimension filters `dim[<dimension_id>]=<value_id>`, and answer `application/json` or `text/csv`.

| Path | Operation | Parameters | Response |
|---|---|---|---|
| `/…/reports/trial-balance` | reports.trial_balance | `as_of` | `TrialBalance {as_of, basis, rows[{account_id, code, name, class, debit, credit}], total_debit, total_credit}` |
| `/…/reports/profit-and-loss` | reports.profit_and_loss | `from`, `to`, `group_by=total\|month\|dimension:<id>`, `compare=none\|previous_period\|previous_year` | `ProfitAndLoss {columns[], sections[{class, rows[{account_id, name, amounts[]}], totals[]}], net_income[]}` |
| `/…/reports/balance-sheet` | reports.balance_sheet | `as_of`, `compare` | `BalanceSheet {columns[], assets, liabilities, equity{rows, retained_earnings, net_income}, checks{balanced}}` |
| `/…/reports/general-ledger` | reports.general_ledger | `from`, `to`, `account_id[]` | `GeneralLedger {accounts[{account_id, opening, rows[{date, document_id, doc_type, number, contact, memo, amount, running}], closing}]}` |
| `/…/reports/journal` | reports.journal | `from`, `to` | `Journal {entries[{document_id, number, date, kind, postings[]}]}` |
| `/…/reports/ar-aging`, `/…/reports/ap-aging` | reports.aging | `as_of`, `detail=summary\|detail`, `contact_id?` | `Aging {as_of, buckets[], contacts[{contact_id, name, amounts[], items[]?}], totals[]}` |
| `/…/reports/sales-tax-liability` | reports.sales_tax | `from`, `to` | `SalesTaxLiability {agencies[{agency_id, name, taxable_base, tax, payments, balance}]}` |
| `/…/audit-events` | audit.list | `from`, `to`, `actor_type`, `entity_type`, `entity_id`, `action` | `Paged<AuditEventView>` |

Permission: `reports.read` (audit events: `audit.read`). Agents may read reports with scope `reports:read`; audit events never.

### 5.7 Imports and exports

| Method | Path | Operation | Request → Response | Permission | Agent |
|---|---|---|---|---|---|
| POST | `/…/imports` | imports.start | `{source: qbo_api\|csv\|interchange\|iif, options}` (multipart when a file is sent) → 202 `Job` + `ImportRun` | `import.run` | no |
| GET | `/…/imports` and `/…/imports/{id}` | imports.list / get | → `ImportRun {status, stats, validation{months[], aging[], residuals[]}, warnings[]}` | `import.run` | no |
| POST | `/…/imports/{id}/rollback` | imports.rollback | `{reason}` → 202 `Job` | `import.run` | no |
| POST | `/…/imports/qbo/connect` | qbo.connect | → `{authorize_url, state}` | `import.run` | no |
| GET | `/…/imports/qbo/callback` | qbo.callback | `?code&state&realmId` (browser redirect, server mode) → 302 to the migration page | session | no |
| POST | `/…/imports/qbo/token` | qbo.token | `{realm_id, access_token, refresh_token, access_expires_at}` (paste flow) → 204 | `import.run` | no |
| POST | `/…/exports` | exports.start | `{format: interchange\|csv}` → 202 `Job` | `export.run` | no |
| GET | `/…/exports/{id}/download` | exports.download | → `application/zip` | `export.run` | no |

## 6. Roles, permissions and scopes

`domain::auth::permits(principal, permission)` is the single source of truth, a pure function covered by an exhaustive table test (T-ID-1).

| Permission | owner | admin | accountant | bookkeeper | viewer |
|---|---|---|---|---|---|
| `company.read`, `books.read`, `reports.read` | ✓ | ✓ | ✓ | ✓ | ✓ |
| `books.write` (lists, drafts, attachments) | ✓ | ✓ | ✓ | ✓ | |
| `documents.post` (post, approve, void, repost) | ✓ | ✓ | ✓ | ✓ | |
| `documents.send` | ✓ | ✓ | ✓ | ✓ | |
| `bank.review`, `reconcile` | ✓ | ✓ | ✓ | ✓ | |
| `bank.feeds.manage` | ✓ | ✓ | | | |
| `period.lock`, `period.override` | ✓ | ✓ | ✓ | | |
| `period.unlock_hard` | ✓ | | | | |
| `audit.read` | ✓ | ✓ | ✓ | | |
| `import.run`, `export.run`, `company.backup` | ✓ | ✓ | ✓ | | |
| `settings.manage`, `members.manage` | ✓ | ✓ | | | |
| Installation level: `company.create`, `users.manage` | users with `is_admin` | | | | |

**Token scopes** narrow a token below its owner's role. The effective permission is: role permits **and** scope permits **and** the agent rule.

| Scope | Grants | Allowed for `api` tokens | Allowed for `agent` tokens |
|---|---|---|---|
| `books:read` | `company.read`, `books.read` | ✓ | ✓ |
| `reports:read` | `reports.read` | ✓ | ✓ |
| `drafts:write` | create, update and delete drafts the token created; attachments on those drafts; `bank.add` as draft | ✓ | ✓ |
| `books:write` | `books.write`, `documents.post`, `bank.review`, `reconcile` | ✓ | **never** (T-ID-2) |

**Agent rule (I-10).** A principal with `actor_type = agent` is refused (403 `auth.agent_forbidden`) on: post, approve, void, repost, delete of non-own drafts, period locks, reconciliation, bank match, exclude and undo, imports, exports, backups, settings, members, users, tokens, bank feeds and audit events. This holds whatever scopes are granted (T-API-1).

**Machine-readable permissions.** Every operation in the generated OpenAPI document carries two extensions: `x-bookscraft-permission` (a permission name from the table above, or `none` or `authenticated`) and `x-bookscraft-agent` (`true` when an agent may call it, matching the Agent column in section 5). Handlers check the permission before calling a service, so a refusal does not depend on the service being implemented. T-API-1 enumerates the operations from `api::openapi()` and calls every operation marked `x-bookscraft-agent: false` with an agent token, expecting 403 `auth.agent_forbidden`; T-API-2 fails when an operation lacks either extension. Area work packages therefore add their routes to the test automatically.

## 7. Shared DTO shapes

### 7.1 Document

`<Type>Input` is the subset of the fields below that the type allows (DATA_MODEL.md §4.1). Responses always use the full `Document`.

```json
{
  "id": "0192f0c4-...",
  "doc_type": "invoice",
  "status": "posted",
  "revision": 1,
  "version": 3,
  "number": "INV-1002",
  "date": "2026-03-02",
  "due_date": "2026-04-01",
  "contact_id": "...",
  "currency": "USD",
  "ar_ap_account_id": "...",
  "money_account_id": null,
  "payment_method_id": null,
  "reference_number": null,
  "terms_id": "...",
  "tax_code_id": "...",
  "tax_mode": "exclusive",
  "tax_after_discount": true,
  "discount": { "kind": "percent", "value": "5" },
  "discount_account_id": null,
  "memo": "Thank you for your business.",
  "private_note": null,
  "billing_address": { "line1": "...", "line2": null, "city": "...", "region": "...", "postal_code": "...", "country": "US" },
  "shipping_address": null,
  "dimensions": { "<dimension_id>": "<value_id>" },
  "custom_fields": { "<custom_field_id>": "value" },
  "lines": [
    {
      "line_key": "...", "line_no": 1, "kind": "item", "item_id": "...", "account_id": null, "contact_id": null,
      "description": "Brand identity package", "qty": "1", "unit_price": "4500.00",
      "amount": { "amount": "4500.00", "currency": "USD" }, "taxable": false, "tax": null,
      "service_date": null, "source_document_id": null, "dimensions": { "<class_dimension_id>": "<brand_value_id>" }
    }
  ],
  "applications": [
    { "charge_document_id": "...", "credit_document_id": "...", "amount": { "amount": "2500.00", "currency": "USD" } }
  ],
  "totals": {
    "subtotal": { "amount": "5300.00", "currency": "USD" },
    "discount": { "amount": "265.00", "currency": "USD" },
    "tax": { "amount": "62.70", "currency": "USD" },
    "total": { "amount": "5097.70", "currency": "USD" },
    "open": { "amount": "2597.70", "currency": "USD" }
  },
  "tax_lines": [ { "tax_rate_id": "...", "agency_id": "...", "taxable_base": { "amount": "760.00", "currency": "USD" }, "tax": { "amount": "47.50", "currency": "USD" } } ],
  "estimate_status": null,
  "links": [ { "type": "converted_from", "document_id": "..." } ],
  "attachment_ids": [],
  "journal_entry_ids": ["..."],
  "source": "ui",
  "created_by": { "actor_type": "user", "id": "...", "name": "Owner" },
  "approved_by": null,
  "voided": null,
  "created_at": "2026-03-02T15:04:05.123Z",
  "updated_at": "2026-03-13T09:12:44.001Z",
  "warnings": []
}
```

Input-only fields: `post` (boolean, default false) and `lock_override_reason` (string). In `<Type>Input`, `number` may be null (assigned from the number sequence when posted), `due_date` may be null (computed from terms), `ar_ap_account_id` may be null (the default AR or AP account), and `line_key` may be null for new lines. Totals and tax lines are always computed by the server: posting them is rejected (`validation.read_only_field`), except on imports.

### 7.2 Other shapes

| DTO | Fields |
|---|---|
| `DocumentSummary` | `id, doc_type, status, number, date, due_date, contact {id, name}, total, open, created_by.actor_type, version` |
| `Account` | `id, code, name, class, subtype, detail, parent_id, currency, system_role, description, is_archived, balance (as of today, accrual), version` |
| `Contact` | `id, display_name, company_name, given_name, family_name, roles {customer, vendor, employee}, parent_id, email, phone, website, billing_address, shipping_address, tax_id_last4, is_1099, is_taxable, default_tax_code_id, default_terms_id, currency, notes, custom_fields, is_archived, open_ar, open_ap, version` (the full tax id is write-only) |
| `Item` | `id, name, sku, kind, parent_id, sales_description, sales_price, income_account_id, purchase_description, purchase_cost, expense_account_id, asset_account_id, is_taxable, components[], custom_fields, is_archived, version` |
| `BankTxn` | `id, account_id, source, external_id, posted_date, amount, payee, memo, check_number, status, matched {document_id, line_key}?, suggestions[], rule_suggestion?` |
| `Reconciliation` | `id, account_id, statement_date, beginning, ending, cleared_total, difference, status, candidates[{line_key, posting_id, date, document_id, number, payee, amount, ticked}], completed_at, snapshot_hash, version` |
| `Job` | `id, kind, status (queued, running, succeeded, failed, canceled), progress {done, total}?, result?, error? (ProblemDetails), created_at, finished_at` |
| `ImportRun` | `id, source, status, stats {created{entity: n}, duplicates{entity: n}, archived{entity: n}}, validation {months[{month, tb_matches, differences[]}], aging[{contact, ar_matches, ap_matches}], residuals[{document_id, month, amount}]}, warnings[], backup_path` |
| `AuditEventView` | `seq, occurred_at, actor {type, id, name}, via, action, entity_type, entity_id, before, after, reason, request_id` |

## 8. MCP surface (W5-02)

| Topic | Rule |
|---|---|
| SDK | `rmcp` 3.x with features `server`, `macros`, `transport-io`, `transport-streamable-http-server`, `schemars` |
| Transports | stdio (`bookscraft mcp --company <file>` or `--server <url> --token-file <file>`) and streamable HTTP at `/mcp` in server mode |
| Authentication | Agent token (bearer on HTTP; `--token-file` or `BOOKSCRAFT_TOKEN` on stdio remote). Locally, the process acts as the desktop principal with `actor_type = agent`, so I-10 holds in every mode. |
| Resources and prompts | None in MVP |
| Output | Tool results are JSON objects with the same shapes as the HTTP DTOs, plus a short text summary |

| Tool | Scope | Purpose |
|---|---|---|
| `list_accounts` | `books:read` | Chart of accounts with balances |
| `list_contacts` | `books:read` | Search contacts by name or role |
| `list_items` | `books:read` | Products and services |
| `search_documents` | `books:read` | Search by type, status, contact, date range, number or text |
| `get_document` | `books:read` | One document with lines, applications and journal |
| `list_bank_transactions` | `books:read` | Bank lines (default: to review) with suggestions |
| `run_report` | `reports:read` | trial_balance, profit_and_loss, balance_sheet, general_ledger, ar_aging, ap_aging, sales_tax_liability |
| `create_draft_invoice`, `create_draft_bill`, `create_draft_expense`, `create_draft_journal_entry`, `create_draft_credit_memo`, `create_draft_vendor_credit`, `create_draft_estimate` | `drafts:write` | Create a draft (never posted); returns the draft and its approval URL |
| `update_draft`, `delete_draft` | `drafts:write` | Only drafts created by the same token |
| `propose_bank_categorization` | `drafts:write` | For a bank line: create a draft expense, deposit or transfer and attach it as the line's suggestion |

Never exposed as tools: post, approve, void, repost, delete of others' drafts, payments, refunds, deposits, transfers, period locks, reconciliation, imports, exports, settings, users, tokens, bank feeds, attachments of posted documents. The tool list is snapshot-tested (T-MCP-1).

## 9. CLI surface (W4-02)

```text
bookscraft [--company <file> | --server <url> [--token-file <file>]] [--data-dir <dir>] [--format table|json|csv] [--yes] <command>

serve        --config <file> --bind <addr:port> [--tls-cert <pem> --tls-key <pem>] [--ui-dir <dir>]
mcp          (stdio; uses --company or --server)
company      create --name <n> --currency <ISO> --fy-start <1-12> --time-zone <IANA> --template <freelancer|agency|service|blank> [--path <file>]
             list | info
import       qbo [--realm <id>] [--qbo-tokens <json file>] | csv --kind <accounts|contacts|items|bank-lines> --map <mapping.toml> <file>
             | interchange <bundle.zip> | iif <file> (v1) | ofx --account <code-or-id> <file>
export       --format <interchange|csv> --out <path>
verify       [<file>] [--full]
backup       [<file>] [--out <path>]
report       <trial-balance|profit-and-loss|balance-sheet|general-ledger|ar-aging|ap-aging|sales-tax> [--as-of <date> | --from <date> --to <date>] [--basis accrual|cash]
user         add <username> --display-name <n> [--admin] | list | disable <username> | reset-password <username>
token        create --user <username> --name <n> --actor <api|agent> --scopes <list> [--company <id>] [--expires <date>] | list | revoke <id>
```

| Rule | Detail |
|---|---|
| Local vs remote | `--company <file>` composes the services in-process and takes the file's exclusive lock. `--server` calls the HTTP API with the token. Exactly one of them is required for company commands. |
| Actor | Local commands act as the system file's desktop principal (`via = cli`). Remote commands act as the token's principal. |
| Output | `table` for humans (default on a TTY), `json` (the HTTP DTOs) and `csv` (reports and lists). |
| Exit codes | 0 success; 1 unexpected error; 2 usage error; 3 domain validation (422-class); 4 conflict or locked (409, 412, `store.company_locked`); 5 not found; 6 permission denied |
| Secrets | Never accepted as plain flags. Passwords are prompted. The BooksCraft API token for `--server` comes from `--token-file` or `BOOKSCRAFT_TOKEN`; QBO OAuth tokens come from the `--qbo-tokens` file. |
