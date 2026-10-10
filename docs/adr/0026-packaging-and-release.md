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

**MVP (W5-01).** `cargo xtask package appimage|deb|rpm|flatpak` produces Linux artifacts. A GitHub Actions release workflow builds them on tags `v*` and attaches them to a GitHub release with SHA-256 sums. The Flatpak manifest lives in `packaging/flatpak/`; Flathub submission happens after MVP.

**Windows + macOS milestone (ROADMAP M-WM).**

* MSI or NSIS installer, signed with an Authenticode certificate.
* dmg signed with a Developer ID and notarized.
* Tauri updater with signed update manifests for AppImage, Windows and macOS. Distro packages update through their repositories.
* macOS print path checked.

### Consequences

* Good, because Linux users get packages early; the other platforms are built and tested in CI all along.
* Bad, because Windows and macOS users run unsigned dev builds until the milestone.

### Confirmation

W5-01 acceptance: each Linux artifact installs and launches in a clean container or VM (CI job with `xvfb` for AppImage and deb; rpm checked on Fedora by the owner); the release workflow dry-runs on a tag in a fork.

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
