---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, import-migration-engineer
---

# QBO migrator access: file paths first, the owner's own Intuit app in MVP, relay later

## Context and Problem Statement

The QBO API needs OAuth 2.0. A secondary source says production keys reject localhost redirects. The token exchange uses a client secret that cannot ship inside open-source binaries. API reads are metered. Intuit's developer terms are unreviewed (R-2). How do desktop users and self-hosters get an access token?

## Decision Drivers

* The MVP exit depends on migrating a real QBO company (the owner's pilot, Q-8).
* No secret in the binary.
* File-based paths must exist regardless (owner rule).
* Don't depend on terms nobody has read.

## Considered Options

* MVP: pluggable token source. Server mode uses the owner's own Intuit app (authorization code with PKCE, HTTPS redirect to the server). Desktop pastes tokens. v1: a stateless hosted relay, gated on a human review of Intuit's terms.
* A client secret embedded in the desktop binary
* A hosted relay in MVP
* No API path: CSV and IIF only

## Decision Outcome

Chosen option: the first one.

* `migrate::qbo` takes a `TokenSource` with two implementations: authorization-code (server) and pasted tokens.
* File-based import (CSV, interchange; IIF in v1) lands first.
* A hosted relay that holds the client secret is v1, only after the owner or a lawyer reviews Intuit's developer terms for competitive use and data migration.
* Validation is gating: month-end trial balance and per-contact aging to the cent, with residual reconstruction (MIGRATION_SPEC §6).

### Consequences

* Good, because the owner can run the pilot in MVP without a relay or an embedded secret.
* Bad, because desktop-only users without a server must obtain tokens themselves in MVP (a documented, technical step).
* Bad, because reads are metered by Intuit. The wizard estimates the request count before starting.

### Confirmation

T-MIG-7 (connector against recorded fixtures); W4-03 acceptance verifies the endpoint names, minor version and report parameters against Intuit's current docs before use; pilot checklist (W5-04).

## Pros and Cons of the Options

### Pluggable token source, relay later

* Good, because it is unblocked now and puts no secret in the code.
* Bad, because the desktop user experience is rough until the relay exists.

### Embedded secret

* Bad, because a secret in an open-source binary is public, breaks Intuit's rules and gets revoked.

### Relay in MVP

* Bad, because it means running a service and reviewing the terms before the core works.

### Files only

* Bad, because QBO cannot export IIF; QBO users would get a lossy path.

## More Information

MIGRATION_SPEC §4; BRIEF_AUDIT R-2, §7.4 (secondary sources), §7.5 (unverified items).
