# W0-04: Storage engine and migration framework

## Goal

Build `crates/store`: company and system SQLite files created from the normative schemas, the open sequence and file lock, transactions, the single write path for the ledger, the hash-chained audit log with `verify`, backups, idempotency keys and the job queue, with every storage rule proven by a test.

## Wave and concurrency

- Wave 0, order 4. Starts when W0-05 is merged. W0-06 may run beside it.
- Agent: `storage-engineer`.
- Timebox: three sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/store/**`, `Cargo.lock`
- `docs/coordination/CCR/CCR-W0-04-*.md`, `docs/coordination/handoffs/W0-04.md`

Read-only: everything else, including `docs/architecture/schema.sql` and `schema-system.sql` (the migrations must equal them; a needed schema change is a CCR).

## Read first

1. `CLAUDE.md` and `.claude/agents/storage-engineer.md`.
2. `docs/architecture/DATA_MODEL.md` in full.
3. `docs/architecture/schema.sql` and `docs/architecture/schema-system.sql` in full.
4. `docs/architecture/LEDGER_SPEC.md` §3, §5, §6, §9, §10 and §11.
5. `docs/architecture/ARCHITECTURE.md` §4.2 (`IdempotencyStore`, `JobQueue`), §4.6 (data access), §12 (jobs), §13 (limits).
6. `docs/architecture/API.md` §2 (idempotency semantics).
7. ADR-0003, 0007, 0009, 0011, 0012 and 0024.
8. `crates/ledger` and `crates/domain` as merged.

## Preconditions

| Precondition | Check |
|---|---|
| W0-05 is merged | `git log origin/main --format=%s \| grep -q '^W0-05: '` |

## Scope in/out

In:

- **Files and opening:** company files (`*.bookscraft`) and the system file, located through `platform::dirs` (or any path the caller gives); the open sequence of DATA_MODEL §2 (lock with diagnostics in `<file>.lock`, pragmas, refuse newer files with `store.file_too_new`, back up then migrate, quick `verify`); `store.company_locked` with the holder's details; the company registry in the system file, where paths that differ only by case conflict (T-PLAT-5).
- **Migrations:** embedded forward-only SQL; `crates/store/migrations/company/0001_initial.sql` equal to `schema.sql` and `crates/store/migrations/system/0001_initial.sql` equal to `schema-system.sql`; `schema_migrations` with checksums; tests `schema_matches_spec` for both files.
- **Transactions:** one write connection per file with `BEGIN IMMEDIATE`; a small read pool; `store::sql` re-exports `rusqlite`; a write handle that runs the pre-commit check (`ledger.entry_left_open`) and maps every trigger error to `StoreError::Constraint(code)` with the exact code string (reusing `ledger::codes` constants where the code is the ledger's).
- **Ledger write path** (DATA_MODEL §4.3), the only code that writes `journal_entry`, `posting`, `posting_dimension`, `lock_override`, `settlement` and `clearing_event` for documents: `store::ledger::post_revision` (post and repost) and `store::ledger::void_document`, taking the document, the new revision's lines, tax lines and dimensions, the `PostedEntry`, the settlement rows, any lock-override reason, and the actor; it writes reversal and original entries (open, postings, finalize), settlements, the header update, clearing events for changed money lines (LEDGER_SPEC §11), the reconciled-line rule (`reconciliation.reconciled_line_changed`), the entry `content_hash`, and the audit event, in one transaction.
- **Audit:** `store::audit::append` (canonical JSON, SHA-256 chain, LEDGER_SPEC §10) for both files; `verify` in quick (last 1,000 events) and full mode, recomputing every hash and every entry `content_hash` and reporting the first mismatch.
- **Backups:** SQLite online backup to `<data_dir>/backups/` or a given path.
- **Idempotency:** the `IdempotencyStore` port for both files (begin, complete, replay; 24-hour expiry; `idempotency.key_reused`, `idempotency.in_progress`).
- **Jobs:** the `JobQueue` port over the system file's `job` table: enqueue, exclusive claim of due jobs, complete, fail with retry after 1, 5 and 30 minutes and then `failed`.
- **`Stores`:** the system store plus the set of open company files (one on desktop, many on a server), resolved by `CompanyId`; `idempotency()` and `jobs()` return the real implementations.

Out: SQL for lists, documents, banking or imports (each service owns its SQL), services, HTTP.

## Tasks

1. File opening, pragmas, lock, registry, migrations and the `schema_matches_spec` tests.
2. Transactions, error mapping and the T-STORE tests (DATA_MODEL §6), one named test per case.
3. Audit append and verify.
4. The ledger write path with its tests.
5. Backups, idempotency, jobs.

## Invariants touched

| Invariant | Test |
|---|---|
| I-3 | T-STORE-1..4, T-STORE-6..10, T-STORE-20 |
| I-5 | T-STORE-12 |
| I-6 | T-STORE-13, T-STORE-19 |
| I-7 | T-STORE-15 |
| I-13 | T-PLAT-5 (case-insensitive name conflict, temporary directories only) |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | The migrations build exactly the normative schemas | tests `schema_matches_spec_company` and `schema_matches_spec_system` compare normalized `sqlite_schema` rows from the migrations and from the `docs/architecture` files |
| AC-2 | Every storage case in DATA_MODEL §6 behaves as specified | 20 tests named `t_store_01_…` to `t_store_20_…`, each asserting the exact error code or success |
| AC-3 | A second open of a locked file fails with `store.company_locked` and the holder's details; a file with a newer schema version fails with `store.file_too_new`; a pending migration writes a backup first | tests |
| AC-4 | `verify` finds tampering | tests: with triggers dropped, an edited `after_json`, an edited posting amount and a deleted audit event are each reported with the first broken `seq` (and the entry id for the posting) |
| AC-5 | The write path posts, reposts and voids per DATA_MODEL §4.3 | tests: post writes revision 1 and `E1`; a repost writes the reversal of `E1` dated like `E1` and `E2`, and old settlements leave `active_settlement`; a void writes only the reversal and freezes the document; each case appends one audit event whose `after_json` holds the new entries' `content_hash` |
| AC-6 | The reconciled-line rule holds | test: reposting a document whose money line key is reconciled, with a changed amount, fails with `reconciliation.reconciled_line_changed`; an unchanged money line passes |
| AC-7 | A transaction cannot commit with an open entry | test expects `ledger.entry_left_open` and a rollback |
| AC-8 | Idempotency follows API.md §2 | tests: same key and body replays the stored response; same key with another body gives `idempotency.key_reused`; a running key gives `idempotency.in_progress`; keys expire after 24 hours (injected clock) |
| AC-9 | Jobs are claimed exclusively and retried on schedule | tests: two claimers, one gets the job; failures reschedule after 1, 5 and 30 minutes, then the job is `failed` |
| AC-10 | Company names differing only by case conflict on every OS | test in a temporary directory: registering `Acme` then `acme` fails |
| AC-11 | Lints pass and no other crate changed | `cargo xtask lint` exits 0; `cargo xtask scope W0-04` exits 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-store --all-targets -- -D warnings
cargo test --locked -p bookscraft-store
cargo build --locked --workspace
cargo xtask lint
cargo xtask spine
cargo xtask scope W0-04
```

## Deliverables

- Branch: `wp/W0-04-store`
- PR title: `W0-04: Storage engine, ledger write path and audit chain`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work. A needed schema change is a CCR containing the full SQL; the migration and `schema.sql` change land together in Weave 0.
- SQLite behaves differently from what `schema.sql` assumes (a trigger cannot express a rule): raise a CCR with a failing test.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
