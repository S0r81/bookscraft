---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect
---

# Process topology: one core, four shells, no TCP port on desktop

## Context and Problem Statement

The desktop app, server (HTTP API plus web UI), CLI and MCP server must all sit over one core. What runs in-process and what runs over HTTP in each mode?

## Decision Drivers

* The UI must be identical in desktop and browser.
* Desktop should not expose a network listener that any local process could call.
* The CLI and MCP must work without a server for solo users.
* One owner per company file (ADR-0003).

## Considered Options

* Desktop routes UI requests through a Tauri custom protocol into the in-process axum router; the server serves the same router over HTTPS
* Desktop runs a localhost HTTP server on a TCP port
* The desktop UI calls Rust directly over Tauri IPC commands, while the web build uses HTTP

## Decision Outcome

Chosen option: **custom protocol into the in-process router**.

* The desktop serves the UI and `/api/v1` from `bookscraft://localhost/` (`http://bookscraft.localhost/` on Windows), calling `api::router` with `tower::ServiceExt::oneshot`.
* `bookscraft serve` runs the same router over HTTP(S), plus MCP at `/mcp`.
* The CLI and MCP run in-process on a company file (exclusive lock) or as HTTP clients of a server.

The full matrix is in [ARCHITECTURE.md](../architecture/ARCHITECTURE.md) §5.

### Consequences

* Good, because there is one API path in all modes and the UI code has no mode switches.
* Good, because no port opens on the desktop, and other local processes cannot reach the API.
* Bad, because custom protocol responses are buffered: no SSE or WebSockets in MVP. Long operations are jobs the UI polls.
* Bad, because while the desktop app holds a file, `bookscraft --company <file>` is refused (`store.company_locked`). v1 adds a local socket so the CLI and MCP can attach to a running desktop app.

### Confirmation

* Spike W0-06, criterion 8: the same bundle hash works through the custom protocol and in a browser.
* W3-05 acceptance: the desktop app answers `/api/v1/health` through the custom protocol and opens no listening socket (checked by listing the process's sockets in the test).

## Pros and Cons of the Options

### Custom protocol

* Good, because it is same-origin, has no port and needs no CORS.
* Bad, because responses are buffered, and the Windows origin differs (handled with relative URLs).

### Localhost server

* Good, because it is streaming-capable.
* Bad, because any local process can call it (it needs a token handshake), and firewalls prompt on Windows.

### IPC commands on desktop, HTTP on web

* Good, because IPC is a little faster.
* Bad, because there are two API surfaces to keep identical: the desktop and web UIs would diverge.

## More Information

BRIEF_AUDIT OV-6, OV-7; Tauri `register_asynchronous_uri_scheme_protocol` (docs.rs, tauri 2.12).
