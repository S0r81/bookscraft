# W4-01: UI: reports, close, audit, migration wizard

## Goal

Build the report screens (`pages/reports/`), closing the books (`pages/close/`), the audit log viewer (`pages/audit/`) and the migration wizard (`pages/migrate/`), with an end-to-end test that runs a report, sets a lock and imports a CSV list.

## Wave and concurrency

- Wave 4, batch B (with W4-02). Paths do not overlap.
- Agent: `ui-engineer`.
- Timebox: two sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/ui/src/pages/reports/**`, `crates/ui/src/pages/close/**`, `crates/ui/src/pages/audit/**`, `crates/ui/src/pages/migrate/**`, `tests/e2e/tests/ui_reports_close.rs`
- `docs/coordination/CCR/CCR-W4-01-*.md`, `docs/coordination/handoffs/W4-01.md`

Read-only: everything else, including the shared UI modules and the e2e harness.

## Read first

1. `CLAUDE.md` and `.claude/agents/ui-engineer.md`.
2. `docs/architecture/ARCHITECTURE.md` §10 and §11 ("Close the books", "Sales tax owed").
3. `docs/architecture/API.md` §5.2 (period locks), §5.6 (reports and audit events), §5.7 (imports, QBO connect and token).
4. `docs/architecture/LEDGER_SPEC.md` §9 and §12; `docs/architecture/MIGRATION_SPEC.md` §4.1, §6, §7.
5. The merged `crates/ui` and `tests/e2e/src/`.

## Preconditions

| Precondition | Check |
|---|---|
| Weave 3 is merged | `git log origin/main --format=%s \| grep -q '^Weave 3: '` |
| The report and migration routes are registered in the UI | `git show origin/main:crates/ui/src/routes.rs \| grep -q 'reports/trial-balance'` |

## Scope in/out

In:

- **Reports:** trial balance, profit and loss, balance sheet, general ledger, journal, AR aging, AP aging and sales tax owed; date or period parameters, accrual or cash basis, tag (dimension) filters, grouping and comparison where the API offers them; drill-down from a balance to the general ledger and to the document; CSV download; residual journal entries visibly flagged.
- **Close the books:** current soft and hard lock dates, setting them with a reason, the owner-only action to move the hard date earlier, and an explanation of what each lock does.
- **Audit log:** filters (time, actor type, entity, action), event detail with before and after, and the result of `verify` (start a verify job and show its report).
- **Migration wizard:** choose a source (QuickBooks Online, CSV or XLSX lists, an interchange bundle); for QuickBooks Online, the server-mode connect button or the desktop paste form for realm id and tokens, plus the request-count estimate; for CSV and XLSX, upload, a mapping step previewing the first 50 rows, and saved mappings; progress by polling the job; the validation report (months, agings, residuals) with an explicit acknowledgment of residuals; rollback with a reason.
- **`tests/e2e/tests/ui_reports_close.rs`:** by keyboard only, run the trial balance and download its CSV, set a soft lock with a reason, and import a contacts CSV through the wizard.

Out: report builder and dashboards (v1), printing reports (W5-03), new shared components (CCR).

## Tasks

1. Report screens with parameters, drill-down and CSV.
2. Close the books.
3. Audit log and verify.
4. Migration wizard.
5. Native tests and the end-to-end test.

## Invariants touched

| Invariant | How |
|---|---|
| I-4 | the basis switch only changes the API parameter; no client-side recomputation (review and a native test of the request builder) |
| I-5 | lock changes require a reason; the hard-unlock action appears only for the owner |
| I-6 | the audit log is read-only in the UI |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | The keyboard-only flow works | `cargo xtask e2e --web` passes `ui_reports_close.rs` |
| AC-2 | Report parameters reach the API unchanged | native tests of the request builder (basis, dates, dimension filters, grouping, comparison, `Accept: text/csv`) |
| AC-3 | Lock rules show in the UI | native tests: an empty or short reason blocks saving; the hard-unlock action is hidden for non-owners |
| AC-4 | The wizard handles every outcome | native tests of the wizard state machine: success, success with residuals (acknowledgment required), parity failure, rollback |
| AC-5 | Every report, close, audit and migrate route in ARCHITECTURE §10.2 renders a real screen | native test over the components named in `routes.rs` |
| AC-6 | Accessibility basics hold | the e2e test checks accessible names on inputs and table headers on the report tables |
| AC-7 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W4-01` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-ui --all-targets -- -D warnings
cargo check --locked -p bookscraft-ui --target wasm32-unknown-unknown
cargo test --locked -p bookscraft-ui
cargo xtask ui build
cargo xtask e2e --web
cargo xtask lint
cargo xtask scope W4-01
```

## Deliverables

- Branch: `wp/W4-01-ui-reports-close`
- PR title: `W4-01: Reports, close, audit and migration screens`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work.
- The API lacks something a screen needs: raise a CCR naming the endpoint and fields.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
