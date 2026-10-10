---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect
---

# Crate choices and pinned versions

## Context and Problem Statement

Wave 0 pins every shared dependency in `[workspace.dependencies]` (W0-01), so builders never edit manifests afterwards. Which crates, at which versions?

## Decision Drivers

* Licenses compatible with AGPL-3.0 (and permissive for the MIT crates' dependencies).
* Maintained, widely used, buildable on Linux, Windows and macOS.
* Synchronous service ports (ADR-0004): blocking I/O inside services, async only at the HTTP edge.
* Stability: each pin is the newest stable release published at least 14 days before 2026-10-10 (cutoff 2026-09-26), checked against crates.io on 2026-10-10.

## Considered Options

The chosen crate per concern is in the table below; the alternatives considered are listed with it.

## Decision Outcome

**Toolchain.** Rust **1.98.1** (`rust-toolchain.toml`) with components `rustfmt` and `clippy` and target `wasm32-unknown-unknown`; edition 2024; resolver 3; `rust-version = "1.98"`. Rust 1.99.0 (released 2026-10-01) is skipped as younger than 14 days; MSRVs in this list top out at 1.92 (typst).

| Concern | Crate (pin) | License | Alternatives considered |
|---|---|---|---|
| Async runtime | tokio 1.53.1 | MIT | async-std (unmaintained), smol |
| HTTP framework | axum 0.8.9; tower 0.5.3; tower-http 0.7.1; http 1.5.0; http-body-util 0.1.5; bytes 1.12.1; futures-util 0.3.34 | MIT | actix-web (different ecosystem), poem |
| TLS server | axum-server 0.8.0 with rustls 0.23.45 | MIT; Apache-2.0/ISC/MIT | a reverse proxy only (still documented) |
| Database | rusqlite 0.40.2 (`bundled`, `backup`, `hooks`) | MIT | sqlx 0.9 (async, compile-time DB), diesel |
| Migrations | own runner in `store` (embedded SQL, `schema_migrations`) | — | refinery 0.10, rusqlite_migration 2.6 (both couple to a rusqlite version) |
| Serialization | serde 1.0.229; serde_json 1.0.151 | MIT/Apache-2.0 | — |
| Ids, dates | uuid 1.26.1 (`v7`, `serde`); jiff 0.2.37 (`serde`) | Apache-2.0/MIT; Unlicense/MIT | chrono, time |
| Decimals | rust_decimal 1.43.0 (`serde-with-str`) | MIT | bigdecimal |
| Hashing, encoding, randomness | sha2 0.11.0; hex 0.4.3; base64 0.23.1; rand 0.10.3; zeroize 1.9.0 | MIT/Apache-2.0 | blake3 (for audit; SHA-256 chosen for ubiquity) |
| Passwords, encryption | argon2 0.6.0; aes-gcm 0.11.1 | MIT/Apache-2.0 | scrypt, ring |
| Errors | thiserror 2.0.21 (libraries); anyhow 1.0.104 (binaries and xtask only); RFC 9457 problem details at the API edge | MIT/Apache-2.0 | snafu, eyre |
| Logging | tracing 0.1.44; tracing-subscriber 0.3.23; tracing-appender 0.2.5 | MIT | log + env_logger |
| OpenAPI | utoipa 6.0.0 | MIT/Apache-2.0 | aide 0.15 (fewer users), hand-written spec |
| HTTP client | reqwest 0.13.5 (`blocking`, `json`, rustls); oauth2 5.0.0; url 2.5.8 | MIT/Apache-2.0 | ureq |
| CSV, XLSX, text encodings, archives | csv 1.4.0; calamine 0.36.1; encoding_rs 0.8.42; zip 8.6.0 | Unlicense/MIT; MIT; (Apache-2.0/MIT) AND BSD-3-Clause; MIT | — |
| OFX and IIF | own parsers in `ofx` and `iif` (MIT) | — | ofx-rs 0.2 (small, partial OFX coverage) |
| PDF and preview | typst 0.15.1; typst-pdf 0.15.1; typst-svg 0.15.1; typst-kit 0.15.1 (embedded fonts) | Apache-2.0 | krilla 0.8, printpdf 0.12, HTML-to-PDF |
| Email | lettre 0.11.23 (SMTP, rustls) | MIT | provider APIs |
| MCP | rmcp 3.4.1 (`server`, `macros`, `transport-io`, `transport-streamable-http-server`, `schemars`); schemars 1.2.2 | Apache-2.0; MIT | hand-rolled JSON-RPC |
| CLI | clap 4.6.7 (`derive`, `env`) | MIT/Apache-2.0 | argh |
| Desktop | tauri 2.12.0; tauri-build 2.7.0; tauri-plugin-dialog 2.8.0 | Apache-2.0/MIT | Dioxus desktop (ADR-0002 runner-up) |
| Platform | directories 6.0.0; keyring 4.2.0; ashpd 0.13.13 (Linux); windows 0.62.2 (Windows); objc2-app-kit 0.3.2 and objc2-foundation 0.3.2 (macOS) | MIT/Apache-2.0; MIT; MIT; MIT/Apache-2.0; Zlib/Apache-2.0/MIT | opener or open (they spawn `xdg-open`: violates I-13) |
| Static assets in the server binary | rust-embed 8.12.0 (feature `embed-ui`, off in dev) | MIT | include_dir |
| UI (WASM) | leptos 0.8.21 (`csr`); leptos_router 0.8.16; wasm-bindgen **=0.2.129**; wasm-bindgen-futures 0.4.79; web-sys 0.3.106; js-sys 0.3.106; gloo-net 0.7.0; console_error_panic_hook 0.1.7 | MIT; MIT/Apache-2.0 | ADR-0002 alternatives |
| xtask, config files | cargo_metadata 0.23.1; globset 0.4.20; spdx 0.13.5; walkdir 2.5.0; wasm-bindgen-cli-support **=0.2.129**; toml 0.9.8 (also the server config file in `cli`); serde_json; anyhow | MIT; Unlicense/MIT; Apache-2.0; Unlicense/MIT; MIT/Apache-2.0; MIT/Apache-2.0 | Trunk (downloads tools from GitHub at build time: blocked in cloud sessions) |
| Testing | proptest 1.11.0; insta 1.48.0 (`json`, `redactions`); tempfile 3.27.0; fantoccini 0.22.1 (WebDriver) | MIT/Apache-2.0; Apache-2.0 | quickcheck |
| Cargo tools (installed, not dependencies) | cargo-deny 0.20.2; tauri-driver 2.1.0 (Linux desktop e2e with `webkit2gtk-driver` and `xvfb`); tauri-cli 2.12.0 (the bundler behind `cargo xtask package`) | MIT/Apache-2.0; Apache-2.0/MIT; Apache-2.0/MIT | cargo-nextest (not needed), cargo-binstall (GitHub downloads blocked in cloud sessions) |
| Packaging | Tauri bundler through `cargo xtask package` (AppImage, deb, rpm; MSI or NSIS; dmg); Flatpak manifest | — | cargo-packager 0.11 (fewer users) |

`wasm-bindgen` and `wasm-bindgen-cli-support` are pinned with `=` and must always be equal. The other pins are caret requirements frozen by the committed `Cargo.lock`. CI and every documented command use `--locked`.

### Consequences

* Good, because builders start with every dependency they need, and `Cargo.lock` is not a hotspot.
* Bad, because every stub crate compiles its declared dependencies (Tauri, Typst) in full-workspace builds. Builders use `-p <crate>` (documented in CLAUDE.md), and CI caches.
* Bad, because upgrades wait for a Weave (CCR), which is deliberate (R-9).

### Confirmation

* `cargo deny check` (licenses, bans, advisories, sources) in CI.
* `cargo xtask lint` checks that every crate takes its dependencies from `[workspace.dependencies]` (`foo.workspace = true`), and that the `wasm-bindgen` and `wasm-bindgen-cli-support` versions are equal.
* `deny.toml` bans `openssl-sys` (rustls everywhere), `sqlx`, `diesel`, `opener`, `open`, payment SDK crates (`async-stripe`, `stripe-rust`, I-11) and duplicate major versions of `rusqlite` or `libsqlite3-sys`.

## Pros and Cons of the Options

Covered per row above. The deciding factors were license, sync-friendliness (rusqlite, reqwest blocking), no build-time downloads (no Trunk, no binstall), and no shelling out (no opener).

## More Information

[BRIEF_AUDIT.md](../architecture/BRIEF_AUDIT.md) §7.2 (first check, 2026-10-09). The pin script logic: newest non-yanked `x.y.z` with `created_at` ≤ cutoff, from `https://crates.io/api/v1/crates/<name>/versions`.
