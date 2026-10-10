---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, api-engineer, security-reviewer
---

# Authentication and roles: desktop principal, local accounts in MVP, OIDC in v1, fixed roles

## Context and Problem Statement

The brief wants multi-user access with basic roles in MVP and an accountant workspace in v1. Desktop solo has one OS user. Server mode needs logins, tokens and roles. What exactly ships in MVP? (G-18, G-19, C-10)

## Decision Drivers

* Desktop must work offline with no login friction.
* Server mode needs safe local accounts before OIDC exists.
* One permission matrix for HTTP, MCP and CLI.
* No tier gating: unlimited users (I-9).

## Considered Options

* Desktop principal (optional app password); server local accounts (argon2id) with sessions and bearer tokens; fixed roles owner, admin, accountant, bookkeeper, viewer; OIDC and custom roles in v1
* OIDC only
* Per-record permissions in MVP

## Decision Outcome

Chosen option: the first one (owner default, Q-7).

* `domain::auth::permits` holds the role × permission matrix ([API.md](../architecture/API.md) §6).
* Tokens carry scopes and an actor type (api or agent).
* Installation admins (`user.is_admin`) create companies and users.
* Sessions are SHA-256-hashed tokens in an HttpOnly, Secure, `SameSite=Strict` cookie, plus a client header for CSRF.
* Login is rate-limited.

### Consequences

* Good, because server mode is usable for small teams and accountants in MVP.
* Bad, because there is no SSO until v1, and custom roles and record-level scopes come in v1.

### Confirmation

T-ID-1 (exhaustive permission matrix table test), T-ID-2 (agent scopes), T-ID-3 (password hashing parameters and timing-safe compare), security review of W1-03 in Weave 1.

## Pros and Cons of the Options

### Local accounts now, OIDC later

* Good, because it works for self-hosters on day one.

### OIDC only

* Bad, because it needs an identity provider before the first login.

### Per-record permissions

* Bad, because it is complex. It is v1 with the accountant workspace.

## More Information

ARCHITECTURE §13; schema-system.sql `user`, `membership`, `session`, `api_token`.
