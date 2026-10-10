# W0-06: UI framework spike (timeboxed)

## Goal

Prove or disprove, against the eight criteria in ADR-0002, that a Leptos 0.8 client-side WASM app inside a Tauri 2 shell, reaching an in-process axum router through a custom protocol, works for BooksCraft on the owner's Fedora machine, and record the result in `spikes/ui/RESULTS.md` and ADR-0002.

## Wave and concurrency

- Wave 0. Starts when W0-01 is merged and runs beside W0-02, W0-05, W0-04 and W0-03 (no shared paths).
- Agent: `ui-engineer`. The owner runs the hands-on checks on Fedora (GNOME, Wayland, NVIDIA RTX 3060).
- Timebox: at most three working sessions (ADR-0002). Whatever is unproven by then is recorded as failed or not tested.

## Owned paths (may modify) / Read-only paths

May modify:

- `spikes/ui/**` (its own Cargo workspace, with its own `Cargo.lock`; excluded from the root workspace)
- `docs/adr/0002-ui-framework.md` (results, status)
- `docs/coordination/CCR/CCR-W0-06-*.md`, `docs/coordination/handoffs/W0-06.md`

Read-only: everything else. The spike is not product code: nothing under `crates/` may depend on it.

## Read first

1. `CLAUDE.md` and `.claude/agents/ui-engineer.md`.
2. `docs/adr/0002-ui-framework.md` (the eight criteria and the fallback rules).
3. `docs/architecture/ARCHITECTURE.md` §5 (custom protocol details), §9 (`webview::apply_env_fixups`), §10 (UI architecture and the keyboard shortcuts).
4. ADR-0004 (topology), 0019 (pinned versions: use the same versions in the spike), 0025 (Typst preview and printing), 0030 (allowed files: the spike's HTML host page is generated, not committed).
5. `docs/process/PARALLEL_DEV_PLAYBOOK.md` §3.3 (Fedora setup and the NVIDIA note).

## Preconditions

| Precondition | Check |
|---|---|
| W0-01 is merged | `git log origin/main --format=%s \| grep -q '^W0-01: '` |
| ADR-0002 is still proposed | `git show origin/main:docs/adr/0002-ui-framework.md \| grep -q '^status: proposed'` |

## Scope in/out

In, inside `spikes/ui/`:

- `spike-api`: an axum router with `GET /api/v1/ping`, `GET /api/v1/rows` (10,000 generated rows of eight columns), `GET /api/v1/accounts` (500 generated accounts), and static serving of the built UI.
- `spike-ui`: a Leptos 0.8 client-side app with three screens: a virtualized 10,000-row table with keyboard cell navigation (arrows, `Home`, `End`, `PageUp`, `PageDown`); a 20-line invoice form whose account cells use a type-ahead over the 500 accounts; and a print preview showing Typst-rendered SVG pages with a Print button. Every input is labelled; the grid and dialog have ARIA roles; a small overlay shows measured timings (first render, frames per second while scrolling, keystroke-to-render time) from the browser's Performance API.
- `spike-desktop`: a Tauri 2 shell registering `bookscraft://` with `register_asynchronous_uri_scheme_protocol`, converting each request to an `http::Request`, calling the router with `tower::ServiceExt::oneshot`, and returning the buffered response; it opens no TCP port.
- `spike-server`: an axum binary serving the same router and bundle on `127.0.0.1` for a browser.
- `spike-build`: a Rust binary that compiles `spike-ui` for `wasm32-unknown-unknown`, runs `wasm-bindgen-cli-support` (the pinned version, as a library), writes the bundle plus a generated HTML host page into `spikes/ui/dist/` (git-ignored), and prints the SHA-256 of the `.wasm` file. No Trunk, no Node, no downloads at build time.
- `spikes/ui/RESULTS.md`: one row per criterion with pass, fail or not tested, the measurement, the environment (Fedora release, GNOME version, Wayland, NVIDIA driver version) and notes, including whether `WEBKIT_DISABLE_DMABUF_RENDERER=1` was needed.
- ADR-0002: results summarized under "More Information"; `status: accepted` only if all eight criteria pass with the owner's confirmation in the PR; otherwise the status stays `proposed`, and the ADR says which criteria failed and whether the cause is the framework (rerun with Dioxus 0.7) or the webview (escalate to the owner, Slint as native fallback).

Out: any code under `crates/`, any production design or styling, accessibility beyond what criterion 6 needs.

## Tasks

1. Build the spike workspace and `spike-build`; produce the bundle and its hash.
2. `spike-api`, `spike-server` and `spike-desktop`.
3. The three screens with labels, roles and the timing overlay.
4. Automated checks you can run in a cloud session (criteria 1 and 8, task list in the acceptance criteria).
5. Write the owner's check script in `spikes/ui/RESULTS.md`: the exact commands and steps for criteria 2–7 on Fedora, including how to start Orca and how to print.
6. Record the owner's results, update ADR-0002 accordingly.

## Invariants touched

| Invariant | How |
|---|---|
| I-12 | Leptos (MIT) and Tauri (MIT or Apache-2.0) are AGPL-compatible; the spike adds no other license family (checked with `cargo tree` in the PR) |
| I-13 | No `std::process::Command` and no `cfg(target_os)` in the spike (the root lint scans tracked files) |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | Criterion 1: the spike builds with cargo alone | `cargo build --locked --manifest-path spikes/ui/Cargo.toml --workspace` and `cargo run --locked --manifest-path spikes/ui/Cargo.toml -p spike-build` exit 0; no `package.json`, `.js` or `.ts` file is tracked (`cargo xtask lint` passes) |
| AC-2 | Criterion 8 (automated part): the desktop and the server serve the same bundle and both answer `/api/v1/ping` | a test in `spike-desktop` calls the protocol handler function directly (no window) for `/api/v1/ping` and for the `.wasm` file; a test in `spike-server` serves on `127.0.0.1:0`; both return 200 for ping and the same SHA-256 for the bundle |
| AC-3 | The desktop shell opens no listening socket | the protocol path above uses no `TcpListener`; review in the PR shows the only listener is in `spike-server` |
| AC-4 | Criteria 2–7 have a recorded result from the owner's Fedora machine | `spikes/ui/RESULTS.md` has a row for each with pass, fail or not tested, and for 3 and 5 the measured numbers against the thresholds (first screen under 500 ms, at least 50 fps, under 50 ms per keystroke) |
| AC-5 | ADR-0002 states the outcome consistently with RESULTS.md | if every criterion passed, `status: accepted`; otherwise `status: proposed` with the failed criteria, their cause (framework or webview) and the recommended next step |
| AC-6 | Nothing outside the owned paths changed | `cargo xtask scope W0-06` exits 0 |

## Verify

```sh
cargo build --locked --manifest-path spikes/ui/Cargo.toml --workspace
cargo test --locked --manifest-path spikes/ui/Cargo.toml --workspace
cargo run --locked --manifest-path spikes/ui/Cargo.toml -p spike-build
cargo xtask lint
cargo xtask scope W0-06
```

The first build creates `spikes/ui/Cargo.lock` (commit it); every command after that uses `--locked`.

## Deliverables

- Branch: `wp/W0-06-ui-spike`
- PR title: `W0-06: UI framework spike results`
- PR description: the template, a summary table of the eight criteria, and the owner's confirmation of criteria 2–7.

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work.
- A criterion fails because of the framework: finish recording the other criteria, then stop; Weave 0 decides whether to rerun the spike with Dioxus 0.7.
- A criterion fails because of the webview (rendering, accessibility or printing in WebKitGTK): record it and stop; this needs an owner decision.
- A pinned version from ADR-0019 does not work in the spike: record the exact error; do not upgrade product pins.
- The same failure persists after two different fix attempts.
- The timebox is reached: record what is untested and run `/handoff` or open the PR with the partial results.
