# W5-04: End-to-end suite, pilot runbook, release checklist

## Goal

Complete the end-to-end suite (an API flow over real HTTP and a desktop test through `tauri-driver`, beside the existing web UI tests), and write the pilot runbook and the release checklist that the MVP exit is measured with, including the owner's dry run against the QuickBooks Online sandbox company.

## Wave and concurrency

- Wave 5, batch A (with W5-01 and W5-03). Paths do not overlap. W5-03 adds `ui_print_polish.rs` on top of the harness at the same time, so keep every existing harness function and signature; only add.
- Agent: `qa-verifier` in builder mode. In Weave 5 a fresh `qa-verifier` in reviewer mode verifies this PR.
- The owner runs the runbook's sandbox section.
- Timebox: two sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `xtask/src/e2e.rs`, `tests/e2e/src/**`, `tests/e2e/tests/api_*.rs`, `tests/e2e/tests/desktop_*.rs`, `docs/process/PILOT_RUNBOOK.md`, `docs/process/RELEASE_CHECKLIST.md`
- `docs/coordination/CCR/CCR-W5-04-*.md`, `docs/coordination/handoffs/W5-04.md`

Read-only: everything else, including the `ui_*.rs` test files, `.github/workflows/**` and `tests/e2e/Cargo.toml`.

## Read first

1. `CLAUDE.md` and `.claude/agents/qa-verifier.md` (builder mode).
2. `docs/roadmap/ROADMAP.md` §2 (the MVP exit and how it is verified).
3. `docs/architecture/MIGRATION_SPEC.md` §4.1 (access), §6 (validation), §9 (re-runs) and §10 (rollback).
4. `docs/architecture/API.md` §2 (idempotency, concurrency), §5 and §6 (agent rule).
5. `docs/architecture/ARCHITECTURE.md` §5 (topology), §10 (testing row) and §15 (`cargo xtask e2e`).
6. `docs/architecture/LEDGER_SPEC.md` §4.1 and Appendix A (S06 and S14 amounts).
7. `docs/process/PARALLEL_DEV_PLAYBOOK.md` §3.3 and §4.4 (the owner's hands-on checks).
8. The merged `tests/e2e/src/`, `xtask/src/e2e.rs`, the `--smoke-test` flag in `crates/desktop`, and the desktop's company creation screen.

## Preconditions

| Precondition | Check |
|---|---|
| Weave 4 is merged | `git log origin/main --format=%s \| grep -q '^Weave 4: '` |
| The web harness exists | `git show origin/main:tests/e2e/src/lib.rs > /dev/null` |
| tauri-driver is installable | `cargo xtask doctor --tools` reports `tauri-driver 2.1.0` installed |

## Scope in/out

In:

- **`cargo xtask e2e`:** `--web` runs the `ui_*` and `api_*` test targets; `--desktop` builds the UI and the desktop app (release, embedded UI), starts `tauri-driver` with `WebKitWebDriver` (and Xvfb when there is no display), passes the driver URL in `BOOKSCRAFT_WEBDRIVER_URL` and the binary path in `BOOKSCRAFT_DESKTOP_BIN`, and runs the `desktop_*` targets; no flag runs both. The desktop app runs with `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, `XDG_CACHE_HOME` and `XDG_STATE_HOME` pointed at a fresh temporary directory, so the owner's real company files are never touched.
- **Harness additions** in `tests/e2e/src/`: an in-process server on `127.0.0.1:0` in server mode, a `reqwest` client with session and bearer helpers, and a desktop session helper for `tauri-driver`.
- **`tests/e2e/tests/api_flow.rs`**, over real HTTP: install and log in as the owner; create a company from the agency template; create a customer and items; save and post INV-1002 (total 5,097.70); record the 2,500.00 payment; AR aging shows 2,597.70 open; an agent token creates a draft, its post is refused with 403 `auth.agent_forbidden`, the owner approves it; an idempotent create replayed returns `Idempotent-Replayed: true`; a stale `If-Match` returns 412; the trial balance as CSV balances; an export job completes and its bundle validates.
- **`tests/e2e/tests/desktop_smoke.rs`**, through `tauri-driver`: the app starts; by keyboard, create a company (in the temporary data directory, no file dialog), add a customer, open the trial balance.
- **`docs/process/PILOT_RUNBOOK.md`**, the owner's procedure for the MVP exit: prerequisites (an Intuit developer app, the sandbox company, a QuickBooks export kept as a backup); installing BooksCraft on Fedora; the sandbox dry run (import, the validation report, residual acknowledgement, rollback practice); the production import (full history; cut-over mode is v1); recording one real month (bank import and review, reconciliation, invoices, bills); soft-locking it; comparing BooksCraft's month-end trial balance with QuickBooks's for the same date to the cent (both exported as CSV, with the comparison recorded); what to do if anything differs; privacy (real data stays on the owner's machine and never goes into the repository, issues or chats; the production evidence is a summary only: the date, the number of accounts compared and the count of differences, never balances or names).
- **`docs/process/RELEASE_CHECKLIST.md`:** every item of ROADMAP §2 step 4 and of the Weave checklist (00-INDEX), each with the command or evidence that proves it and a field for the link.

Out: CI workflow changes (Weave 5 decides whether the end-to-end jobs become required), UI test files (their owners), new product features.

## Tasks

1. `xtask/src/e2e.rs`: target selection, the desktop mode, the isolated environment; unit tests.
2. Harness additions, keeping the existing API.
3. `api_flow.rs` and `desktop_smoke.rs`.
4. The pilot runbook and the release checklist.
5. The owner's sandbox dry run, with its evidence in the PR.

## Invariants touched

| Invariant | Test |
|---|---|
| I-10 | `api_flow.rs`: the agent's draft cannot be posted over HTTP; the owner's approval posts it |
| I-1 | `api_flow.rs`: INV-1002 is 5,097.70 and 2,597.70 stays open after the payment, compared as decimal strings |
| I-13 | tests start no processes (`xtask` does, D-5) and use temporary directories only |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | The web and API suites pass | `cargo xtask e2e --web` passes every `ui_*` and `api_*` file, including `api_flow.rs` with each assertion listed in the scope |
| AC-2 | The desktop suite passes | `cargo xtask e2e --desktop` passes `desktop_smoke.rs` (output in the PR) |
| AC-3 | The desktop app cannot touch real data | `xtask` unit test: the environment built for the app sets the four XDG variables to paths inside a new temporary directory and none of them under the real home directory |
| AC-4 | Target selection is right | `xtask` unit tests: `--web` selects `ui_*` and `api_*`, `--desktop` selects `desktop_*`, no flag selects both |
| AC-5 | The runbook is complete and usable | the owner runs its sandbox section; the PR attaches the evidence: validation passed for every imported month, agings equal per contact, residuals listed and acknowledged, a rollback practised, and the trial balance comparison CSV with zero differences |
| AC-6 | The release checklist covers the exit | the checklist opens with a table mapping each item of ROADMAP §2 step 4 and each of the eight Weave checklist items to a checklist line with its proof; the reviewing qa-verifier fails the PR if any item is unmapped |
| AC-7 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W5-04` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p xtask -p bookscraft-e2e --all-targets -- -D warnings
cargo test --locked -p xtask
cargo xtask e2e --web
cargo xtask e2e --desktop
cargo xtask lint
cargo xtask scope W5-04
```

## Deliverables

- Branch: `wp/W5-04-e2e-pilot`
- PR title: `W5-04: End-to-end suite, pilot runbook and release checklist`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work (a workflow, a UI test file, a dependency).
- `tauri-driver` or WebKitWebDriver cannot run in this environment: record the exact error, keep the code, ask the owner to run `cargo xtask e2e --desktop` on Fedora and attach the output.
- Any step of the pilot would put real company data into the repository, an issue or a chat: stop and rewrite that step.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
