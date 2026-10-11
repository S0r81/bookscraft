# W5-01: Linux packaging and release workflow

## Goal

Produce the Linux desktop packages (AppImage, deb, rpm, and a Flatpak manifest) with `cargo xtask package`, plus a release workflow that builds them and the `bookscraft` server binary on `v*` tags, checks that each package installs and launches, and attaches them to a draft GitHub release with SHA-256 sums.

## Wave and concurrency

- Wave 5, batch A (with W5-03 and W5-04). Paths do not overlap.
- Agent: `platform-release-engineer`. The owner checks the rpm and the Flatpak build on Fedora.
- Timebox: two sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `packaging/**`, `.github/workflows/release.yml`, `xtask/src/package.rs`, `crates/desktop/tauri.conf.json`, `crates/desktop/icons/**`
- `docs/coordination/CCR/CCR-W5-01-*.md`, `docs/coordination/handoffs/W5-01.md`

Read-only: everything else, including `crates/desktop/src/**` (use `--smoke-test` as W3-05 built it), `.github/workflows/ci.yml` and `pr-meta.yml`, and every `Cargo.toml`.

## Read first

1. `CLAUDE.md` and `.claude/agents/platform-release-engineer.md`.
2. ADR-0026 (packaging, the application identifier, the AppImage tooling download), ADR-0030 (the Flatpak manifest, desktop entry and metainfo are allowed data files), ADR-0019 (tauri-cli 2.12.0).
3. `docs/architecture/ARCHITECTURE.md` §5 (desktop topology), §11 (own wording) and §15 (tooling, `package` subcommand).
4. `docs/process/PARALLEL_DEV_PLAYBOOK.md` §2 (what the cloud environment can download) and §3.3 (local mode on Fedora).
5. The merged `crates/desktop/tauri.conf.json`, `crates/desktop/icons/` and `xtask/src/package.rs` (the stub).
6. Tauri's distribution guides for Debian, RPM, AppImage and Flatpak (v2.tauri.app/distribute).

## Preconditions

| Precondition | Check |
|---|---|
| Weave 4 is merged | `git log origin/main --format=%s \| grep -q '^Weave 4: '` |
| The desktop app has its Tauri configuration and smoke flag | `git show origin/main:crates/desktop/tauri.conf.json > /dev/null && git grep -q 'smoke-test' origin/main -- crates/desktop/src` |
| tauri-cli is installable | `cargo xtask doctor --tools` reports `tauri-cli 2.12.0` installed |

## Scope in/out

In:

- **`cargo xtask package <kind>`:** runs `cargo xtask ui build`, then `cargo tauri build --bundles <kind>` for `crates/desktop` (tauri-cli 2.12.0, from `cargo xtask doctor --tools`), copies the artifact into `target/dist/` and appends its SHA-256 to `target/dist/SHA256SUMS`. Kinds: `appimage`, `deb`, `rpm`, `flatpak`. `msi` and `dmg` print that they belong to milestone M-WM (ROADMAP §5) and exit 2.
- **Bundle configuration** in `tauri.conf.json`: product name BooksCraft, identifier `io.github.s0r81.bookscraft`, version taken from the workspace (no version in the file), deb and rpm runtime dependencies for WebKitGTK 4.1, the desktop entry and metainfo below, icons.
- **Linux metadata** in `packaging/linux/`: `io.github.s0r81.bookscraft.desktop` (categories `Office;Finance;`) and `io.github.s0r81.bookscraft.metainfo.xml` (AppStream: BooksCraft's own summary and description, AGPL-3.0-only, project URL, a release entry); no Intuit names, marks or wording except a factual interoperability sentence.
- **Flatpak:** `packaging/flatpak/io.github.s0r81.bookscraft.yml` on the GNOME runtime, installing the binary and resources from the release's deb (a `file` source with its SHA-256, as in Tauri's Flatpak guide); `cargo xtask package flatpak` writes the manifest for the current version and deb checksum into `target/dist/`. Building from source for Flathub (vendored crates generated without the usual Python tool) is a v1 item.
- **Release workflow** `.github/workflows/release.yml`:
  - triggers: `push` of tags `v*`, and `pull_request` limited to `packaging/**`, `.github/workflows/release.yml`, `xtask/src/package.rs` and `crates/desktop/**`;
  - `build` on `ubuntu-22.04`: Tauri system packages, `cargo install --locked tauri-cli --version 2.12.0`, `cargo xtask package deb`, `rpm`, `appimage` and `flatpak`, `cargo build --locked --release -p bookscraft-cli` packed as `bookscraft-<version>-x86_64-linux.tar.gz`, `SHA256SUMS` for everything, uploaded as a workflow artifact;
  - `smoke` on a fresh `ubuntu-22.04` runner: install the deb with `apt-get install ./<deb>` and run `xvfb-run -a bookscraft-desktop --smoke-test`; run the AppImage the same way (with `APPIMAGE_EXTRACT_AND_RUN=1`, so FUSE is not needed); validate the desktop entry (`desktop-file-validate`) and the metainfo (`appstreamcli validate --no-net`);
  - `publish`, only for tags, after `smoke`: `permissions: contents: write` on this job alone; creates a **draft** release for the tag with every artifact and `SHA256SUMS` (`gh release create --draft --verify-tag`, with `--notes-file docs/releases/<tag>.md` when that file exists, and `--prerelease` for tags containing `-rc`). The owner reviews and publishes it. Every other job has `contents: read`.
  - Third-party actions pinned to full commit SHAs; every `cargo` call `--locked` (lint rule `workflows`).
- **Tags:** the owner creates them (cloud sessions cannot push tags); the playbook steps are in W5-W.

Out: Windows and macOS installers, signing, notarization and the updater (M-WM); Flathub submission (after MVP); distro repositories; changes to `ci.yml` or the desktop source.

## Tasks

1. `xtask/src/package.rs` with tests of argument handling and checksum output.
2. `tauri.conf.json` bundle settings; icons checked at every size Tauri needs.
3. Desktop entry, metainfo and the Flatpak manifest.
4. The release workflow, run on this PR.
5. The owner's Fedora checklist in the PR (rpm install and launch, Flatpak build and launch).

## Invariants touched

| Invariant | Test |
|---|---|
| I-13 | packaging is driven by `xtask` (the only crate allowed to start processes); no shell scripts are tracked (lint `file-types`) |
| I-12 | the packages carry the AGPL license text and the metainfo declares `AGPL-3.0-only` (checked by `appstreamcli validate`) |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | deb and rpm build in a session | `cargo xtask package deb` and `cargo xtask package rpm` each leave one artifact in `target/dist/` and a matching line in `SHA256SUMS`; the PR states which bundle types downloaded anything at build time |
| AC-2 | The release workflow builds everything on this PR | the `build` job of `release.yml` is green on the PR and its artifact holds the AppImage, deb, rpm, Flatpak manifest, CLI tarball and `SHA256SUMS` |
| AC-3 | Packages install and launch on a clean machine | the `smoke` job is green: the installed deb and the AppImage each print `SMOKE-OK` under Xvfb |
| AC-4 | Linux metadata is valid | `desktop-file-validate` and `appstreamcli validate --no-net` pass in the `smoke` job |
| AC-5 | Publishing happens only for tags | on the PR run, the `publish` job is skipped; it is the only job with `contents: write` (visible in the workflow file) |
| AC-6 | M-WM kinds are explicit | `xtask` tests: `package msi` and `package dmg` exit 2 with a message naming milestone M-WM |
| AC-7 | rpm and Flatpak work on Fedora | the PR records the owner's run: `sudo dnf install ./<rpm>`, `bookscraft-desktop --smoke-test` prints `SMOKE-OK`, the app opens a company; `flatpak-builder --user --install` with the generated manifest, then the app launches |
| AC-8 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W5-01` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p xtask --all-targets -- -D warnings
cargo test --locked -p xtask
cargo xtask ui build
cargo xtask package deb
cargo xtask package rpm
xvfb-run -a target/release/bookscraft-desktop --smoke-test
cargo xtask lint
cargo xtask scope W5-01
```

## Deliverables

- Branch: `wp/W5-01-packaging`
- PR title: `W5-01: Linux packages and release workflow`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work (for example a desktop source change, a new dependency, or a change to `ci.yml`).
- A step would need a signing key, certificate or other secret: stop; that is milestone M-WM.
- A package needs a download that the cloud session blocks: build that kind in the workflow only and say so in the PR; do not vendor binaries into the repository.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
