# W0-03: Test harness and scenario spine

## Goal

Build the shared test harness (`crates/test-support`) and the capability-gated scenario spine (`tests/scenarios`): all 31 Copperline Studio steps with expected results transcribed from LEDGER_SPEC Appendix A, running in order and reporting passed, failed and pending.

## Wave and concurrency

- Wave 0, order 5 (last before Weave 0 closes). Starts when W0-04 is merged. W0-06 may still be running.
- Agent: `qa-verifier`, in builder mode.
- Timebox: two sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/test-support/**`, `tests/scenarios/**`, `Cargo.lock`
- `docs/coordination/CCR/CCR-W0-03-*.md`, `docs/coordination/handoffs/W0-03.md`

Read-only: everything else. After this WP, only QA work packages and Weaves change these paths (OWNERSHIP.md).

## Read first

1. `CLAUDE.md` and `.claude/agents/qa-verifier.md`.
2. `docs/architecture/LEDGER_SPEC.md` §13 and Appendix A in full.
3. `docs/adr/0029-scenario-spine.md`.
4. `docs/architecture/DATA_MODEL.md` §6 and `docs/architecture/API.md` §6 (the agent rule).
5. `docs/architecture/ARCHITECTURE.md` §4 (ports, capabilities, `app::compose`) and §4.6.
6. `crates/store`, `crates/domain` and `crates/app` as merged (public APIs and docs).

## Preconditions

| Precondition | Check |
|---|---|
| W0-04 is merged | `git log origin/main --format=%s \| grep -q '^W0-04: '` |
| The spine binary stub exists | `cargo run --locked -q -p bookscraft-scenarios --bin spine \| grep -q '^SPINE-JSON '` |

## Scope in/out

In:

- **`test-support`** (dev-only; depends on `domain`, `store`, `ledger`, `posting`, `money`, never on `app`):
  - `FixedClock` and `SeqIds` (deterministic UUIDv7-shaped ids);
  - fakes: `FakeSecretStore`, `RecordingMailer`, a fixed-rate `TaxRateProvider`, and no bank providers;
  - `World`: a temporary directory with `Stores` and `Infra` built from the fakes;
  - principals: an owner user, a bookkeeper, a viewer, an `api` token principal and an `agent` token principal;
  - builders for the domain commands the spine needs (accounts, contacts, documents with lines, applications);
  - `assert_audited(store, since_seq, expected)` checking actor type, `via` and action of the events appended since a sequence number (T-AUDIT-1);
  - insta settings with redactions for ids and timestamps; proptest strategies for amounts, dates and document sequences.
- **`tests/scenarios`:**
  - the 31 steps of Appendix A, each declaring its capabilities, driving the services through `app::compose` (no HTTP);
  - steps run in order; the first step whose capabilities are not all registered, and every step after it, report `pending` (ADR-0029);
  - `SpineRun::with(services, capabilities)` to run against any `Services` (for example the stubs) with a forced capability set, for tests;
  - S01 creates, by name, every account listed in Appendix A that the `agency` template does not already contain, with the class and subtype given there;
  - expected results written as literal Rust tables transcribed from Appendix A (trial balance, profit and loss on both bases, balance sheet on both bases, AR and AP aging, sales tax liability, reconciliation) and the negative expectations;
  - the S27 statement fixture `tests/scenarios/fixtures/checking-2026-03.ofx`, hand-written OFX 1.0.2 (SGML) with the nine transactions and FITIDs `CL-0001`..`CL-0009` of Appendix A and a ledger balance of 17,835.00;
  - `scenarios::copperline::build(&World)`, a library function that runs S01–S31 and returns the company, for other crates' integration tests (T-MIG-3 in W3-04);
  - the T-PROP-1 property harness (random sequences of documents, edits and voids through the services, checking the trial balance and the balance sheet), gated by the same capabilities;
  - the `spine` binary's output: one line per step, then `SPINE-JSON {...}` as specified in W0-01.

Out: implementing any service (steps stay pending), changing a golden number (they come from the spec).

## Tasks

1. `test-support`.
2. The spine runner, gating and output.
3. The 31 steps against the port traits.
4. The golden tables and the OFX fixture.
5. `copperline::build` and the T-PROP-1 harness.

## Invariants touched

| Invariant | Test |
|---|---|
| I-3 | T-PROP-1 harness (active once Wave 2 registers the document capabilities) |
| I-4 | T-SPINE-CASH (cash-basis P&L of Appendix A) |
| I-5 | spine S30 |
| I-6 | T-AUDIT-1 (`assert_audited`) |
| I-7 | spine S27 (re-import inserts nothing) |
| I-10 | spine S28 (agent draft, refused post, owner approval) |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | All 31 steps exist and are pending with today's capabilities | `cargo xtask spine` prints `spine: 0 passed, 0 failed, 31 pending` and exits 0 |
| AC-2 | A capability registered before its feature works fails the spine | test: a run against `domain::ports::stubs::Unimplemented` for every service, with the capabilities forced to {Company, Accounts, Contacts, Tax, Dimensions}, reports S01 failed with `api.not_implemented`, S02–S31 pending, and a failing status (the stubs never change, so this test stays valid as services are implemented) |
| AC-3 | The transcribed goldens are internally consistent | tests: trial balance debits and credits both 52,181.10; net income 9,751.60 accrual and 7,185.85 cash; assets equal liabilities plus equity on both bases (49,832.70 and 47,235.00); AR aging total 2,597.70; sales tax base 760.00 with 47.50 and 15.20 |
| AC-4 | The OFX fixture matches Appendix A | test (a simple line scanner, not the `ofx` crate): nine `STMTTRN` blocks, FITIDs `CL-0001`..`CL-0009`, amounts as listed, sum 5,335.00, ledger balance 17,835.00 |
| AC-5 | `assert_audited` detects missing and wrong audit events | tests with a store from `World`: passes when the expected event was appended; fails on a wrong actor type, a wrong `via`, and a missing event |
| AC-6 | The harness is deterministic | tests: `FixedClock` and `SeqIds` produce the same sequence on every run |
| AC-7 | T-PROP-1 is gated like the spine | the T-PROP-1 test prints `T-PROP-1 pending: missing <capabilities>` and passes when its capabilities are missing, and fails when run against the stubs with its capabilities forced |
| AC-8 | `test-support` does not depend on `app` | `cargo tree --locked -p bookscraft-test-support -e normal \| grep -c bookscraft-app` prints `0` |
| AC-9 | Lints pass | `cargo xtask lint` exits 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-test-support -p bookscraft-scenarios --all-targets -- -D warnings
cargo test --locked -p bookscraft-test-support -p bookscraft-scenarios
cargo xtask spine
cargo xtask lint
cargo xtask scope W0-03
```

## Deliverables

- Branch: `wp/W0-03-spine`
- PR title: `W0-03: Test harness and scenario spine`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work (for example a port method a step needs is missing from `domain`).
- Appendix A is ambiguous or internally inconsistent: raise a CCR quoting the lines; do not guess a number.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
