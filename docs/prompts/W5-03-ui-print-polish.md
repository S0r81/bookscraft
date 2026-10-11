# W5-03: UI: print, email, polish, accessibility pass

## Goal

Add print preview, printing, PDF download and email sending to the sales document screens, printing to the report screens and the email settings form, and finish the UI with an accessibility and consistency pass across every screen, proven by a keyboard-only end-to-end test and a contrast test of the design tokens.

## Wave and concurrency

- Wave 5, batch A (with W5-01 and W5-04). Paths do not overlap; W5-04 owns the end-to-end harness, which this WP uses as it is.
- Agent: `ui-engineer`. The owner checks the screens with Orca on Fedora.
- Timebox: two sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/ui/src/components/**`, `crates/ui/src/shell/**`, `crates/ui/src/pages/**`, `crates/ui/tests/**`, `crates/ui/style/**`, `tests/e2e/tests/ui_print_polish.rs`
- `docs/coordination/CCR/CCR-W5-03-*.md`, `docs/coordination/handoffs/W5-03.md`

Read-only: everything else, including `crates/ui/src/lib.rs`, `crates/ui/src/routes.rs`, `crates/ui/src/api/**` (use its generic request functions), `crates/ui/index.html` and `tests/e2e/src/**`.

## Read first

1. `CLAUDE.md` and `.claude/agents/ui-engineer.md`.
2. `docs/architecture/ARCHITECTURE.md` §10 (print and PDF, accessibility, testing), §10.1 (`Ctrl+P`), §11 (own wording).
3. `docs/architecture/API.md` §5.1 (jobs, email settings), §5.4 (`pdf`, `preview`, `send`) and §4 (`render.not_sendable`, `render.smtp_failed`).
4. ADR-0025 (print through the webview dialog).
5. WCAG 2.2 success criteria 1.4.3 (text contrast 4.5:1) and 1.4.11 (non-text contrast 3:1).
6. The merged `crates/ui` and `tests/e2e/src/`.

## Preconditions

| Precondition | Check |
|---|---|
| Weave 4 is merged | `git log origin/main --format=%s \| grep -q '^Weave 4: '` |
| Rendering is registered | `git grep -q 'Capability::RenderPdf' origin/main -- crates/render/src` |

## Scope in/out

In:

- **`pages/sales/print.rs`**, used by every sales document screen: Preview (the `PrintPreview` component showing the SVG pages from `/documents/{id}/preview`), Print (the webview's print dialog through `web-sys`, on a print stylesheet that shows only the preview pages), Save as PDF (a download of `/documents/{id}/pdf`), and Email (a dialog with to, cc, subject and message; validates addresses; sends; shows the job's status by polling `/jobs/{id}`; explains `render.not_sendable` for drafts and voided documents). `Ctrl+P` opens the preview on a document screen.
- **`pages/settings/email.rs`:** the installation's email settings form, replacing W2-05's placeholder in the same file and keeping the component name `routes.rs` uses: `email.get` and `email.set` (host, port, username, password, from address, TLS; the password is write-only, API.md §5.1) and a test email through `email.test` showing the job's status. Shown to principals with `installation.manage`; others see an explanation instead.
- **Reports:** a Print action on every report screen, using the print stylesheet (no report PDF endpoint, ARCHITECTURE §10).
- **Accessibility pass** over every screen: every input labelled, dialogs with `role="dialog"`, `aria-modal`, focus moved in and trapped, `Esc` to close and focus returned; table headers and grid roles; visible focus; toasts in the live region; reading-order tab sequence; design tokens meeting 4.5:1 for text and 3:1 for focus indicators and control borders.
- **Consistency pass:** every list page has an empty state, a loading state and an error state with BooksCraft's own wording; a shortcuts dialog listing ARCHITECTURE §10.1, opened from the command palette.
- **`tests/e2e/tests/ui_print_polish.rs`.**

Out: report PDFs, new API endpoints or client modules (CCR), routes (fixed in W2-05), harness changes (W5-04; a missing helper is written inside this WP's test file).

## Tasks

1. Print, PDF and email actions in `pages/sales/print.rs`, wired into the sales document screens; the email settings form.
2. Print on report screens; the print stylesheet.
3. Accessibility pass, screen by screen; token contrast test.
4. Empty, loading and error states; the shortcuts dialog.
5. End-to-end test; owner's Orca checklist in the PR.

## Invariants touched

| Invariant | How |
|---|---|
| I-1 | amounts on screen and in previews come from the API's decimal strings; nothing is recomputed in the UI (review and the existing `MoneyInput` tests) |
| I-10 | an agent's draft can be previewed but not emailed until a person approves and posts it (`render.not_sendable`; AC-2) |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | Print, PDF and email work by keyboard | `cargo xtask e2e --web` passes `ui_print_polish.rs`: open a posted invoice, `Ctrl+P` shows at least one SVG page, the Save as PDF link's URL answers `application/pdf`, the email dialog rejects a malformed address, then sends and shows the queued job |
| AC-2 | Drafts and voided documents explain why they cannot be sent | native test of the email dialog's state machine: `render.not_sendable` shows the explanation; success shows queued, then sent or failed from the job status |
| AC-3 | Token contrast meets WCAG | native test parses the design tokens in `crates/ui/style/` and asserts 4.5:1 for every text and background pair and 3:1 for focus indicators and control borders |
| AC-4 | Dialogs are accessible | the e2e test checks, for the email dialog and the payment dialog: `role="dialog"` and `aria-modal="true"`, focus inside on open, `Tab` cycling inside, `Esc` closing and returning focus |
| AC-5 | Inputs have accessible names | the e2e test checks every input on the invoice form and the email dialog for an accessible name |
| AC-6 | Report screens print | the e2e test finds a keyboard-reachable Print action on the trial balance; a native test checks that the print stylesheet hides the navigation and the app shell |
| AC-7 | No UI regression | `cargo xtask e2e --web` passes every `ui_*.rs` file |
| AC-8 | Owner checks with Orca | the PR records the owner's Orca pass on Fedora over the invoice form, the preview and the email dialog |
| AC-9 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W5-03` exit 0 |
| AC-10 | The email settings form keeps the password write-only | native test of the form state: the password field is never filled from `email.get`; saving with the field left empty omits `password` from `email.set`; a test email shows queued, then sent or failed from the job status |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-ui --all-targets -- -D warnings
cargo check --locked -p bookscraft-ui --target wasm32-unknown-unknown
cargo test --locked -p bookscraft-ui
cargo xtask ui build
cargo xtask e2e --web
cargo xtask lint
cargo xtask scope W5-03
```

## Deliverables

- Branch: `wp/W5-03-ui-print-polish`
- PR title: `W5-03: Print, PDF, email and accessibility pass`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work (a route, the API client, the harness, an endpoint).
- A screen cannot meet the contrast or focus rules without changing a shared token another screen depends on in a way you cannot test: raise a CCR with the proposed token values.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
