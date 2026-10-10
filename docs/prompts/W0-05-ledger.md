# W0-05: Ledger core and posting framework

## Goal

Build the MIT `ledger` crate (balanced entries that cannot be built unbalanced, reversals, lock evaluation, trial balance fold) and the `posting` framework with the journal entry and opening balance rules, proven by property and golden tests.

## Wave and concurrency

- Wave 0, order 3. Starts when W0-02 is merged. W0-06 may run beside it.
- Agent: `ledger-engineer`.
- Timebox: two sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/ledger/**`, `crates/posting/**`, `Cargo.lock`
- `docs/coordination/CCR/CCR-W0-05-*.md`, `docs/coordination/handoffs/W0-05.md`

Read-only: everything else, including `crates/domain` (use its document types as they are).

## Read first

1. `CLAUDE.md` and `.claude/agents/ledger-engineer.md`.
2. `docs/architecture/LEDGER_SPEC.md` §1–§3, §4.16, §4.17, §6 (reversal rules), §8.1, §9 and §13.
3. `docs/architecture/DATA_MODEL.md` §5 (which errors the type layer owns).
4. `docs/architecture/ARCHITECTURE.md` §2–§3 and §4.6 (error-code ownership).
5. ADR-0005 (the MIT crates), 0006, 0007, 0008 and 0010.
6. `crates/domain/src/documents.rs` and `crates/money` as merged by W0-02.

## Preconditions

| Precondition | Check |
|---|---|
| W0-02 is merged | `git log origin/main --format=%s \| grep -q '^W0-02: '` |

## Scope in/out

In:

- **`ledger` (MIT, pure, depends on `money` and permissive crates only):**
  - `PostingLine { account: Uuid, contact: Option<Uuid>, currency: Currency, amount: Minor, base_amount: Minor, line_key: LineKey, dimensions: Vec<(Uuid, Uuid)> }` with dimensions kept sorted;
  - `BalancedEntry`, built only by `BalancedEntry::new(date, lines)`, which refuses fewer than two lines (`ledger.too_few_lines`), a line whose amount and base amount are both zero (`ledger.zero_line`), a repeated line key (`ledger.duplicate_line_key`), a non-zero base sum (`ledger.unbalanced`), and a non-zero transaction sum when every line has one currency (`ledger.unbalanced_currency`);
  - `BalancedEntry::reversal()`: same date, accounts, contacts, currencies, line keys and dimensions, negated amounts;
  - `LockState { hard_locked_through, soft_locked_through }` with `check(date, has_override)` returning `period.hard_locked` or `period.soft_locked` per LEDGER_SPEC §9;
  - a trial balance fold over (account, base amount) pairs and a balance check;
  - error-code string constants in `ledger::codes` (`store` reuses them for the matching triggers).
- **`posting` (AGPL, pure):**
  - `post(document, revision, ctx) -> Result<Option<PostedEntry>, PostingError>`, where `PostedEntry` holds the `BalancedEntry` and its `rules_version`;
  - `PostingContext`: the accounts the document references (class, subtype, system role), items with their income and expense accounts, tax rates with their agency's liability account, the system accounts by role, and `source_rounding_tolerance: Option<i64>` (set to 2 for imports, LEDGER_SPEC §8.1);
  - shared helpers: line-key construction (§3.5), contact rule (§3.6), dimension propagation with line values winning (§3.7), group lines that do not post (§3.8), zero-amount postings skipped, source rounding residue to the `rounding` account with line key `{doc}:rounding`;
  - the rule registry in `crates/posting/src/rules/mod.rs`, keyed by document type, with every rule in its own file under `src/rules/`; this WP adds `journal_entry@1` (§4.16) and `opening_balance@1` (§4.17); `estimate` returns `None`; every other type returns `posting.rule_missing` until W1-01;
  - error codes in `posting::codes`: `posting.invalid_account`, `posting.invalid_contact`, `posting.rule_missing`, `posting.source_unbalanced`, and the warning `posting.source_rounding_adjusted`;
  - golden snapshots stored under `crates/posting/golden/` (insta `snapshot_path`), so W1-01 can own them.

Out: the other document types' rules (W1-01), storage (W0-04), services.

## Tasks

1. `ledger` types, constructor, reversal, lock check and fold, with property tests.
2. `posting` framework and registry.
3. The journal entry and opening balance rules with golden files.
4. Determinism property test over random journal entries and opening balances.

## Invariants touched

| Invariant | Test |
|---|---|
| I-1 | D-6 lint (no floats); amounts only through `money` |
| I-2 | T-POST-1 (determinism), D-2 lint (no I/O) |
| I-3 | T-LEDGER-1 (constructor), T-LEDGER-2 (reversal) |
| I-5 | `LockState` tests (LEDGER_SPEC §9) |
| I-8 | dimension propagation test |
| I-12 | D-1 lint (`ledger` is MIT) |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | T-LEDGER-1: `BalancedEntry::new` accepts every balanced input and refuses every unbalanced, single-line, zero-line or duplicate-key input with the right code | proptest (at least 1,000 cases) plus one unit test per error code |
| AC-2 | `BalancedEntry` has no other public constructor and no public mutable access | a `compile_fail` doctest that tries to build one with a struct literal; review of the public API in the PR |
| AC-3 | T-LEDGER-2: a reversal cancels its original exactly, line by line | proptest: `entry` plus `entry.reversal()` sums to zero per account, contact, line key and currency |
| AC-4 | `LockState` follows LEDGER_SPEC §9 | tests: a date on or before the hard date fails even with an override; a soft-locked date fails without an override and passes with one; open dates pass |
| AC-5 | Journal entry golden: JE-01 (spine S26) posts Depreciation 100.00 Dr and Accumulated Depreciation 100.00 Cr with `rules_version` `journal_entry@1` | insta snapshot reviewed in the PR |
| AC-6 | Opening balance golden: OB-1 (spine S02) posts Checking 12,500.00 Dr, Savings 20,000.00 Dr, Equipment 6,000.00 Dr, Studio Visa 450.00 Cr and Opening Balance Equity 38,050.00 Cr with line key `{doc}:ob` on the offset | insta snapshot reviewed in the PR |
| AC-7 | A journal entry line to an AR account without a contact is refused | test expects `posting.invalid_contact` |
| AC-8 | Dimensions propagate with line values winning over document values | unit test |
| AC-9 | T-POST-1: posting is deterministic | proptest over 1,000 random journal entries and opening balances: two runs give byte-identical `serde_json` of the result |
| AC-10 | Source rounding: an imported journal entry unbalanced by 2 minor units gets a `{doc}:rounding` line and the warning; by 3 it fails with `posting.source_unbalanced` | unit tests |
| AC-11 | Lints pass: `ledger` depends only on MIT or permissive crates, neither crate does I/O, no floats | `cargo xtask lint` exits 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-ledger -p bookscraft-posting --all-targets -- -D warnings
cargo test --locked -p bookscraft-ledger -p bookscraft-posting
cargo build --locked --workspace
cargo xtask lint
cargo xtask spine
cargo xtask scope W0-05
```

## Deliverables

- Branch: `wp/W0-05-ledger`
- PR title: `W0-05: Ledger core and posting framework`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work (for example a missing field on a `domain` document type).
- A golden number disagrees with LEDGER_SPEC and the spec, not the code, seems wrong: raise a CCR with both computations; never change a spec number in code.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
