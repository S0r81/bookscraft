# W2-05: UI foundation, books, settings and session screens

## Goal

Build the UI foundation in `crates/ui` (the WASM build through `cargo xtask ui`, the app shell with keyboard shortcuts and command palette, every MVP route pre-registered, the typed API client, the design system components) plus the home, books, settings and session screens, and the web end-to-end harness (`cargo xtask e2e --web`).

## Wave and concurrency

- Wave 2, batch B (with W2-04). Paths do not overlap.
- Agent: `ui-engineer`. The owner checks the screens with Orca on Fedora before the Weave.
- Timebox: three sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/ui/src/**`, `crates/ui/tests/**`, `crates/ui/index.html`, `crates/ui/style/**`, `crates/ui/assets/**`
- `xtask/src/ui.rs`, `xtask/src/e2e.rs`
- `tests/e2e/src/**`, `tests/e2e/tests/ui_foundation.rs`
- `docs/coordination/CCR/CCR-W2-05-*.md`, `docs/coordination/handoffs/W2-05.md`

Read-only: everything else. After this WP, `crates/ui/src/lib.rs` and `crates/ui/src/routes.rs` change only in Weaves, and each `pages/<area>/` directory belongs to its area's work package.

## Read first

1. `CLAUDE.md` and `.claude/agents/ui-engineer.md`.
2. `docs/adr/0002-ui-framework.md` and `spikes/ui/RESULTS.md` (what the spike proved and measured).
3. `docs/architecture/ARCHITECTURE.md` §1 (principle 5), §5 (desktop and browser origins), §10 (UI architecture, shortcuts, routes and page ownership, testing), §11 (terminology).
4. `docs/architecture/API.md` §2, §5.1–§5.4, §6, §7.
5. ADR-0025 (print preview) and ADR-0030 (allowed files).

## Preconditions

| Precondition | Check |
|---|---|
| Weave 1 is merged | `git log origin/main --format=%s \| grep -q '^Weave 1: '` |
| ADR-0002 is accepted with Leptos | `git show origin/main:docs/adr/0002-ui-framework.md \| grep -q '^status: accepted'` |

## Scope in/out

In:

- **Build:** `cargo xtask ui build` compiles `bookscraft-ui` for `wasm32-unknown-unknown` (release profile), runs `wasm-bindgen-cli-support`, and copies `index.html`, `style/` and `assets/` into `target/ui-dist/`, printing the bundle size; `cargo xtask ui serve` serves `target/ui-dist/` and forwards `/api` to a running `bookscraft serve` (or the address in `BOOKSCRAFT_API`).
- **Module layout:** `lib.rs` (mounts the app), `routes.rs` (every route in ARCHITECTURE §10.2, pointing at fixed component names), `api/` (client), `components/` (design system), `shell/` (layout, navigation, command palette, shortcuts), `pages/<area>/` for each area. Areas owned by later work packages get a placeholder page exporting the fixed component name and saying the screen is coming; no test asserts a placeholder's content, because later work packages replace the placeholders.
- **API client:** relative `/api/v1` URLs over `gloo-net`, typed with `api-types`; `Idempotency-Key` on creates; `If-Match` on updates; problem details turned into field errors; a 412 shows a reload prompt; session login in server mode, the desktop principal otherwise.
- **Shell:** navigation, company switcher, command palette (`Ctrl+K`), and the shortcuts of ARCHITECTURE §10.1; visible focus; toasts in a live region.
- **Components:** `DataTable` (virtualized rows, keyboard cell navigation, sortable columns), `MoneyInput` (decimal strings, never floats), `DateInput`, `ComboBox` (type-ahead), `LineItemsGrid` (live totals with `money::calc`), `Dialog`, `Toast`, `FormField` (label, description, error), `PrintPreview` (shows SVG pages from an API response).
- **Screens:** `pages/home` (home with to-do counts, approvals list), `pages/books` (contacts, items, accounts, journal entries, opening balances), `pages/settings` (company, users, tokens, taxes, terms, payment methods; dimensions and custom fields read-only, since their management UI is v1; and, because the email settings API arrives with W4-04, a placeholder page in `pages/settings/email.rs` whose component `routes.rs` names and W5-03 later fills with the form, keeping that name), `pages/session` (login, company list and creation).
- **End-to-end harness:** `cargo xtask e2e --web` builds the UI, starts WebKitWebDriver (and Xvfb when there is no display), then runs `cargo test --locked -p bookscraft-e2e`; the harness in `tests/e2e/src/` starts an in-process server (router plus `app::compose` on a temporary company), connects `fantoccini` to the driver URL that `xtask` passes in `BOOKSCRAFT_WEBDRIVER_URL` (without it, the harness fails with "run through cargo xtask e2e"), and offers keyboard helpers. The test process starts no processes itself (D-5). The normal test run excludes this crate (`cargo xtask ci`).
- **`tests/e2e/tests/ui_foundation.rs`:** by keyboard only, create a company, then a customer and an account, and find them through the command palette.

Out: sales, purchases, banking, reports, close, audit and migration screens (Waves 3–4), printing, email actions and the email settings form (W5-03), desktop shell (W3-05).

## Tasks

1. `xtask ui` build and serve.
2. App skeleton, routes, API client, shell.
3. Components with native tests of their view-model logic.
4. Home, books, settings and session screens.
5. `xtask e2e` and the harness; `ui_foundation.rs`.
6. Owner check list for Orca in the PR description.

## Invariants touched

| Invariant | How |
|---|---|
| I-1 | money shown and entered as decimal strings through `money`; no floats (review and a test of `MoneyInput` parsing) |
| I-13 | the UI runs in the desktop webview and in browsers from one bundle with relative URLs |
| — | D-3: `ui` depends only on `api-types` and `money` among workspace crates (lint) |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | The UI builds with cargo alone | `cargo xtask ui build` exits 0 and prints the bundle size; no JavaScript is tracked (`cargo xtask lint`) |
| AC-2 | Every route of ARCHITECTURE §10.2 is registered | a native test lists `routes.rs` entries and compares them with the table (paths and component names) |
| AC-3 | View-model logic is tested natively | `cargo test --locked -p bookscraft-ui` passes, covering money input parsing, keyboard maps, form validation and table navigation state |
| AC-4 | The keyboard-only flow works in the web build | `cargo xtask e2e --web` passes `ui_foundation.rs` |
| AC-5 | API errors reach the user | tests of the client's problem-details mapping: field errors attach to fields; 412 triggers the reload prompt |
| AC-6 | Accessibility basics hold | the e2e test checks that every input on the tested screens has an accessible name and that dialogs have `role="dialog"`; the owner's Orca check (labels, roles, table headers) is recorded in the PR |
| AC-7 | The performance budget from the spike holds | the PR reports first-render and keystroke timings for the accounts table and contact type-ahead from the spike's overlay method, within ADR-0002's thresholds |
| AC-8 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W2-05` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-ui --all-targets -- -D warnings
cargo check --locked -p bookscraft-ui --target wasm32-unknown-unknown
cargo test --locked -p bookscraft-ui
cargo xtask ui build
cargo xtask e2e --web
cargo xtask lint
cargo xtask scope W2-05
```

## Deliverables

- Branch: `wp/W2-05-ui-foundation`
- PR title: `W2-05: UI foundation, books, settings and session screens`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work.
- ADR-0002 is not accepted, or names a framework other than Leptos: stop; Weave 0 must rewrite this prompt.
- WebKitWebDriver cannot run in CI or the cloud environment: record the exact error, keep the harness, mark `ui_foundation.rs` as ignored with the reason, and raise a CCR for Weave 2.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
