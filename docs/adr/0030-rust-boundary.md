---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect
---

# Where "100% Rust" stops: code is Rust; data and config files are allowed

## Context and Problem Statement

Owner decision D-1: all application code, UI, tooling and build automation are Rust, with a `cargo xtask` pattern. Exempt are config and data formats (TOML, YAML, SQL migrations, Markdown, CI workflow files) and the minimal bootstrap shell needed to install Rust. A web-based UI and PDF templates add other file types (G-26).

## Decision Drivers

* No JavaScript authored, no Node toolchain, no build-time downloads.
* Keep the exemption list explicit so reviewers can check it.

## Considered Options

* Allow non-code assets as data: CSS, one HTML host page, Typst templates, fonts, icons, the Flatpak manifest, container files, the cloud environment setup script. Ban authored JS/TS and Node.
* Inline styles only, with Rust-generated templates
* Allow small JS helpers

## Decision Outcome

Chosen option: the first one (owner default, Q-4).

**Allowed files:**

* `*.rs`;
* `*.toml`, `*.yml`/`*.yaml`, `*.sql`, `*.md`, `*.json` (data);
* `*.css`, the single `crates/ui/index.html` host page, `*.typ` templates, fonts, `*.svg` and `*.png` icons;
* the Flatpak manifest and an optional container file for the server image.

**Allowed shell:**

* `.claude/hooks/session-start.sh`, which only installs or verifies Rust, then hands off to `cargo xtask`;
* the environment setup script pasted into the Claude Code cloud environment UI (not in the repo).

**Not allowed:**

* authored `.js`, `.ts`, `.jsx`, `.tsx`, `package.json`, Node, npm;
* shell or Python scripts in the repo (beyond the bootstrap above);
* Makefiles.

`wasm-bindgen`'s generated JavaScript glue is a build artifact in `target/`, never committed.

### Consequences

* Good, because reviewers can verify the rule mechanically.
* Bad, because CSS is authored by hand (no preprocessors that need Node). A Rust-side CSS minifier can be added to `xtask ui build` later if needed.

### Confirmation

`cargo xtask lint` rule D-10 (no authored JS/TS or `package.json`) plus an allowlist of file extensions outside `target/`, failing on anything else (W0-01).

## Pros and Cons of the Options

### Assets as data

* Good, because it is practical for a DOM UI and PDF templates while code stays Rust.

### Inline styles, Rust templates

* Bad, because it is awkward to maintain, hard for designers, and gains nothing in safety.

### Small JS helpers

* Bad, because it breaks the owner's rule and reintroduces a second language and toolchain.

## More Information

BRIEF_AUDIT OV-1, G-26; ADR-0002.
