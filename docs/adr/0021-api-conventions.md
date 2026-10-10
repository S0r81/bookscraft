---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, api-engineer
---

# API conventions: REST + JSON, decimal-string money, idempotency keys, ETags, cursor pages, RFC 9457 errors

## Context and Problem Statement

The HTTP API is used by our UI, integrations, the CLI and indirectly by MCP. Once published it is expensive to change. Which conventions?

## Decision Drivers

* Exact money on the wire.
* Safe retries from flaky networks and agents.
* Lost-update protection (QBO's SyncToken analogue).
* Machine-readable errors with stable codes.

## Considered Options

* REST + JSON; money as `{"amount": "<decimal string>", "currency": "<ISO>"}`; `Idempotency-Key`; `ETag`/`If-Match` with integer versions; cursor pagination; RFC 9457 problem details with namespaced codes
* Money as integer minor units in JSON
* Offset pagination
* GraphQL

## Decision Outcome

Chosen option: the first one, specified in [API.md](../architecture/API.md) §2 to §4.

* Money strings carry exactly the currency's minor digits, and parsing is strict.
* Every state-changing `POST` needs `Idempotency-Key` (replay for 24 hours).
* Updates need `If-Match` (412 on mismatch, 428 when missing).
* Errors are `application/problem+json` with `code` = `<namespace>.<name>`.

### Consequences

* Good, because it is unambiguous for humans and machines and safe for agents to retry.
* Bad, because decimal strings need parsing on every client. `api-types` provides the type for Rust clients.

### Confirmation

Contract tests in W1-05: replay, key reuse, 412, 428, money format rejection; OpenAPI generated and checked into `docs/architecture/openapi.json` by `cargo xtask docs`. W1-05 commits the first version; afterwards each Weave regenerates it, and drift fails CI on Weave PRs (work package PRs that add routes cannot all edit the one file without conflicts).

## Pros and Cons of the Options

### Decimal strings

* Good, because they read like money and are exact.

### Integer minor units

* Good, because they are trivially exact.
* Bad, because they are easy to misread by 100× and hard to scan in logs.

### Offset pagination

* Bad, because pages are unstable under inserts.

### GraphQL

* Bad, because it is heavier for caching and idempotency semantics, and less common for small integrators.

## More Information

[RFC 9457](https://www.rfc-editor.org/rfc/rfc9457); BRIEF_AUDIT ADR register row 0021.
