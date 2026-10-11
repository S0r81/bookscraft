---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, platform-release-engineer
---

# Packaging and release: Linux first; Windows and macOS as their own milestone

## Context and Problem Statement

Desktop is first-class (owner decision D-2): Linux first for development and first releases, then Windows and macOS. CI must build and test on all three from the first build prompt (I-13), even though releases are Linux-first.

## Decision Drivers

* Fedora is the owner's distro; Debian and Ubuntu users are the largest group.
* No shell scripts for packaging (D-1): `cargo xtask package`.
* Signing and notarization need paid accounts and secrets, so they are kept out of MVP.

## Considered Options

* Tauri bundler driven by `cargo xtask package` for AppImage, deb and rpm, plus a Flatpak manifest; MSI or NSIS with code signing and a notarized dmg in a later milestone; Tauri updater for AppImage, Windows and macOS
* cargo-packager
* Snap first

## Decision Outcome

Chosen option: the first one.

**Application identifier.** `io.github.s0r81.bookscraft`, following Flathub's rule for apps hosted on GitHub (`io.github.<user>.<repo>`, lowercase domain portion; docs.flathub.org "Requirements", checked 2026-10-10). It is the Tauri `identifier` (W3-05), the keychain service name for stored secrets (W3-05), the Flatpak app id, and the name of the desktop entry and AppStream metainfo files (W5-01). Changing it after the first release orphans keychain entries and Flatpak data, so a change (for example to a project domain) must be decided before W3-05 starts. Data directories are unaffected: they come from `platform::dirs` (DATA_MODEL §2).

**MVP (W5-01).** `cargo xtask package appimage|deb|rpm|flatpak` produces Linux artifacts. A GitHub Actions release workflow builds them on tags `v*`, together with a tarball of the `bookscraft` CLI and server binary for x86_64 Linux, and attaches them to a draft GitHub release with SHA-256 sums. The Flatpak manifest lives in `packaging/flatpak/`; Flathub submission happens after MVP. The Tauri bundler fetches its AppImage tooling (`linuxdeploy`) at build time and caches it (tauri-bundler release notes, v1.0.0-rc.10: "Pull correct linuxdeploy AppImage", "Cache bundling tools in a directory shared by all tauri projects"), so AppImages are built where that download works: GitHub Actions or the owner's machine, not necessarily a cloud session. W5-01 records which bundle types download anything.

**Windows + macOS milestone (ROADMAP M-WM).**

* MSI or NSIS installer, signed with an Authenticode certificate.
* dmg signed with a Developer ID and notarized.
* Tauri updater with signed update manifests for AppImage, Windows and macOS. Distro packages update through their repositories.
* macOS print path checked.

### Consequences

* Good, because Linux users get packages early; the other platforms are built and tested in CI all along.
* Bad, because Windows and macOS users run unsigned dev builds until the milestone.

### Confirmation

W5-01 acceptance: each Linux artifact installs and launches on a fresh CI runner (`bookscraft-desktop --smoke-test` under `xvfb` for AppImage and deb; rpm checked on Fedora by the owner); the release workflow's build and smoke jobs run on every pull request that touches packaging, and its publish job runs only on `v*` tags, creating a draft release that the owner publishes.

## Pros and Cons of the Options

### Tauri bundler via xtask

* Good, because it is the bundler matched to the framework, and Rust-driven.

### cargo-packager

* Neutral, because it is capable.
* Bad, because it has a smaller user base, and the Tauri bundler is already in the dependency tree.

### Snap first

* Bad, because Fedora users rarely use Snap, and the confinement complicates Secret Service and portals.

## More Information

Tauri distribution targets (v2.tauri.app/distribute); ROADMAP milestone M-WM.
