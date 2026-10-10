# W1-02: Books service

## Goal

Implement `CompanyService` and `BooksService` in `crates/books`: company lifecycle from templates, the chart of accounts and every list, manual sales tax setup and computation, dimensions, custom fields, attachments, journal entries, opening balances, period locks, drafts, approvals and the shared document helpers the other services use.

## Wave and concurrency

- Wave 1, batch A (with W1-01 and W1-05). Paths do not overlap.
- Agent: `ledger-engineer`.
- Timebox: three sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/books/src/**`, `crates/books/tests/**`, `crates/books/templates/**`
- `docs/coordination/CCR/CCR-W1-02-*.md`, `docs/coordination/handoffs/W1-02.md`

Read-only: everything else, including `crates/books/Cargo.toml` (dependencies are fixed), `crates/store`, `crates/domain`, `crates/posting`.

## Read first

1. `CLAUDE.md` and `.claude/agents/ledger-engineer.md`.
2. `docs/architecture/LEDGER_SPEC.md` §2 (accounts and roles), §4.16–§4.18, §6 (drafts, approval, void), §9 (locks), §10 (audit), Appendix A steps S01, S02, S26, S28, S30.
3. `docs/architecture/DATA_MODEL.md` §3–§5.
4. `docs/architecture/API.md` §5.2–§5.4 (what these services must support) and §6.
5. `docs/architecture/ARCHITECTURE.md` §4.2 (`CompanyService`, `BooksService`), §4.6 (data access: you write your own SQL; the store owns ledger writes and audit), §8 (`books::tax::ManualRates`, `books::locale::EnUs`).
6. ADR-0010, 0013, 0014, 0016, 0024.
7. The merged `crates/domain/src/ports.rs`, `crates/store`, `crates/posting` and `crates/test-support`.

## Preconditions

| Precondition | Check |
|---|---|
| Weave 0 is merged | `git log origin/main --format=%s \| grep -q '^Weave 0: '` |
| The store's ledger write path exists | `git grep -q 'pub fn post_revision' origin/main -- crates/store` |

## Scope in/out

In:

- **CompanyService:** create a company file from a template (freelancer, agency, service business, blank; templates come from the locale pack in `Infra.locales` that matches the company's locale, falling back to the built-in `EnUs`, so tests with no locale packs still get them): system accounts with their roles (LEDGER_SPEC §2), the preset dimensions `class` (line), `location` (document) and `project` (line), number sequences, default terms (Due on receipt, Net 15, Net 30) and payment methods (Cash, Check, Card, Bank transfer, Other), plus the registry entry in the system file; list; get; update settings; get and set period locks (one audited command with before and after values and a reason of at least 5 characters; moving the hard date earlier needs the owner role, `books.hard_unlock_requires_owner`); backup and verify (each enqueues its job kind; the job handlers run the store's backup and verify).
- **BooksService:** accounts (create, update, archive and unarchive, hierarchy; system accounts protected, `books.system_account_protected`; archiving needs a zero balance, `books.account_in_use`); contacts with role flags and parents; items, including bundles; terms; payment methods; tax agencies (each creates its `sales_tax_payable` liability account), rates and codes; `books::tax` computing document tax with `money::calc` and the `ManualRates` `TaxRateProvider`; dimensions and hierarchical values; custom field definitions and values; attachments (upload with SHA-256 deduplication into `attachment_blob`, 25 MB limit, link, unlink, content); journal entries (save draft, update draft, post through `posting::post` and `store::ledger::post_revision`, repost, void; the reversing option posts a second entry dated X, linked by a `document_link` of type `reverses`, now or through a `reversing_entry` job when X is in the future); opening balances; generic document get, search, history and journal; delete draft; the approvals list; approve.
- **Shared helpers for `sales`, `purchases` and `banking`:** saving drafts with number sequences; posting, reposting and voiding through the store with lock overrides, where the lock check also covers documents that write no entry (hard-locked: `period.hard_locked`; soft-locked: the `period.override` permission and a reason, recorded in the `period.override` audit event, LEDGER_SPEC §9); refusing to repost or void a source of a posted deposit (`books.source_in_posted_deposit`); the agent rule; and `approval::approve_and_post` (checks that the draft was created by an `api` or `agent` principal and that the approver is a human with `documents.post`, records the approver, appends `approval.approve`, then posts).
- **Agent rule:** agents may create, update and delete their own drafts of the types API.md §5.4 allows; posting, approving, voiding, deleting others' drafts and changing locks fail with `auth.agent_forbidden`.
- **Locale:** `books::locale::EnUs` with the four templates as JSON data in `crates/books/templates/`, en-US money and date formatting.
- **Infrastructure constructors:** `books::infra::tax_rates()` returns `ManualRates` and `books::infra::locales()` returns `[EnUs]`, with the signatures W0-01 wrote (ARCHITECTURE §4.5).
- **Capabilities:** add each of `Company`, `Accounts`, `Contacts`, `Items`, `Terms`, `PaymentMethods`, `Tax`, `Dimensions`, `CustomFields`, `Attachments`, `JournalEntries`, `OpeningBalances`, `PeriodLocks`, `Approvals` and `Verify` to `CAPABILITIES` only when it is complete and tested.

Out: HTTP routes (W1-05), sales, purchases and banking documents (Wave 2), reports (W2-04), the dimension and custom-field management UI (v1).

## Tasks

1. Company creation and the templates.
2. Lists and tax setup, with `books::tax`.
3. Dimensions, custom fields, attachments.
4. Journal entries, opening balances, drafts, approvals, voids, and the shared helpers.
5. Period locks, backup and verify.
6. Register capabilities, then run `cargo xtask spine`.

## Invariants touched

| Invariant | Test |
|---|---|
| I-3 | journal entries post and void only through the store's write path; void is a reversal (test) |
| I-5 | T-BOOKS-1: lock changes and overrides are audited; moving the hard date earlier needs the owner and a reason |
| I-6 | T-AUDIT-1: `assert_audited` on every mutating command |
| I-8 | T-BOOKS-2: 200 dimensions, and one dimension with 1,000 values |
| I-9 | T-LIMIT-1 (books part): 2,000 accounts, 200 dimensions and 200 custom field definitions with no limit error |
| I-10 | T-BOOKS-3: approval stores the approver and appends `approval.approve`; agent post, approve and void fail with `auth.agent_forbidden` |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | Each template creates every system account with its role exactly once, plus the preset dimensions, terms and payment methods | a test per template |
| AC-2 | T-BOOKS-1 | tests: setting locks appends `period.set_locks` with before, after and reason; a reason under 5 characters fails; a non-owner moving the hard date earlier gets `books.hard_unlock_requires_owner`; posting into a soft-locked date with an override appends `period.override` |
| AC-3 | T-BOOKS-2 and T-LIMIT-1 (books part) | tests create 200 dimensions, 1,000 values in one dimension, 2,000 accounts and 200 custom field definitions without error |
| AC-4 | T-BOOKS-3 and the agent rule | tests: an agent creates a draft journal entry; its post, approve and void calls fail with `auth.agent_forbidden`; the owner approves; the document has `approved_by_user_id`; the audit shows `approval.approve` then `document.post` |
| AC-5 | Journal entries post, repost and void correctly | tests: JE-01 posts 100.00 Dr Depreciation / Cr Accumulated Depreciation; a repost writes a reversal plus a new entry; a void writes only a reversal; a reversing entry is linked to its original by `reverses`, and one dated in the future is queued as a `reversing_entry` job |
| AC-6 | Tax computation matches LEDGER_SPEC §4.1 | test: INV-1002's lines and the "Local 8.25%" code give tax 47.50 and 15.20 on a 760.00 base |
| AC-7 | Attachments are deduplicated and limited | tests: the same bytes uploaded twice store one blob; a 25 MB + 1 byte upload is refused |
| AC-8 | T-AUDIT-1 for every mutating command | each command's test calls `assert_audited` with the expected actor type, `via` and action |
| AC-9 | The spine runs its first two steps | `cargo xtask spine` prints `spine: 2 passed, 0 failed, 29 pending` |
| AC-10 | T-BOOKS-4: deposited documents are protected | tests with a source document and a posted deposit written through `store::ledger::post_revision`: the shared repost and void helpers refuse the source with `books.source_in_posted_deposit` |
| AC-11 | Templates fall back to the built-in locale | test: with no locale packs in `Infra`, creating a company from the `agency` template succeeds and creates its accounts |
| AC-12 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W1-02` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-books --all-targets -- -D warnings
cargo test --locked -p bookscraft-books
cargo xtask lint
cargo xtask spine
cargo xtask scope W1-02
```

## Deliverables

- Branch: `wp/W1-02-books`
- PR title: `W1-02: Books service`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work (a missing port method, a store helper, a schema change).
- A spine step S01 or S02 fails and the cause is outside `books`: raise a CCR with the failing output.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
