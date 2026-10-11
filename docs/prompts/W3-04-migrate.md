# W3-04: Migration pipeline, CSV lists, parity validation, rollback, export

## Goal

Build `crates/migrate` (except the QBO connector): the import pipeline from interchange bundles into the services, CSV and XLSX list import, validation against source reports with residual reconstruction, rollback, the export bundle, and the import and export routes in `crates/api/src/routes/imports.rs`.

## Wave and concurrency

- Wave 3, batch A (with W3-03 and W3-05). Paths do not overlap; the QBO connector comes later in `crates/migrate/src/qbo/` (W4-03): create that module as a placeholder whose functions return `api.not_implemented`, each taking `&Ctx`, the crate's `Stores`, `Infra` and `Services` (from `migrate::build`) and the operation's command or the job, so W4-03 never needs to change their signatures (any test of the placeholder goes in `crates/migrate/tests/qbo_placeholder.rs`, which W4-03 owns and replaces).
- Agent: `import-migration-engineer`. A `security-reviewer` pass is required in Weave 3.
- Timebox: three sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/migrate/src/**`, `crates/migrate/tests/**`, `crates/migrate/fixtures/**`, `crates/api/src/routes/imports.rs`
- `docs/coordination/CCR/CCR-W3-04-*.md`, `docs/coordination/handoffs/W3-04.md`

Read-only: everything else, including `crates/interchange`, `crates/iif`, `crates/qbo`, the services and `tests/scenarios` (call `scenarios::copperline::build` from your tests).

## Read first

1. `CLAUDE.md` and `.claude/agents/import-migration-engineer.md`.
2. `docs/architecture/MIGRATION_SPEC.md` in full.
3. `docs/architecture/LEDGER_SPEC.md` §4.16 (residual journal entries), §4.17 (opening balances), §8.1 (import rounding).
4. `docs/architecture/DATA_MODEL.md` §8 and `docs/architecture/interchange-v1.md`.
5. `docs/architecture/API.md` §5.7 and §9 (`import csv --map`).
6. ADR-0012 and ADR-0017.

## Preconditions

| Precondition | Check |
|---|---|
| Weave 2 is merged | `git log origin/main --format=%s \| grep -q '^Weave 2: '` |
| The imports route module is pre-registered | `git show origin/main:crates/api/src/routes/imports.rs > /dev/null` |
| The spine company builder exists | `git grep -q 'pub fn build' origin/main -- tests/scenarios/src` |

## Scope in/out

In:

- **Pipeline:** an interchange bundle into a new company file (default) through the services' commands in the order of MIGRATION_SPEC §4.2, with `via = import` and the importing user as actor; `external_ref` per record (unique on source, realm, type, id); re-run rules of §9 (skip same sync token, refresh unchanged entities in open periods, report conflicts, never delete); amounts as received with the posting tolerance of 2 minor units (posting codes reported as `import.rounding_adjusted` and `import.unbalanced_source`); voided source transactions imported as posted with no entry, then voided without a reversal, keeping number and date; unmodeled records into `import_archive`; the run as an `import` job with progress and stats in `import_run`.
- **Validation** (§6) against source reports supplied with the bundle or by the caller (month-end trial balances, agings per contact, document balances, counts): gating checks fail the run with `import.parity_failed` and the differences; residual reconstruction posts one `is_residual` journal entry per month for the remaining trial balance delta, then reruns validation; the cash-basis comparison is reported, never gating.
- **CSV and XLSX lists** (§7): accounts, contacts, items and an opening trial balance; a column-mapping structure (the CLI parses its TOML file; the UI saves mappings by name); UTF-8 and Windows-1252; row external ids from a key column or `sha256(file name ‖ row number ‖ row content)`.
- **Rollback** (§10) in all three cases, never deleting a user file.
- **Export** (§11): the zip bundle with `manifest.json` (per-file SHA-256), one JSON Lines file per entity, `csv/` copies and `attachments/`; CSV-only export.
- **Routes:** `/imports` (start with multipart files, list, get, rollback), `/exports` (start, download), and the `qbo/connect`, `qbo/callback`, `qbo/estimate` and `qbo/token` routes calling `ImportService` (which answers `api.not_implemented` until W4-03).
- **Capabilities:** `ImportCsv`, `ImportInterchange`, `Export` when complete (`ImportQbo` is W4-03; `ImportIif` is v1).

Out: the QBO HTTP connector and token handling (W4-03), the migration wizard UI (W4-01), IIF import path (v1).

## Tasks

1. Pipeline and idempotency.
2. Validation and residual reconstruction.
3. CSV and XLSX lists.
4. Rollback and export.
5. Routes with contract tests; capabilities.

## Invariants touched

| Invariant | Test |
|---|---|
| I-1 | T-MIG-4: a source imbalance of ±2 minor units posts to the rounding account; ±3 fails |
| I-3 | rollback with later activity voids by reversal, never deletes (T-MIG-6) |
| I-7 | T-MIG-1 (W3-04 part): the same QBO-sourced interchange bundle imported twice creates nothing the second time and reports every record as duplicate |
| I-6 | each run writes its summary audit event plus per-document events |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | T-MIG-1 (W3-04 part) | test with a bundle whose records carry QBO source refs |
| AC-2 | T-MIG-3: the spine company round-trips | test: `scenarios::copperline::build`, export the bundle, import it into a new company; trial balances, agings and document counts are equal |
| AC-3 | T-MIG-4 | tests with ±2 and ±3 minor-unit source imbalances |
| AC-4 | T-MIG-5: residual reconstruction | test: a fixture with a hidden COGS posting in two months yields one residual journal entry per affected month, flagged `is_residual`, and validation then passes |
| AC-5 | T-MIG-6: rollback in all three cases | tests: new company file (registry entry archived, file kept), existing company without later activity (backup restored), existing company with later activity (documents voided in reverse order, list rows archived) |
| AC-6 | Validation gates the run | test: an unresolvable trial balance difference without residuals fails with `import.parity_failed` listing account and month |
| AC-7 | CSV and XLSX lists import with mappings, encodings and dedupe | tests: Windows-1252 file, debit and credit columns, a re-import skipping known rows, an opening trial balance that does not balance refused |
| AC-8 | Export bundle is well formed | test: manifest counts and SHA-256 values match the files; the bundle validates with `interchange` |
| AC-9 | Routes behave per API.md §5.7 | contract tests, including each of the four QBO routes mapping an `api.not_implemented` answer from a fake `ImportService` to 501 problem details (a fake, so the test survives W4-03) |
| AC-10 | Archives are safe to read | test: a bundle with a `../` entry or an absolute path is refused |
| AC-11 | No spine regression | `cargo xtask spine` prints `spine: 31 passed, 0 failed, 0 pending` |
| AC-12 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W3-04` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-migrate -p bookscraft-api --all-targets -- -D warnings
cargo test --locked -p bookscraft-migrate -p bookscraft-api
cargo xtask lint
cargo xtask spine
cargo xtask scope W3-04
```

Do not commit `docs/architecture/openapi.json` or `error-codes.md`: Weave 3 regenerates them.

## Deliverables

- Branch: `wp/W3-04-migrate`
- PR title: `W3-04: Migration pipeline, validation, rollback and export`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work.
- A service command cannot accept imported data as MIGRATION_SPEC §2 requires (source amounts, inclusive tax, residual entries): raise a CCR for that service's port.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
