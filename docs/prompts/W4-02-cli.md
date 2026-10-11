# W4-02: Server composition and CLI

## Goal

Build the `bookscraft` binary in `crates/cli`: `serve` (the API, the web UI and `/mcp` over HTTPS or HTTP from one process) and every command of API.md §9, working locally on a company file or remotely against a server, with exact exit codes and no secrets on the command line.

## Wave and concurrency

- Wave 4, batch B (with W4-01). Paths do not overlap.
- Agent: `api-engineer`.
- Timebox: two sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/cli/src/**`, `crates/cli/tests/**`
- `docs/coordination/CCR/CCR-W4-02-*.md`, `docs/coordination/handoffs/W4-02.md`

Read-only: everything else, including `crates/app`, `crates/api` and `crates/mcp` (use them as they are).

## Read first

1. `CLAUDE.md` and `.claude/agents/api-engineer.md`.
2. `docs/architecture/API.md` §1, §8 (MCP transports) and §9 (CLI).
3. `docs/architecture/ARCHITECTURE.md` §5 (topology, file lock), §12 (jobs: the CLI runs jobs inline), §13 (TLS, limits), §14 (logs).
4. `docs/architecture/MIGRATION_SPEC.md` §7 (the CSV mapping file).
5. ADR-0004, 0023 and 0024.

## Preconditions

| Precondition | Check |
|---|---|
| Weave 3 is merged | `git log origin/main --format=%s \| grep -q '^Weave 3: '` |

## Scope in/out

In:

- **Entry point:** `bookscraft_cli::run(args, io) -> ExitCode` as a library function, with `main` a thin wrapper; all tests call `run` with in-memory input and output (tests never start processes, D-5).
- **`serve`:** reads a TOML config file (bind address, data directory, TLS certificate and key paths, UI directory or embedded UI, key-encryption key source; SMTP is an installation setting set through the API, not the file); builds `Infra` with `app::infra` and `app::server_secrets` (the key-encryption key from the config file or `BOOKSCRAFT_KEK`), then the services with `app::compose`; serves `api::router` plus `mcp::http_router(services)` at `/mcp` with `axum-server` and rustls when TLS is configured (HSTS on), plain HTTP otherwise (behind a reverse proxy); starts the job runner; logs to stderr, as JSON with `--log-format json`; shuts down gracefully.
- **Commands:** `mcp` (requires `--company`, with `--server` a usage error; calls `mcp::serve_stdio`; while that returns `api.not_implemented` it reports that the MCP server is not available and exits 1; test only this error mapping, not the stub itself, because W5-02 replaces it), `company create|list|info`, `import qbo|csv|interchange|ofx` (`iif` prints that it arrives in v1 and exits 2), `export`, `verify`, `backup`, `report`, `user add|list|disable|reset-password`, `token create|list|revoke`.
- **Modes:** `--company <file>` composes in-process and holds the file's lock (`store.company_locked` gives exit 4); `--server <url>` calls the HTTP API with a token from `--token-file` or `BOOKSCRAFT_TOKEN`. Passwords are prompted; no secret is accepted as a plain flag.
- **Output:** `table` (default on a terminal), `json` (the HTTP DTOs), `csv` (reports and lists).
- **Exit codes:** 0 success, 1 unexpected, 2 usage, 3 domain validation, 4 conflict or locked, 5 not found, 6 permission denied.
- **Jobs inline:** commands that start jobs (import, export, backup, verify) run them to completion in-process and print the result.

Out: the MCP tools themselves (W5-02), packaging (W5-01), a local socket to a running desktop app (v1).

## Tasks

1. `run` and argument parsing; output formats; exit-code mapping.
2. Local mode commands.
3. Remote mode (HTTP client).
4. `serve` with configuration, TLS and graceful shutdown.
5. Tests.

## Invariants touched

| Invariant | Test |
|---|---|
| I-6 | local commands act as the desktop principal with `via = cli`; their audit events show it |
| I-10 | `token create --actor agent` with `books:write` fails (identity rule, exit 6 or 3 as mapped) |
| I-13 | paths taken from arguments and the platform crate only; no shelling out |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | Exit codes follow API.md §9 | tests: success 0; unknown flag 2; a validation error 3; a locked company file 4 (the test holds the lock first); a missing document 5; a viewer's token writing 6 |
| AC-2 | Secrets never come from plain flags | tests: `--token` and `--password` are rejected as unknown; the token is read from `--token-file` and from `BOOKSCRAFT_TOKEN` |
| AC-3 | Local commands work end to end | tests: `company create` with the agency template, `import ofx` of the spine statement (9 new lines, then 0), `report trial-balance --format csv`, `verify`, `backup` |
| AC-4 | Remote mode works | test: start `serve` in-process on `127.0.0.1:0`, then run `company list` and `report trial-balance` with `--server` and a token file |
| AC-5 | `serve` serves the UI, the API and `/mcp` | test: `/` returns the UI host page, `/api/v1/health` returns 200, `/mcp` is routed to the MCP router (any status except 404, so the test still passes once W5-02 replaces the 501 stub) |
| AC-6 | Jobs run inline | test: `export --format interchange --out <temp>` writes a bundle that validates |
| AC-7 | Audit shows the CLI | test: a local `company create` appends events with `via = cli` |
| AC-8 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W4-02` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-cli --all-targets -- -D warnings
cargo test --locked -p bookscraft-cli
cargo build --locked -p bookscraft-cli --release
cargo xtask lint
cargo xtask spine
cargo xtask scope W4-02
```

## Deliverables

- Branch: `wp/W4-02-cli`
- PR title: `W4-02: bookscraft serve and CLI`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work (for example a change to `api::router`'s signature or to `app`).
- A command in API.md §9 has no service operation behind it: raise a CCR.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
