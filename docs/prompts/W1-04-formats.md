# W1-04: Interchange, OFX and IIF libraries

## Goal

Build the three pure MIT format crates: `interchange` (BooksCraft's open import and export model, with its published schema), `ofx` (OFX 1.x and 2.x, QFX and QBO Web Connect statement parser) and `iif` (IIF reader, writer and mapping to interchange).

## Wave and concurrency

- Wave 1, batch B (with W1-03). Paths do not overlap.
- Agent: `import-migration-engineer`.
- Timebox: two sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/interchange/src/**`, `crates/interchange/tests/**`
- `crates/ofx/src/**`, `crates/ofx/tests/**`
- `crates/iif/src/**`, `crates/iif/tests/**`
- `docs/architecture/interchange-v1.md`
- `docs/coordination/CCR/CCR-W1-04-*.md`, `docs/coordination/handoffs/W1-04.md`

Read-only: everything else, including `tests/scenarios/fixtures/checking-2026-03.ofx` (used as a test input).

## Read first

1. `CLAUDE.md` and `.claude/agents/import-migration-engineer.md`.
2. `docs/architecture/MIGRATION_SPEC.md` §2, §3 (interchange model and bundle), §8 (IIF) and §9.
3. `docs/architecture/LEDGER_SPEC.md` §11 (which statement fields dedupe needs).
4. `docs/architecture/DATA_MODEL.md` §8 (entity fields the model must carry).
5. ADR-0005 (MIT crates: pure, permissive dependencies only) and ADR-0012 (keys and external refs).

## Preconditions

| Precondition | Check |
|---|---|
| Weave 0 is merged | `git log origin/main --format=%s \| grep -q '^Weave 0: '` |
| The spine's statement fixture exists | `git show origin/main:tests/scenarios/fixtures/checking-2026-03.ofx > /dev/null` |

## Scope in/out

In:

- **`interchange`:** the entities of MIGRATION_SPEC §3 with string keys (`qbo:Invoice:145` style), `money::Money` amounts and ISO dates; JSON Lines encoding and decoding per entity type; the `Manifest` struct (format, version 1, created time, company, counts, per-file SHA-256 supplied by the caller); validation (unique keys, every reference resolves, dependency order). `docs/architecture/interchange-v1.md` documents every entity: fields, types, required or optional, and one example line each.
- **`ofx`:** parse OFX 1.x (SGML, unclosed leaf tags), OFX 2.x (XML), QFX (Intuit extension tags ignored) and QBO Web Connect into `Statement { account, currency, ledger_balance, balance_date, lines }`, where each line has `fitid`, posted date, amount (exact, through `money`), `trntype`, name or payee, memo and check number. Honor the header's charset (US-ASCII, Windows-1252, UTF-8). Hostile-input safe: bounded nesting, input size checked by the caller (10 MB), errors with line numbers, never a panic.
- **`iif`:** read header rows and their data rows for `ACCNT`, `CUST`, `VEND`, `INVITEM`, `CLASS`, and `TRNS`/`SPL`/`ENDTRNS` blocks (Windows-1252 unless valid UTF-8); refuse a block whose splits do not sum to zero with its `TRNS` line (`iif.unbalanced_transaction`); map lists and transactions to interchange using an `ACCNTTYPE` table and the TRNSTYPE table of MIGRATION_SPEC §8, with external ids per §8 (the caller passes the realm, the file's SHA-256); write lists and journal-style transactions back to IIF.

Out: CSV and XLSX (in `migrate`, W3-04), the import pipeline, QBO types (W3-03), any I/O (the crates take bytes or `&str`).

## Tasks

1. `interchange` model, JSON Lines, manifest, validation, and `interchange-v1.md`.
2. `ofx` tokenizer and parser for both syntaxes, with hand-written fixtures.
3. `iif` reader, mapping and writer, with hand-written fixtures.
4. Property tests and goldens.

Fixtures are written by hand from the published formats, with invented names and amounts. No bank's or Intuit's sample file is copied.

## Invariants touched

| Invariant | Test |
|---|---|
| I-1 | amounts parsed exactly into `money` types; D-6 not applicable (not a money-path crate), floats still never used |
| I-7 | statement lines keep FITIDs; IIF rows keep their source ids |
| I-12 | D-1: the three crates depend only on MIT workspace crates and permissive externals |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | OFX 1.x, OFX 2.x, QFX and QBO fixtures parse to the expected statements | insta goldens in `crates/ofx/tests/` |
| AC-2 | The spine's statement parses correctly | test reads `tests/scenarios/fixtures/checking-2026-03.ofx`: nine lines, FITIDs `CL-0001`..`CL-0009`, amounts summing to 5,335.00, ledger balance 17,835.00 |
| AC-3 | Malformed input fails cleanly | fixtures with an unclosed aggregate, a bad amount and a bad date each give an error naming the line; a property test feeds 1,000 arbitrary byte strings and never panics |
| AC-4 | T-MIG-8: every IIF list and transaction type parses; an unbalanced block is refused; Windows-1252 names decode | goldens and tests in `crates/iif/tests/` |
| AC-5 | IIF write and read round-trip | test: write lists and transactions, read them back, equal |
| AC-6 | Interchange round-trips | property test: random valid bundles encode to JSON Lines and decode to equal values |
| AC-7 | Interchange validation catches bad bundles | tests: duplicate key, dangling reference, wrong dependency order |
| AC-8 | `interchange-v1.md` documents every entity of MIGRATION_SPEC §3 | test checks that each entity name appears as a heading in the document |
| AC-9 | Lints pass (D-1, D-2) and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W1-04` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-interchange -p bookscraft-ofx -p bookscraft-iif --all-targets -- -D warnings
cargo test --locked -p bookscraft-interchange -p bookscraft-ofx -p bookscraft-iif
cargo xtask lint
cargo xtask spine
cargo xtask scope W1-04
```

## Deliverables

- Branch: `wp/W1-04-formats`
- PR title: `W1-04: Interchange, OFX and IIF libraries`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work.
- A published format detail contradicts MIGRATION_SPEC: raise a CCR quoting the format's documentation.
- A needed dependency is not already declared for the crate: raise a CCR (no new dependencies).
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
