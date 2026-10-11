---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect
---

# Licensing: AGPL-3.0-only application, MIT libraries, DCO

## Context and Problem Statement

The owner locked the licensing model (I-12): the application is AGPL-3.0, and the money, ledger core, IIF and OFX parsers and QBO mapper are MIT. Open questions:

* "only" or "or later"?
* How do the MIT crates avoid depending on AGPL code?
* How are contributions accepted?

## Decision Drivers

* Prevent closed hosted forks of the application (AGPL).
* Maximize reuse of the format and accounting libraries (MIT).
* A trustworthy, permanent license for a community project (brief §7.5).
* Mechanically enforceable.

## Considered Options

* AGPL-3.0-only app; MIT libraries plus an MIT `interchange` crate; DCO with a no-relicensing pledge
* AGPL-3.0-or-later app
* Apache-2.0 libraries
* A CLA instead of the DCO

## Decision Outcome

Chosen option:

* **AGPL-3.0-only** for the application (owner default, Q-6).
* **MIT** for `money`, `ledger`, `interchange`, `iif`, `ofx` and `qbo`.

`interchange` is added (C-7) so the QBO mapper and IIF code produce an MIT data model instead of AGPL domain types.

Contributions use the **DCO**. The sign-off is carried in the PR description, which becomes the squash commit message. The project publishes a **no-relicensing pledge** in CONTRIBUTING.md.

### Consequences

* Good, because the libraries are reusable by anyone, and the app stays copyleft.
* Good, because a DCO plus a pledge signals permanence (no CLA-enabled dual licensing).
* Bad, because "only" means moving to a future AGPL version would need every contributor's consent. That is accepted as the price of certainty; the pledge forbids relicensing anyway.
* Bad, because the MIT crates cannot use AGPL helpers. Shared code goes into an MIT crate or is duplicated.

### Confirmation

* `cargo deny check licenses` with `deny.toml` (app policy) in CI.
* `cargo xtask lint` rule D-1: an MIT crate's normal-dependency closure contains only MIT workspace crates and externals allowed by `deny-mit.toml` (MIT, Apache-2.0, BSD-2/3-Clause, ISC, Zlib, Unicode-3.0, Unlicense, CC0-1.0, MPL-2.0 excluded).
* SPDX headers in every file (D-9).
* `LICENSE` holds the AGPL-3.0 text; `LICENSES/MIT.txt` holds MIT; each crate's `license` field is set in `Cargo.toml`.

## Pros and Cons of the Options

### AGPL-3.0-only + MIT libraries + DCO

* Good, because it is clear, enforceable and community-friendly.
* Bad, because of the "only" version lock-in noted above.

### AGPL-3.0-or-later

* Good, because it is future-proof if the FSF updates the license.
* Bad, because it delegates future terms to a third party.

### Apache-2.0 libraries

* Good, because of the explicit patent grant.
* Bad, because the owner locked MIT.

### CLA

* Good, because it allows relicensing.
* Bad, because the same allowance erodes trust (Akaunting precedent, brief §7.5).

## More Information

BRIEF_AUDIT C-6, C-7, R-13. Trademark clearance of the name "BooksCraft" is the owner's call; this is not legal advice.
