# W1-05: API framework, composition root, company, identity and books routes

## Goal

Build the HTTP API framework in `crates/api` (router, middleware, problem details, idempotency, optimistic concurrency, permission checks with machine-readable OpenAPI metadata), implement the system, session, identity, company, books and generic document routes, pre-register every other area's route module, and add the job runner and HTTP wiring to `crates/app`.

## Wave and concurrency

- Wave 1, batch A (with W1-01 and W1-02). Paths do not overlap.
- Agent: `api-engineer`. A `security-reviewer` pass is required in Weave 1.
- Timebox: three sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/api/src/**`, `crates/api/tests/**`, `crates/app/src/**`, `crates/app/tests/**`, `docs/architecture/openapi.json`
- `docs/coordination/CCR/CCR-W1-05-*.md`, `docs/coordination/handoffs/W1-05.md`

Read-only: everything else. After this WP, `crates/api/src/lib.rs`, `crates/api/src/routes/mod.rs` and `crates/app/src/**` change only in Weaves, and each area module belongs to its area's work package.

## Read first

1. `CLAUDE.md` and `.claude/agents/api-engineer.md`.
2. `docs/architecture/API.md` in full.
3. `docs/architecture/ARCHITECTURE.md` §4 (ports, `Services`, data access and generic actions), §5 (topology: desktop principal, static UI), §6.1 (request flow), §7 (route modules), §12 (jobs), §13 (limits, CSRF, sessions).
4. ADR-0004, 0021, 0022, 0023, 0024.
5. `crates/domain` (`ports`, `auth`, `errors`, `OPERATIONS`) and `crates/api-types` as merged.

## Preconditions

| Precondition | Check |
|---|---|
| Weave 0 is merged | `git log origin/main --format=%s \| grep -q '^Weave 0: '` |
| Every operation id maps to a port method | `git grep -q 'OPERATIONS' origin/main -- crates/domain/src` |

## Scope in/out

In:

- **Framework:** `api::router(state: ApiState) -> axum::Router`, where `ApiState` holds `Services`, the mode (desktop or server), limits and the static UI source (a directory, or the embedded bundle with feature `embed-ui`); middleware for request ids (`X-Request-Id`), tracing without bodies or secrets, body limits (2 MB JSON, 25 MB attachments, 10 MB statement files, `api.payload_too_large`), authentication through the `Authenticator` (cookie or bearer; the desktop principal in desktop mode), the CSRF header `X-BooksCraft-Client: ui` for cookie-authenticated mutations, idempotency through `IdempotencyStore` (API.md §2: replay, `idempotency.key_reused`, `idempotency.in_progress`, `idempotency.key_required`), ETag and `If-Match` (`concurrency.version_mismatch` 412, `concurrency.if_match_required` 428), cursor pagination (max 500), problem details for every error (`DomainError` to status per API.md §3, `api.internal` with the request id for anything unexpected), strict JSON (`validation.unknown_field`, `validation.money_format`, `validation.date_format`).
- **Permissions:** every handler checks its permission with `domain::auth::permits` before calling a service. Every OpenAPI operation carries `x-bookscraft-permission` and `x-bookscraft-agent` (API.md §6); the middleware refuses an `agent` principal on any operation marked `x-bookscraft-agent: false` with 403 `auth.agent_forbidden`.
- **Routes implemented here:** API.md §5.1 (health with capabilities, session, users, tokens, account templates, jobs; not the email settings, which W4-04 serves from `routes/render.rs`), §5.2 (companies, members, period locks, backups, verify, number sequences), §5.3 (accounts, contacts, items, terms, payment methods, tax agencies, rates and codes, dimensions and values, custom fields, contact open items, attachments; not bank rules), §5.4 generic document endpoints (search, get, journal, history, post, approve, void, delete draft, approvals list) and the typed `journal-entries` and `opening-balances` endpoints. Generic post, approve, void and delete read the document type and call the owning service's port method (ARCHITECTURE §4.6).
- **Route modules pre-registered for later work packages:** `routes/sales.rs`, `purchases.rs`, `banking.rs`, `reports.rs`, `imports.rs`, `render.rs`, `feeds.rs`, each with `pub fn router() -> Router<ApiState>` and `pub fn openapi() -> utoipa::openapi::OpenApi`, empty for now; `routes/mod.rs` merges every module's router and OpenAPI document.
- **OpenAPI:** `api::openapi()`; a binary `crates/api/src/bin/openapi-json.rs` printing it; `docs/architecture/openapi.json` generated with `cargo xtask docs` and committed.
- **Static UI:** serve the UI bundle at `/` with the API at `/api/v1` from the same router (same origin for desktop and browser).
- **`app`:** the job runner (one thread per process: claim due jobs, run each as its creating principal, dispatch by `JobKind` to the owning port's `run_job` through `ports::JOB_OWNERS`, record the result or problem details; the store's queue schedules retries); `app::infra` and `app::server_secrets` exactly as ARCHITECTURE §4.5 (system clock, UUIDv7 ids and the fixed infrastructure constructors, so later work packages never edit `app`); and a constructor for `ApiState` from `Services`.

Out: sales, purchases, banking, reports, imports, render and feeds routes (their work packages fill the pre-registered modules), the CLI and `serve` command (W4-02), the desktop shell (W3-05), the MCP server (W5-02).

## Tasks

1. Framework and middleware, with contract tests against fake port implementations written inside your tests.
2. Permission metadata and the agent rule.
3. The routes listed above.
4. Area module placeholders and the merged OpenAPI document; the `openapi-json` binary; `cargo xtask docs`.
5. The job runner in `app`.

## Invariants touched

| Invariant | Test |
|---|---|
| I-10 | T-API-1: every operation marked `x-bookscraft-agent: false` returns 403 `auth.agent_forbidden` for an agent token; T-API-2: every operation has both extensions |
| I-11 | T-SCOPE-1: no OpenAPI path segment (split on `/` and `-`) or operation id part (split on `.` and `_`) is one of `payroll`, `paycheck`, `paychecks`, `payout`, `payouts`, `ach`, `wire` or `efile` |
| I-6 | mutating requests reach services that audit; the request id is passed into the audit event through `Ctx` (test with a fake service) |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | T-API-1 | test enumerates `api::openapi()` and calls every operation marked `x-bookscraft-agent: false` with an agent bearer token; every response is 403 with code `auth.agent_forbidden` |
| AC-2 | T-API-2 | test fails if any operation lacks `x-bookscraft-permission` or `x-bookscraft-agent` |
| AC-3 | T-SCOPE-1 | test over the OpenAPI paths and operation ids, matching whole words only (so `attachments` does not match `ach`) |
| AC-4 | Idempotency follows API.md §2 | contract tests: replay with `Idempotent-Replayed: true`; key reuse 422; in progress 409; missing key 400 |
| AC-5 | Optimistic concurrency | contract tests: stale `If-Match` 412; missing 428; a successful update returns the new `ETag`; an unversioned resource of API.md §2 (`PUT /…/members/{uid}`) succeeds without `If-Match` and returns no `ETag` |
| AC-6 | Errors are problem details | tests: a domain error, a validation error with field errors, an unknown field, a bad money string, an oversized body (413), and an unexpected error (500 `api.internal` with the request id, no internal detail) |
| AC-7 | Authentication and CSRF | tests: no credentials 401 `auth.required`; cookie mutation without `X-BooksCraft-Client` refused; bearer mutation accepted without it; desktop mode resolves the desktop principal |
| AC-8 | Every implemented endpoint has contract tests | each route file has tests for success, validation, permission (a viewer gets 403 on writes) and, for creates, idempotent replay |
| AC-9 | Generic post, approve and void dispatch by document type | tests with fake services check that a journal entry goes to `BooksService` and an invoice to `SalesService` |
| AC-10 | The OpenAPI document is committed and current | `cargo xtask docs --check` exits 0 |
| AC-11 | The job runner works | tests: a claimed job runs as its creator and is completed by its owning port; a failing job is rescheduled by the store; a runner restarted after a crash picks up a job left `queued`; `app::infra` builds an `Infra` from `Stores` and a fake secret store |
| AC-12 | The UI and the API share one origin | test: `/` serves `index.html` from a directory source and `/api/v1/health` answers JSON with the capability list |
| AC-13 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W1-05` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-api -p bookscraft-app --all-targets -- -D warnings
cargo test --locked -p bookscraft-api -p bookscraft-app
cargo xtask docs --check
cargo xtask lint
cargo xtask spine
cargo xtask scope W1-05
```

## Deliverables

- Branch: `wp/W1-05-api`
- PR title: `W1-05: API framework, composition root and core routes`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work (a missing DTO in `api-types`, a missing port method in `domain`).
- An endpoint in API.md cannot be expressed with the merged contracts: raise a CCR with the exact shape needed, keep a local adapter if possible.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
