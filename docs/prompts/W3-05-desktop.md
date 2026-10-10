# W3-05: Platform services and desktop shell

## Goal

Complete `crates/platform` (keychain secrets, URL opening through portals and OS APIs, webview fixes, file permissions, network-path detection) and build the Tauri 2 desktop app in `crates/desktop`, serving the embedded UI and the in-process API through the `bookscraft://` custom protocol with no network listener.

## Wave and concurrency

- Wave 3, batch A (with W3-03 and W3-04). Paths do not overlap.
- Agent: `platform-release-engineer`. A `security-reviewer` pass is required in Weave 3. The owner checks the app on Fedora.
- Timebox: three sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/platform/src/**`, `crates/platform/tests/**`
- `crates/desktop/src/**`, `crates/desktop/tests/**`, `crates/desktop/build.rs`, `crates/desktop/tauri.conf.json`, `crates/desktop/capabilities/**`, `crates/desktop/icons/**`
- `docs/coordination/CCR/CCR-W3-05-*.md`, `docs/coordination/handoffs/W3-05.md`

Read-only: everything else, including both crates' `Cargo.toml` (dependencies are fixed) and `crates/api` (use `api::router` and the `embed-ui` feature).

## Read first

1. `CLAUDE.md` and `.claude/agents/platform-release-engineer.md`.
2. `docs/architecture/ARCHITECTURE.md` §5 (topology and custom protocol details), §9 (platform table and rules), §13 (desktop security), §14 (logs).
3. `docs/architecture/DATA_MODEL.md` §2 (files, lock, network paths).
4. ADR-0004, 0018 (credentials), 0020, 0023 (desktop principal, app password), 0026.
5. `spikes/ui/RESULTS.md` (the custom protocol pattern and the NVIDIA finding).
6. `docs/process/PARALLEL_DEV_PLAYBOOK.md` §3.3 (Fedora notes).

## Preconditions

| Precondition | Check |
|---|---|
| Weave 2 is merged | `git log origin/main --format=%s \| grep -q '^Weave 2: '` |
| The UI builds | `cargo xtask ui build` succeeds on `origin/main` |

## Scope in/out

In:

- **`platform`:** `secrets::Keychain` implementing `SecretStore` through `keyring`, with service name `io.github.s0r81.bookscraft` (ADR-0026); `open::open_uri` (XDG Desktop Portal OpenURI through `ashpd` on Linux, `ShellExecuteW` on Windows, `NSWorkspace` on macOS; when no portal answers, return an error that lets the UI show the URL to copy); `webview::apply_env_fixups` (sets `WEBKIT_DISABLE_DMABUF_RENDERER=1` when NVIDIA and Wayland are both detected and the user has not set it, per the spike); `fs::restrict_permissions` (owner-only where the OS supports it); `fs::is_probably_network_path`; `net::listening_sockets()` listing the current process's listening TCP sockets, for tests (Linux reads `/proc/self/net/tcp` and `tcp6` and the process's socket inodes; other OSes return `None`, unsupported, and the AC-2 test then skips with a notice).
- **`desktop`:** `build.rs` with `tauri-build`; `tauri.conf.json` (identifier `io.github.s0r81.bookscraft`, ADR-0026) and `capabilities/` granting only what the app uses (file dialogs); the `bookscraft` custom protocol handler converting each request to an `http::Request`, calling `api::router` with `tower::ServiceExt::oneshot`, and returning the buffered response (`http://bookscraft.localhost` on Windows); the UI embedded from `target/ui-dist` through `api`'s `embed-ui` feature in release builds (read from disk in debug builds); the system file and the desktop principal (OS user); an optional app password gating the UI at start, which is the desktop user's password in `identity` (set with `users.set_password`, checked through `IdentityService` login; no password set means no gate); the company picker (`tauri-plugin-dialog`), recent companies, a clear message for `store.company_locked` naming the holder and for files on network paths; the job runner; logs through `tracing-appender` in `platform::dirs::log_dir()`, rotated daily with 7 files; daily automatic backups (at start and then hourly, a `backup` job for each open company whose newest automatic copy is older than 24 hours; the store keeps the 7 newest automatic copies, DATA_MODEL §2); `Infra` from `app::infra` with `platform::secrets::Keychain` as the secret store (ARCHITECTURE §4.5).
- **Smoke flag:** `bookscraft-desktop --smoke-test` opens the window on a temporary system file and company, loads the UI through the custom protocol, has the page fetch `/api/v1/health`, prints `SMOKE-OK <version>` and exits 0, or exits 1 after 60 seconds. W5-01's package checks and W5-04's desktop tests use it.
- **Icons:** original, simple BooksCraft icons in the formats Tauri needs (generate the set with `cargo tauri icon` from an original image; tauri-cli 2.12.0 through `cargo xtask doctor --tools`). Nothing resembling another product's icon.

Out: packaging and release (W5-01), signing and updates (M-WM), a local socket for CLI and MCP (v1).

## Tasks

1. `platform` functions with tests on all three OSes.
2. Desktop shell: protocol handler, embedded UI, principal and app password.
3. Company picker, lock and network-path messages, job runner, logs.
4. Icons.
5. Owner check list in the PR.

## Invariants touched

| Invariant | Test |
|---|---|
| I-13 | platform tests run on Linux, Windows and macOS in CI; no `cfg(target_os)` outside `crates/platform` and no `std::process::Command` outside `xtask` (lint) |
| I-6 | the desktop principal's actions are audited with actor type `user` and `via = ui` (test through the handler) |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | The protocol handler serves the API and the UI | test: calling the handler function (no window) for `/api/v1/health` returns 200 with the capability list, and for `/` returns `index.html` |
| AC-2 | The desktop app opens no listening socket | test: after building the app state and serving requests through the handler, `platform::net::listening_sockets()` is empty |
| AC-3 | Platform functions work on each OS | `cargo test --locked -p bookscraft-platform` passes in CI on all three OSes (directories, permissions, network-path detection with temporary paths) |
| AC-4 | The webview fix follows its rule | unit test of the decision function: NVIDIA plus Wayland and no user setting gives the variable; any other combination does not |
| AC-5 | Keychain round trip | test gated by `BOOKSCRAFT_KEYCHAIN_TESTS=1` (CI has no Secret Service) passes on the owner's Fedora machine; the PR records the run |
| AC-6 | Owner checks on Fedora | the PR records: the app opens and renders (with and without the fix), a URL opens through the portal, a locked company shows the holder, the app password gate works |
| AC-7 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W3-05` exit 0 |
| AC-8 | The smoke flag works without a real display | `xvfb-run -a target/release/bookscraft-desktop --smoke-test` prints `SMOKE-OK` and exits 0 (output in the PR) |
| AC-9 | Automatic backups are scheduled daily | unit test of the scheduling decision: no automatic copy, or one older than 24 hours, enqueues a backup; a copy 23 hours old does not |

## Verify

```sh
cargo fmt --all -- --check
cargo xtask ui build
cargo clippy --locked -p bookscraft-platform -p bookscraft-desktop --all-targets -- -D warnings
cargo test --locked -p bookscraft-platform -p bookscraft-desktop
cargo build --locked -p bookscraft-desktop --release
xvfb-run -a target/release/bookscraft-desktop --smoke-test
cargo xtask lint
cargo xtask scope W3-05
```

## Deliverables

- Branch: `wp/W3-05-desktop`
- PR title: `W3-05: Platform services and desktop shell`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work (for example `crates/api` or a `Cargo.toml`).
- The webview cannot render on the owner's machine even with the fix: record the details and stop; this needs an owner decision (ADR-0002 risk).
- A pinned platform crate does not build on one OS: report the exact error and stop that line of work.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
