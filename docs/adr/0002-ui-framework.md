---
status: proposed
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, ui-engineer
---

# UI framework: Leptos (client-side WASM) in a Tauri 2 shell (provisional)

Provisional until spike W0-06 passes. The spike result moves this ADR to `accepted`, or to `rejected` with a superseding ADR.

## Context and Problem Statement

BooksCraft needs a Rust-authored UI that:

* runs on Linux, Windows and macOS;
* handles data-dense tables, forms and keyboard-first entry;
* is accessible;
* shows print and PDF previews;
* serves server mode's browser clients from one codebase.

Which framework?

## Decision Drivers

* 100% Rust authoring (owner decision D-1); no Node toolchain.
* One UI codebase for desktop and browser (server mode).
* Mature accessibility (screen readers), text input, IME, printing.
* License compatible with AGPL-3.0.
* Linux first (owner on Fedora, GNOME, Wayland, NVIDIA).
* Reversal cost: this is the most expensive decision to undo (BRIEF_AUDIT R-1).

## Considered Options

* Leptos 0.8 (client-side rendering, WASM) inside Tauri 2.12
* Dioxus 0.7 (desktop webview renderer and web renderer)
* Slint 1.18 (native renderer; GPL-3.0 option)
* iced 0.14 (native, Elm-like)
* egui 0.36 (immediate mode)

## Decision Outcome

Chosen option (provisional): **Leptos 0.8 CSR in a Tauri 2 shell**. Runner-up: **Dioxus 0.7**.

Reasons:

* A real DOM gives the platform's accessibility tree, text editing, IME and printing for free.
* The same WASM bundle serves browsers in server mode.
* Tauri's custom protocol lets the desktop reach the in-process router without opening a port.
* Leptos (MIT) and Tauri (MIT or Apache-2.0) are AGPL-compatible.
* The build is plain cargo plus the `wasm-bindgen-cli-support` library, driven by `cargo xtask ui build`, with no Node and no Trunk downloads.

### Consequences

* Good, because desktop and web share one UI and one API client.
* Good, because accessibility comes from the browser engine and is checked with Orca on GNOME.
* Bad, because on Linux the UI depends on WebKitGTK, whose rendering varies by GPU and driver. The NVIDIA + Wayland combination needs `WEBKIT_DISABLE_DMABUF_RENDERER=1` on some systems; `platform::webview` applies it.
* Bad, because the HTML host page and CSS files are non-Rust assets (allowed as data, ADR-0030).
* Bad, because ArtCraft's "no web views" principle is not followed; the README makes no such claim (owner accepted, Q-5).

### Confirmation

Spike W0-06 ([docs/prompts/W0-06-ui-spike.md](../prompts/W0-06-ui-spike.md)) must pass every criterion, in up to three working sessions:

1. Builds with `cargo` + `xtask` only.
2. Opens on the owner's Fedora machine.
3. A 10,000-row table renders its first screen in < 500 ms and scrolls at ≥ 50 fps.
4. Keyboard grid navigation works.
5. A 20-line invoice form with a type-ahead over 500 accounts responds in < 50 ms per keystroke.
6. Orca announces labels, roles and table headers.
7. A Typst SVG print preview prints through the GTK dialog.
8. The identical WASM bundle (same hash) calls `/api/v1/ping` through the custom protocol and in a browser against a server.

If a criterion fails for framework reasons, run the same criteria against Dioxus 0.7. If it fails for webview reasons, escalate to the owner, with Slint as the native fallback.

## Pros and Cons of the Options

### Leptos + Tauri

* Good, because the DOM gives accessibility, IME, printing, and fine-grained reactivity for large tables.
* Good, because it compiles to WASM for the web.
* Bad, because there are two runtimes (WASM in the webview, native core) and data crosses an HTTP boundary.

### Dioxus 0.7

* Good, because it is one framework for desktop (webview), web and mobile, with good hot-patching.
* Neutral, because the native renderer (Blitz) is still work in progress, per its 0.7 release notes.
* Bad, because desktop mode runs Rust in the native process and talks to the webview, which differs from the web build's architecture.

### Slint

* Good, because rendering is native, with no webview and a predictable look.
* Bad, because the license is GPL-3.0 or proprietary (GPL is AGPL-compatible but restricts the MIT libraries' reuse story), and there is no browser target for server mode without its WASM renderer.

### iced

* Good, because it is pure Rust and native.
* Bad, because its accessibility support is limited and it has no web reuse for server mode.

### egui

* Good, because it is very fast to build tools with.
* Bad, because immediate mode makes accessibility and native-feeling text input hard for a data-entry product.

## More Information

Versions checked on 2026-10-09 (BRIEF_AUDIT §7.2). The spike lives in `spikes/ui/`, its own Cargo workspace. Results are recorded in `spikes/ui/RESULTS.md` and summarized here.
