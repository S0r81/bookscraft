---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, platform-release-engineer
---

# One platform crate for all OS-specific code; no shelling out

## Context and Problem Statement

I-13 requires:

* OS-specific code in one platform crate;
* no shelling out to OS tools;
* platform-standard directories;
* tests that assume neither Unix paths nor case-sensitive filesystems.

Where do directories, secrets, URL opening, file dialogs and webview quirks live?

## Decision Drivers

* Linux first, then Windows and macOS, without scattering `cfg` blocks.
* No `xdg-open`, `open` or `start` subprocesses.
* The desktop must work on the owner's Fedora GNOME Wayland NVIDIA machine.

## Considered Options

* A `platform` crate with `dirs`, `secrets`, `open`, `webview` and `fs` modules over portal and OS APIs; file dialogs via `tauri-plugin-dialog`
* `cfg` blocks wherever needed
* Crates that spawn helper processes (opener, open)

## Decision Outcome

Chosen option: **`crates/platform`**, with the function table in [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) §9.

* Linux uses XDG directories, Secret Service through `keyring`, and the XDG Desktop Portal (OpenURI) through `ashpd`.
* Windows uses Known Folders, Credential Manager and `ShellExecuteW`.
* macOS uses `~/Library`, Keychain and `NSWorkspace`.
* `webview::apply_env_fixups` handles WebKitGTK quirks (NVIDIA + Wayland), configured from the spike's findings.
* W0-01 implements `dirs`; W3-05 implements the rest.

### Consequences

* Good, because the lint can prove I-13 mechanically: `cfg` only in platform, no `std::process::Command` outside xtask.
* Bad, because portal-based URL opening needs a portal service. Fedora GNOME ships one; if it is missing, the app shows the URL so the user can copy it.

### Confirmation

T-PLAT-2 and T-PLAT-3 (`cargo xtask lint`), T-PLAT-5 (case-insensitive path test), W3-05 manual check on the owner's Fedora machine (open URL, keychain round trip, window renders with the fix applied).

## Pros and Cons of the Options

### Platform crate

* Good, because it is auditable and testable in one place.

### Scattered cfg

* Bad, because I-13 cannot be checked and per-OS bugs hide.

### opener and open

* Bad, because they spawn `xdg-open` and its equivalents, violating I-13.

## More Information

BRIEF_AUDIT R-1, R-12; Tauri Linux prerequisites (Fedora: `webkit2gtk4.1-devel`, `openssl-devel`, `curl`, `wget`, `file`, `libappindicator-gtk3-devel`, `librsvg2-devel`, `libxdo-devel`, plus the `c-development` group).
