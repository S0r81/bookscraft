# W0-01: Workspace bootstrap, toolchain, xtask, CI matrix

## Goal

Create the Rust workspace with every crate as a compiling stub and its full pinned dependency list, the contract skeleton, the `cargo xtask` tooling (lint rules, scope and DCO checks, Claude Code hooks) and CI with the ten required checks on Linux, Windows and macOS.

## Wave and concurrency

- Wave 0, order 1. Nothing else runs until this PR is merged; then W0-02 and W0-06 start.
- Agent: `platform-release-engineer`.
- Timebox: three sessions. If the work is not done by then, run `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `.cargo/**`, `rustfmt.toml`, `clippy.toml`, `deny.toml`, `deny-mit.toml`, `.gitattributes`, `.gitignore`
- `.github/workflows/**`
- `xtask/**`, `crates/**`, `tests/scenarios/**`, `tests/e2e/**`
- `docs/coordination/CCR/CCR-W0-01-*.md`, `docs/coordination/handoffs/W0-01.md`

Read-only: everything else, in particular `docs/**`, `.claude/**`, `CLAUDE.md`, `README.md`, `CONTRIBUTING.md`, `LICENSE`, `LICENSES/**`, `.github/CODEOWNERS`, `.github/pull_request_template.md`.

## Read first

1. `CLAUDE.md`.
2. `docs/architecture/ARCHITECTURE.md` §1–§4 (crate map, dependency rules D-1..D-10, contracts, fixed constructors, data access), §7, §8 (`Infra`), §9 (platform), §15 (tooling and the required CI checks).
3. `docs/adr/0019-crate-choices.md` (every pin), `0005-licensing.md`, `0020-platform-layer.md`, `0028-repository-policy.md`, `0030-rust-boundary.md`.
4. `docs/coordination/OWNERSHIP.md` in full: the table format your parser reads, the Weave-only table and the ownership checks.
5. `docs/architecture/LEDGER_SPEC.md` §13 rows T-MONEY-2, T-POST-2, T-SCOPE-1, T-LIC-1..3, T-PLAT-1..5 and T-LIMIT-1.
6. `docs/architecture/API.md` §4 (error-code namespaces) and §6 (the machine-readable permission extensions).
7. `.claude/settings.json` (the hook commands you implement) and `.claude/hooks/session-start.sh` (what calls `cargo xtask doctor` and `warm`).
8. `docs/process/PARALLEL_DEV_PLAYBOOK.md` §1.3 (check names) and §2 (cloud environment).
9. `CONTRIBUTING.md` (DCO line format).

## Preconditions

| Precondition | Check |
|---|---|
| The architecture PR is merged | `git show origin/main:docs/architecture/ARCHITECTURE.md > /dev/null` succeeds |
| The sign-off identity is set | `git show origin/main:CLAUDE.md \| grep -c SIGNOFF_NAME` prints `0` |
| The workspace does not exist yet | `git show origin/main:Cargo.toml` fails |
| The pinned toolchain installs in this environment | `rustup toolchain install 1.98.1 --profile minimal` succeeds |

## Scope in/out

In:

1. Workspace manifest, toolchain file, cargo alias, rustfmt and clippy configuration, cargo-deny policies, `.gitattributes`, `.gitignore`.
2. All 29 workspace members as compiling stubs, each with the dependency list in task 2, so `Cargo.lock` covers the whole MVP.
3. The contract skeleton described in ARCHITECTURE §4.5 (task 3).
4. `platform::dirs` (ARCHITECTURE §9).
5. `xtask` with every subcommand registered; `ui`, `e2e` and `package` print which work package implements them and exit 0.
6. CI workflows with the exact job names.

Out: domain types beyond the skeleton (W0-02), the store (W0-04), ledger and posting (W0-05), the spine's steps (W0-03), UI code (W0-06, W2-05), packaging (W5-01), any business logic.

## Tasks

### 1. Workspace files

- Root `Cargo.toml`: `[workspace]` with the 29 members of ARCHITECTURE §2, `exclude = ["spikes/ui"]`, `resolver = "3"`. `[workspace.package]`: `version = "0.0.0"` (Weave 5 sets the release version here), `edition = "2024"`, `rust-version = "1.98"`, `repository = "https://github.com/S0r81/bookscraft"`, `publish = false`. `[workspace.dependencies]`: every crate in ADR-0019 at exactly its pinned version (caret requirements, except `wasm-bindgen` and `wasm-bindgen-cli-support` pinned with `=`), with the features the ADR names (`rusqlite`: `bundled`, `backup`, `hooks`; `uuid`: `v7`, `serde`; `jiff`: `serde`; `rust_decimal`: `serde-with-str`; `reqwest`: `blocking`, `json`, rustls, default features off; `rmcp`: the five features listed; `clap`: `derive`, `env`; `leptos`: `csr`; `insta`: `json`, `redactions`; `rust-embed`; `typst-kit` with embedded fonts). Add other features only where a stub needs them to compile; list every feature choice in the PR. Nothing may pull in OpenSSL (`deny.toml` bans it): turn default features off and choose the rustls or pure-Rust backends for `reqwest`, `lettre`, `oauth2`, `fantoccini` and `keyring`, and give `typst-kit` only its font features (no package downloads at run time). Workspace crates are also listed there by path.
- `rust-toolchain.toml`: channel `1.98.1`, components `rustfmt` and `clippy`, target `wasm32-unknown-unknown`, profile `minimal`.
- `.cargo/config.toml`: `[alias] xtask = "run --quiet --locked --package xtask --"`.
- `rustfmt.toml`: `edition = "2024"`, `newline_style = "Unix"`.
- `clippy.toml` files in `crates/money`, `crates/ledger` and `crates/posting` with `disallowed-types` for `f32` and `f64`. If clippy cannot express primitive types there, say so in the PR; the lint rule D-6 (task 5) enforces it either way.
- `deny.toml` (application policy): allow AGPL-3.0-only (workspace crates), MIT, Apache-2.0, Apache-2.0 WITH LLVM-exception, BSD-2-Clause, BSD-3-Clause, ISC, Zlib, Unicode-3.0, Unlicense, CC0-1.0 and MPL-2.0. Ban `openssl-sys`, `openssl`, `sqlx`, `diesel`, `postgres`, `opener`, `open`, `async-stripe` and `stripe-rust`, and duplicate versions of `rusqlite` and `libsqlite3-sys`. Deny known vulnerabilities. Allow only crates.io as a source. Any further license you must allow (fonts inside Typst, for example) is listed in the PR with the crates that need it, for Weave 0 to confirm.
- `deny-mit.toml`: the permissive list for the MIT crates (ADR-0005): MIT, Apache-2.0, Apache-2.0 WITH LLVM-exception, BSD-2-Clause, BSD-3-Clause, ISC, Zlib, Unicode-3.0, Unlicense, CC0-1.0. MPL-2.0 is excluded.
- `.gitattributes`: `* text=auto eol=lf`, plus `binary` for `*.png`, `*.ico`, `*.icns`, `*.ttf`, `*.otf`, `*.woff2`, `*.xlsx`, `*.zip`.
- `.gitignore`: `/target/`, `/spikes/ui/target/`, `/.claude/worktrees/`, `.env`, and company files outside fixtures (`*.bookscraft*` with `!**/fixtures/**`).

### 2. Crates

Every crate: package name `bookscraft-<dir>` (`xtask` stays `xtask`), `license = "MIT"` for the six MIT crates and `"AGPL-3.0-only"` otherwise, `version`, `edition`, `rust-version`, `repository` and `publish` inherited with `.workspace = true`, dependencies only as `foo.workspace = true`. Every `.rs` file starts with the SPDX line of its crate's license. Every crate root carries `#![forbid(unsafe_code)]`, except `platform` (and `desktop` only if Tauri's generated code requires it, with a comment saying so). Each `lib.rs` starts with a one-line doc comment from ARCHITECTURE §2.

| Crate | Workspace deps | External deps | Dev deps |
|---|---|---|---|
| money (MIT) | — | rust_decimal, serde, thiserror | proptest, serde_json |
| ledger (MIT) | money | jiff, uuid, serde, thiserror | proptest |
| interchange (MIT) | money | serde, serde_json, jiff, rust_decimal, thiserror | proptest, insta |
| iif (MIT) | interchange, money | encoding_rs, jiff, rust_decimal, thiserror | proptest, insta |
| ofx (MIT) | money | encoding_rs, jiff, rust_decimal, thiserror | proptest, insta |
| qbo (MIT) | interchange, money | serde, serde_json, jiff, rust_decimal, thiserror | insta |
| domain | money | uuid, jiff, rust_decimal, serde, serde_json, thiserror, zeroize | proptest |
| posting | domain, ledger, money | rust_decimal, thiserror | proptest, insta, serde_json |
| api-types | money | serde, serde_json, uuid, jiff, rust_decimal; utoipa (optional, feature `openapi`) | insta |
| store | domain, ledger, money | rusqlite, serde, serde_json, sha2, hex, uuid, jiff, rust_decimal, thiserror, tracing | tempfile, proptest |
| books | domain, store, posting, ledger, money | serde, serde_json, sha2, hex, uuid, jiff, rust_decimal, thiserror, tracing | test-support, tempfile, proptest, insta |
| sales | domain, store, posting, books, money | jiff, rust_decimal, thiserror, tracing | test-support, tempfile, proptest, insta |
| purchases | domain, store, posting, books, money | jiff, rust_decimal, thiserror, tracing | test-support, tempfile, proptest, insta |
| banking | domain, store, posting, books, ofx, money | csv, encoding_rs, sha2, hex, serde, serde_json, reqwest, url, base64, jiff, rust_decimal, thiserror, tracing | test-support, tempfile, insta |
| reports | domain, store, ledger, money | csv, jiff, rust_decimal, thiserror | test-support, tempfile, proptest, insta |
| migrate | domain, store, interchange, qbo, iif, money | csv, calamine, encoding_rs, zip, serde, serde_json, sha2, hex, reqwest, oauth2, url, rand, uuid, jiff, rust_decimal, thiserror, tracing | test-support, tempfile, insta, bookscraft-scenarios |
| identity | domain, store | argon2, rand, sha2, hex, base64, aes-gcm, zeroize, uuid, jiff, serde, serde_json, thiserror, tracing | test-support, tempfile |
| render | domain, store, money | typst, typst-pdf, typst-svg, typst-kit, lettre, serde, serde_json, thiserror, tracing | test-support, tempfile, insta, bookscraft-scenarios |
| api | domain, api-types (feature `openapi`), money | axum, tower, tower-http, http, http-body-util, bytes, futures-util, tokio, serde, serde_json, utoipa, uuid, jiff, sha2, hex, thiserror, tracing; rust-embed (optional, feature `embed-ui`) | tokio, tower |
| mcp | domain | rmcp, schemars, axum, tokio, serde, serde_json, thiserror, tracing | test-support, app, tempfile, tower, http-body-util, insta |
| app | domain, store, books, sales, purchases, banking, reports, migrate, identity, render, api, mcp | tokio, tracing, thiserror | tempfile |
| ui | api-types, money | leptos, leptos_router, wasm-bindgen, wasm-bindgen-futures, web-sys, js-sys, gloo-net, console_error_panic_hook, serde, serde_json | — |
| platform | domain | directories, keyring, thiserror, tracing; Linux only: ashpd; Windows only: windows; macOS only: objc2-app-kit, objc2-foundation | tempfile |
| desktop | app, api (feature `embed-ui`), platform, domain | tauri, tauri-plugin-dialog, tokio, tower, http, http-body-util, bytes, tracing, tracing-subscriber, tracing-appender, anyhow | — (build dependency: tauri-build) |
| cli | app, api (feature `embed-ui`), mcp, platform, domain, api-types | clap, tokio, axum, axum-server, rustls, reqwest, serde, serde_json, toml, tracing, tracing-subscriber, anyhow | tempfile |
| test-support | domain, store, ledger, posting, money | proptest, insta, tempfile, uuid, jiff, serde, serde_json | — |
| tests/scenarios (`bookscraft-scenarios`) | test-support, app, domain, money | serde_json, jiff | — |
| tests/e2e (`bookscraft-e2e`) | app, api, api-types, domain | fantoccini, reqwest, tokio, axum, serde_json, tempfile, url | — |
| xtask | — | anyhow, cargo_metadata, globset, spdx, walkdir, serde, serde_json, toml, wasm-bindgen-cli-support | tempfile |

`desktop` has no `build.rs` and no `tauri.conf.json` yet (W3-05 adds them); it compiles as `fn main() {}` with its dependencies declared. `cli` compiles as a `main` that prints its version. `ui` compiles for the host and for `wasm32-unknown-unknown`.

### 3. Contract skeleton (ARCHITECTURE §4.5)

W0-02 fills these in later without renaming anything, so use exactly these names:

- `domain::capability`: `enum Capability` with every variant of ARCHITECTURE §4.4 (books' 15, `Identity`, sales' 8, purchases' 6, banking's 7, `Reports`, migrate's 5, render's 2), deriving `Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash`; `struct CapabilitySet` over a `BTreeSet<Capability>`.
- `domain::errors`: `struct ErrorCode(pub &'static str)`; `struct FieldError { field: String, code: ErrorCode, message: String }`; `struct DomainError { code: ErrorCode, message: String, fields: Vec<FieldError>, status_hint: Option<u16> }`; constant `API_NOT_IMPLEMENTED = ErrorCode("api.not_implemented")` and `DomainError::not_implemented()`.
- `domain::ports`: the service traits `CompanyService`, `BooksService`, `SalesService`, `PurchasesService`, `BankingService`, `ReportsService`, `ImportService`, `ExportService`, `RenderService`, `IdentityService`, `Authenticator`, `IdempotencyStore`, `JobQueue`, and the infrastructure traits `Clock`, `IdGen`, `SecretStore`, `Mailer`, `TaxRateProvider`, `BankProvider`, `LocalePack`: all `Send + Sync` and empty for now. `#[derive(Clone)] struct Infra` with the fields of ARCHITECTURE §8. `BooksPorts`, `IdentityPorts`, `MigratePorts` as in §4.5. `#[derive(Clone)] struct Services` with one `Arc<dyn Trait>` field per service trait (`company`, `books`, `sales`, `purchases`, `banking`, `reports`, `import`, `export`, `render`, `identity`, `authenticator`, `idempotency`, `jobs`). `mod stubs { pub struct Unimplemented; }` implementing every service trait and the infrastructure traits `SecretStore`, `Mailer` and `TaxRateProvider`. `pub use zeroize::Zeroizing;`.
- `store::Stores`: a placeholder struct (`Stores::unopened()`), with `idempotency()` and `jobs()` returning `Arc<dyn …>` of `stubs::Unimplemented`.
- Every service crate (`books`, `sales`, `purchases`, `banking`, `reports`, `migrate`, `identity`, `render`): `pub fn build(stores: Stores, infra: Infra) -> …` with the return type of §4.5, returning the stub, and `pub const CAPABILITIES: &[Capability] = &[];`.
- The infrastructure constructors of ARCHITECTURE §4.5, with exactly those signatures, returning the stub or an empty list: `books::infra::tax_rates()`, `books::infra::locales()`, `identity::infra::envelope_secrets(…)`, `banking::feeds::providers(…)` (in `crates/banking/src/feeds/mod.rs`), `render::infra::mailer(…)`.
- `app::compose(stores, infra) -> Services`, calling every `build`; `app::capabilities() -> CapabilitySet`, the union of every crate's `CAPABILITIES`.
- `mcp::http_router(services: Services) -> axum::Router` answering 501 for every request, and `pub async fn mcp::serve_stdio(services: Services, company_id: String) -> Result<(), DomainError>` returning `DomainError::not_implemented()` (W5-02 implements both).

### 4. `platform::dirs`

`data_dir()`, `config_dir()`, `cache_dir()`, `log_dir()` from `directories::ProjectDirs::from("org", "BooksCraft", "BooksCraft")` (DATA_MODEL §2), returning `Result<PathBuf, DomainError>`. This is the only place a platform directory is resolved.

### 5. `xtask`

One module file per subcommand: `doctor`, `lint`, `scope`, `ci`, `spine`, `hook`, `warm`, `ui`, `e2e`, `package`, `docs`, `dco`.

| Subcommand | Behavior |
|---|---|
| `doctor [--fix] [--tools] [--quiet]` | Checks that the toolchain in `rust-toolchain.toml` is installed with its components and target, and reports whether `cargo-deny` 0.20.2, `tauri-driver` 2.1.0 and `tauri-cli` 2.12.0 are installed. `--fix` installs missing components and targets with rustup; `--tools` also runs `cargo install --locked <tool> --version <v>` for missing tools. Missing tools are a warning, not a failure. |
| `lint` | Runs every rule below over the repository and prints each violation as `<rule id>: <path>[:<line>]: <message>`; exits non-zero on any violation. |
| `scope <WP>` / `scope --ci` | Lists files changed between the merge base with `origin/main` and `HEAD` and fails if any is outside the WP's OWNERSHIP row plus its CCR and handoff files. `--ci` reads the pull request from `$GITHUB_EVENT_PATH`: the WP comes from the head branch `wp/<WP>-…`, or else from a title starting `<WP>: `; `weave/*` branches pass; anything else fails with an explanation. Output on success: `OK: <n> files, all inside owned paths`. |
| `ci [--step <fmt\|clippy\|test\|lint\|deny\|spine>]` | Without `--step`, runs all steps in order. `fmt`: `cargo fmt --all -- --check`. `clippy`: `cargo clippy --locked --workspace --all-targets -- -D warnings`, then `cargo check --locked --target wasm32-unknown-unknown` for `bookscraft-ui` and `bookscraft-api-types`. `test`: `cargo test --locked --workspace --exclude bookscraft-e2e` (end-to-end tests need drivers and run only through `cargo xtask e2e`). `lint`: `cargo xtask lint`, plus `docs --check` when the branch (`GITHUB_HEAD_REF` in CI, the current branch locally) starts with `weave/`, because generated docs are refreshed only in Weaves. `deny`: `cargo deny --locked check` (skipped with a notice when `cargo-deny` is missing, unless `CI` is set). `spine`: as below. |
| `spine` | Runs `cargo run --locked -p bookscraft-scenarios --bin spine`. The binary prints one line per step and a last line `SPINE-JSON {"passed":P,"failed":F,"pending":Q,"steps":[...]}`; `xtask` prints `spine: P passed, F failed, Q pending` and fails when F > 0. The stub you write has zero steps. |
| `hook guard` | Reads the hook JSON from stdin (`tool_input.file_path` or `tool_input.notebook_path`, and `cwd`). Finds the git work tree from `cwd` and its branch. On `wp/<WP>-…`, a path inside the work tree that is not owned by the WP (OWNERSHIP row, its CCR files, its handoff note) exits 2 with: the path, the WP, its owned globs, and "raise a CCR with /ccr instead". On `main`, any edit inside the work tree exits 2 ("start a work package with /start-wp or a Weave with /weave"). Paths outside the work tree, and other branches, exit 0. |
| `hook fmt` | Reads the hook JSON; if the edited file is a `.rs` file inside the work tree, runs `rustfmt --edition 2024` on it. Success exits 0 silently; a rustfmt error exits 2 with its message. |
| `hook stop` | Reads the hook JSON; exits 0 when `stop_hook_active` is true. Otherwise: on a `wp/*` or `weave/*` branch with commits not on its remote branch, exits 2 asking to push; then maps changed `.rs` and `Cargo.toml` files (merge base with `origin/main`, plus uncommitted changes) to packages and runs `cargo check --locked --all-targets -p <package>` for each; a failure exits 2 with the first 40 lines of errors and "fix these, or run /handoff if you must stop". |
| `warm [--quiet]` | `cargo fetch --locked`, then `cargo check --locked` for `bookscraft-money`, `bookscraft-domain`, `bookscraft-ledger` and `bookscraft-api-types`. |
| `ui`, `e2e`, `package` | Print "implemented by W2-05" (ui, e2e) or "implemented by W5-01" (package) and exit 0. |
| `docs [--check]` | If `crates/api/src/bin/openapi-json.rs` exists, runs it and writes (or with `--check` compares) `docs/architecture/openapi.json`. Generates `docs/architecture/error-codes.md` from every error-code constant (namespace, code, defining crate), or compares it with `--check`. A missing file that nothing generates yet is not an error. |
| `dco [--pr-body <file>]` | Reads the PR description from the file or from `$GITHUB_EVENT_PATH`. Passes when it contains a line `Signed-off-by: <name> <<email>>` with a non-empty name and a syntactically valid address, and neither part contains `SIGNOFF_NAME` or `SIGNOFF_EMAIL`. |

`lint` rules, each with a stable id:

| Id | Rule |
|---|---|
| `D-1` | An MIT crate's normal-dependency closure (from `cargo metadata`) contains only MIT workspace crates and external packages whose license expression is satisfied by `deny-mit.toml`'s list (`spdx` crate). |
| `D-2` | The pure crates (`money`, `ledger`, `posting`, `domain`, `interchange`, `iif`, `ofx`, `qbo`, `api-types`) do not depend on `tokio`, `rusqlite`, `reqwest`, `hyper`, `axum`, `tauri`, `lettre` or `keyring`, and their sources do not use `std::fs`, `std::net` or `std::process`. |
| `D-3` | `ui`'s workspace dependencies are exactly `api-types` and `money`. |
| `D-4` | `cfg(target_os`, `cfg(windows`, `cfg(unix`, `cfg(target_family` and `[target.'cfg(…)'.dependencies]` appear only under `crates/platform`. |
| `D-5` | `std::process::Command` (or `process::Command`) appears only under `xtask`. |
| `D-6` | The tokens `f32` and `f64` do not appear in `crates/money`, `crates/ledger` or `crates/posting` (T-MONEY-2). |
| `D-7` | Service crates (`books`, `sales`, `purchases`, `banking`, `reports`, `migrate`, `identity`, `render`) have no normal dependency on another service crate, except `sales`, `purchases` and `banking` on `books`. Dev-dependencies are not counted. |
| `D-8` | `api` and `mcp` have no normal dependency on a workspace crate other than `domain`, `api-types` and `money`. Dev-dependencies are not counted. |
| `D-9` | Every `.rs` file's first line is the SPDX line of its crate's license (T-LIC-3). |
| `D-10` | No tracked `.js`, `.ts`, `.jsx`, `.tsx` or `package.json` file. |
| `members` | The workspace members equal ARCHITECTURE §2's list (29). |
| `workspace-deps` | Every dependency in every member uses `workspace = true`. |
| `pins` | Every `[workspace.dependencies]` version equals the version named for that crate in ADR-0019's table; `wasm-bindgen` and `wasm-bindgen-cli-support` are equal. |
| `file-types` | Every tracked file matches ADR-0030's allowed list (extensions and named files), plus `.claude/hooks/session-start.sh`. |
| `crlf` | No tracked text file contains CRLF (T-PLAT-4). |
| `ownership` | The four checks in OWNERSHIP.md "Ownership checks" (parse, disjoint within a wave, Weave-only paths, CODEOWNERS mirror). `lint --fix-codeowners` rewrites `.github/CODEOWNERS` from the table (used only in Weaves). |
| `error-codes` | No error-code string is defined by more than one constant (string literals that look like `<namespace>.<name>` inside `ErrorCode(…)` or `&str` constants named `*_CODE` or in a `codes` module). |
| `count-limits` | No identifier `MAX_ACCOUNTS`, `MAX_USERS`, `MAX_DIMENSIONS`, `MAX_DIMENSION_VALUES`, `MAX_CUSTOM_FIELDS`, `MAX_CLASSES`, `MAX_LOCATIONS`, `MAX_COMPANIES`, `MAX_CONTACTS` or `MAX_ITEMS` (I-9, T-LIMIT-1). |
| `temp-paths` | No string literal starting `/tmp` or `C:\` in tests (T-PLAT-5). |
| `workflows` | Every `cargo` invocation in `.github/workflows/*.yml` is `cargo xtask …` or contains `--locked`. |

Every rule has a test that builds a violating tree in a temporary directory, runs the rule on it, and asserts the rule id in the output. Nothing that violates a rule is committed.

### 6. CI

- `.github/workflows/ci.yml`, on `pull_request` (`opened`, `synchronize`, `reopened`) and on pushes to `main`. Jobs, named exactly: `fmt`, `clippy`, `lint`, `test` (matrix `os: [ubuntu-latest, windows-latest, macos-latest]`, job name `test (${{ matrix.os }})`, `fail-fast: false`), `deny`, `spine`; plus `e2e (ubuntu-latest)`, which runs `cargo xtask e2e --web` and is not a required check. Each job runs `cargo xtask ci --step <step>`, except `deny`, which first installs `cargo-deny` with `cargo install --locked cargo-deny --version 0.20.2`.
- `.github/workflows/pr-meta.yml`, on `pull_request` (`opened`, `edited`, `synchronize`, `reopened`): jobs `scope` (`cargo xtask scope --ci`, with a full-history checkout) and `dco` (`cargo xtask dco`).
- Linux jobs install the Tauri system packages (`libwebkit2gtk-4.1-dev libssl-dev libxdo-dev libayatana-appindicator3-dev librsvg2-dev build-essential pkg-config`; the `e2e` job also `webkit2gtk-driver xvfb`). Third-party actions are pinned to full commit SHAs; the Rust build cache uses a pinned cache action. The toolchain comes from `rust-toolchain.toml`.

### 7. Stubs for the spine and end-to-end crates

- `tests/scenarios`: a library plus a binary target named `spine` (`[[bin]] name = "spine"`) that prints `SPINE-JSON {"passed":0,"failed":0,"pending":0,"steps":[]}`.
- `tests/e2e`: library and one ignored placeholder test.

## Invariants touched

| Invariant | What this WP does | Test |
|---|---|---|
| I-1 | D-6 lint and clippy configuration | T-MONEY-2 |
| I-2 | D-2 pure-crate rule | T-POST-2 |
| I-9 | `count-limits` rule | T-LIMIT-1 (lint part) |
| I-11 | Payment SDKs banned in `deny.toml` | T-SCOPE-1 (deny part) |
| I-12 | `deny.toml`, `deny-mit.toml`, D-1, D-9 | T-LIC-1, T-LIC-2, T-LIC-3 |
| I-13 | 3-OS CI, D-4, D-5, `.gitattributes`, `crlf`, `temp-paths`, `platform::dirs` | T-PLAT-1..4, T-PLAT-5 (lint part) |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | The workspace builds with the locked dependencies | `cargo build --locked --workspace --all-targets` exits 0 |
| AC-2 | The 29 members match ARCHITECTURE §2, and every dependency version matches ADR-0019 | `cargo xtask lint` exits 0 (rules `members`, `workspace-deps`, `pins`) |
| AC-3 | Every lint rule in task 5 fires on a violating tree | `cargo test --locked -p xtask` passes, with one test per rule id whose name contains the id (for example `lint_d6_float_in_money`) |
| AC-4 | The repository itself passes every lint rule | `cargo xtask lint` exits 0 |
| AC-5 | The ten required checks exist with the exact names and are green on this PR | The PR's checks list shows `fmt`, `clippy`, `lint`, `test (ubuntu-latest)`, `test (windows-latest)`, `test (macos-latest)`, `deny`, `spine`, `scope`, `dco`, all passing |
| AC-6 | `scope` accepts this branch for W0-01 and rejects it for another WP | `cargo xtask scope W0-01` exits 0; `cargo xtask scope W1-02` exits non-zero and lists foreign paths |
| AC-7 | `dco` accepts a valid sign-off and rejects the placeholder, a missing line and a malformed address | Tests in `xtask` for all four cases pass |
| AC-8 | The hooks behave as specified | Tests feed JSON to `hook guard` (exit 2 for an unowned path on a `wp/W1-02-books` branch of a temporary repository, exit 0 for an owned path and for a path outside the repository), `hook fmt` (a misformatted file becomes formatted) and `hook stop` (exit 0 when `stop_hook_active` is true; exit 2 when a temporary branch has unpushed commits) |
| AC-9 | `doctor` reports and fixes the toolchain | `cargo xtask doctor` exits 0 in this session; with the wasm target removed, `cargo xtask doctor --fix` reinstalls it |
| AC-10 | The skeleton composes | A test in `app` builds `Services` with `app::compose` from `Stores::unopened()` and test implementations of the infrastructure traits, and asserts that `app::capabilities()` is empty; `cargo test --locked -p bookscraft-app` passes |
| AC-11 | The UI and wire-type crates compile to WebAssembly | `cargo check --locked -p bookscraft-ui --target wasm32-unknown-unknown` and the same for `bookscraft-api-types` exit 0 |
| AC-12 | Platform directories resolve on all three OSes | A `platform` test, run by CI on each OS, asserts `data_dir()` is absolute and contains a component equal to `bookscraft` ignoring case |
| AC-13 | Line endings are pinned | `test "$(git ls-files --eol \| grep -c 'i/crlf')" = 0` succeeds |
| AC-14 | The spine runs and reports nothing yet | `cargo xtask spine` prints `spine: 0 passed, 0 failed, 0 pending` and exits 0 |
| AC-15 | Generated docs are checkable | `cargo xtask docs --check` exits 0 (nothing to generate yet) |

## Verify

```sh
cargo xtask doctor
cargo build --locked --workspace --all-targets
cargo test --locked -p xtask
cargo xtask ci
cargo check --locked -p bookscraft-ui --target wasm32-unknown-unknown
cargo check --locked -p bookscraft-api-types --target wasm32-unknown-unknown
test "$(git ls-files --eol | grep -c 'i/crlf')" = 0
cargo xtask scope W0-01
```

## Deliverables

- Branch: `wp/W0-01-workspace`
- PR title: `W0-01: Workspace bootstrap, toolchain, xtask and CI`
- PR description: the template, the feature choices made in `[workspace.dependencies]`, any license added to `deny.toml`, and the ten check names as GitHub shows them (the owner needs them for branch protection).

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work.
- A pinned crate fails to build on one of the three OSes: report the exact error and the smallest fix (a feature change, or a CCR proposing another pin). Do not choose another version yourself.
- `cargo deny` reports a license outside the lists above that cannot be avoided: list it with the crates that need it in the PR and continue; Weave 0 decides.
- A locked invariant would be violated, a precondition is false, or the specs contradict each other on something this WP must decide.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
