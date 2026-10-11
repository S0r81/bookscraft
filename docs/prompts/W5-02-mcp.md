# W5-02: MCP server (MVP stretch)

## Goal

Implement the MCP server in `crates/mcp`: the read and draft tools of API.md §8 over stdio (`mcp::serve_stdio`) and streamable HTTP at `/mcp` (`mcp::http_router`), with scopes, company resolution and the agent rule enforced so that no tool can post, approve, void or move money.

## Wave and concurrency

- Wave 5, batch B (stretch; runs beside batch A, since its paths overlap nobody's). If it is not green when Weave 5 starts, the owner may defer it to v1; the agent rule ships regardless (ADR-0022).
- Agent: `api-engineer`. A `security-reviewer` pass is required in Weave 5.
- Timebox: two sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/mcp/src/**`, `crates/mcp/tests/**`
- `docs/coordination/CCR/CCR-W5-02-*.md`, `docs/coordination/handoffs/W5-02.md`

Read-only: everything else, including `crates/cli` (it already calls `mcp::serve_stdio` and mounts `mcp::http_router`) and `crates/mcp/Cargo.toml`.

## Read first

1. `CLAUDE.md` and `.claude/agents/api-engineer.md`.
2. `docs/architecture/API.md` §6 (roles, permissions, scopes, the agent rule) and §8 (the MCP surface, in full).
3. ADR-0022 (MCP surface) and ADR-0019 (rmcp 3.4.1 and its features).
4. `docs/architecture/ARCHITECTURE.md` §3 (D-8: `mcp` reaches services only through `domain::ports`), §5 (topology: stdio and HTTP columns), §13 (security).
5. `docs/architecture/LEDGER_SPEC.md` §13, row I-10 (T-MCP-1).
6. The merged `domain::ports`, `domain::auth`, the `Authenticator`, and `crates/cli`'s use of the two entry points.
7. rmcp 3.4.1 on docs.rs: server handler, tool macros, stdio transport, streamable HTTP server.

## Preconditions

| Precondition | Check |
|---|---|
| Weave 4 is merged | `git log origin/main --format=%s \| grep -q '^Weave 4: '` |
| The entry points exist as stubs | `git grep -q 'fn serve_stdio' origin/main -- crates/mcp/src && git grep -q 'fn http_router' origin/main -- crates/mcp/src` |

## Scope in/out

In:

- **Tools:** exactly the tools of API.md §8, with input schemas from `schemars` and the scope each requires; every tool calls a `domain::ports` method inside `spawn_blocking` with a `Ctx` whose `via` is `mcp`; results are the JSON of the domain read model plus a one-line text summary; draft-creating tools return the draft and the UI path of the approvals page (`/c/<company_id>/approvals`).
- **Rules:** a missing scope gives `auth.scope_missing`; `update_draft` and `delete_draft` act only on drafts the same principal created (the services' rule); `propose_bank_categorization` creates a draft through the banking service's add action, which drafts for an agent; any service refusal is returned as a tool error carrying the problem-details code (`auth.agent_forbidden` included); a tool name outside the list gives `mcp.tool_not_permitted`.
- **Company:** stdio uses the company id passed to `serve_stdio`; on HTTP, a token bound to one company uses it, otherwise each tool requires `company_id` (`validation.required`).
- **stdio:** `serve_stdio(services, company_id)` serves rmcp over stdin and stdout as the desktop principal with actor type `agent` and the scopes `books:read`, `reports:read`, `drafts:write`.
- **HTTP:** `http_router(services)` serves rmcp's streamable HTTP service at `/mcp`; the bearer token is resolved by the `Authenticator`; no token gives 401 `auth.required`; a principal whose actor type is not `agent` gives 403 `auth.forbidden`.
- **Tests** run in-process without starting processes (D-5): the HTTP router through `tower::ServiceExt::oneshot` with JSON-RPC `initialize`, `tools/list` and `tools/call`, and the tool handlers directly for the stdio principal.

Out: resources and prompts (none in MVP), a stdio-to-server bridge (remote agents use `/mcp`), new service operations (CCR), changes to the CLI.

## Tasks

1. Server handler and the tool table; schemas; text summaries.
2. Principal, scope and company resolution for both transports.
3. Tools, one module per area (books, documents, banking, reports, drafts).
4. `serve_stdio` and `http_router`.
5. Tests, including T-MCP-1.

## Invariants touched

| Invariant | Test |
|---|---|
| I-10 | T-MCP-1: the tool-list snapshot, plus the name-set check against API.md §8; an agent's draft cannot be posted through any tool, and posting it through the services as the agent returns `auth.agent_forbidden` |
| I-6 | drafts created through MCP carry actor type `agent` and `via = mcp` in their audit events |
| I-11 | no tool moves money: the name set has no payment, refund, deposit or transfer tool, and a bank-line proposal is only a draft |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | T-MCP-1: the tool list is exactly API.md §8's | an insta snapshot of `tools/list` (names, descriptions, input schemas, scopes), and a test that parses the tool table in `docs/architecture/API.md` §8 and compares the name sets |
| AC-2 | Scopes are enforced | tests: a token with only `books:read` can call `list_accounts` and gets `auth.scope_missing` from `create_draft_invoice`; `run_report` needs `reports:read` |
| AC-3 | Agents only draft | test: `create_draft_invoice` creates a document with status `draft`, created by actor type `agent` with `via = mcp` (audit checked with `test_support::assert_audited`); posting it as the agent through the services fails with `auth.agent_forbidden`; the owner's approve posts it |
| AC-4 | Drafts belong to their creator | test: `update_draft` and `delete_draft` on a draft created by another token are refused, and the draft is unchanged |
| AC-5 | HTTP authentication | tests: no token 401 `auth.required`; a user's session or an `api` token 403 `auth.forbidden`; an agent token lists the tools |
| AC-6 | Company resolution | tests: a company-bound token needs no `company_id`; an unbound token without it gets `validation.required` |
| AC-7 | The stdio principal is an agent | test through the stdio tool handlers: a created draft's audit event has actor type `agent` |
| AC-8 | Nothing secret leaks | test: tool results and errors for a company with SMTP and bank-feed credentials contain no credential value (unique fixture strings searched in the output) |
| AC-9 | The CLI and server keep working | `cargo test --locked -p bookscraft-cli` passes with this crate implemented |
| AC-10 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W5-02` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-mcp --all-targets -- -D warnings
cargo test --locked -p bookscraft-mcp
cargo test --locked -p bookscraft-cli
cargo xtask lint
cargo xtask spine
cargo xtask scope W5-02
```

## Deliverables

- Branch: `wp/W5-02-mcp`
- PR title: `W5-02: MCP server with read and draft tools`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work (a missing service operation, an rmcp feature that is not enabled, a CLI change).
- A tool could post, approve or void anything, create a payment or refund, create a deposit or transfer other than as a bank-line proposal draft, or reach locks, reconciliation, imports, exports, settings, users, tokens, bank feeds or secrets: stop; that breaks I-10 or I-11.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
