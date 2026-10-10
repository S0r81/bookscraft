---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, api-engineer, security-reviewer
---

# MCP surface: read and draft tools only, enforced by actor type and scopes

## Context and Problem Statement

BooksCraft is "agent-ready" (brief §2.9 and §8). I-10: AI and agent actions create drafts only; posting a draft requires an audited human approval. How is the MCP server shaped so no model can post?

## Decision Drivers

* No path from an agent to a posted entry.
* Bring your own model; works locally and against a server.
* The same permissions as the HTTP API (one matrix).

## Considered Options

* rmcp server exposing read tools and draft-creating tools, with agent tokens limited to `books:read`, `reports:read` and `drafts:write`
* Full read/write tools gated by confirmation prompts
* No MCP; agents use the HTTP API

## Decision Outcome

Chosen option: the first one.

* Tools are listed in [API.md](../architecture/API.md) §8.
* Transports: stdio and streamable HTTP (`/mcp`).
* Locally, the MCP process runs as the desktop principal with `actor_type = agent`.
* Agent tokens can never receive `books:write`.
* Services refuse post, approve, void and other protected operations for any agent principal, wherever the call comes from (403 `auth.agent_forbidden`).
* Approval is a human `POST .../documents/{id}/approve`, audited as `approval.approve`.

### Consequences

* Good, because I-10 is enforced in three places: the tool list, the token scopes, and the service and permission check.
* Good, because agents still get useful work: drafts, categorization proposals, report questions.
* Bad, because bulk agent workflows need a human approval step. That is intended.
* MVP placement: W5-02 is a late-MVP stretch. If it slips to v1, the I-10 enforcement in services (W1-05, T-API-1) still ships in MVP.

### Confirmation

T-MCP-1 (tool list snapshot), T-ID-2 (agent token scope validation), T-API-1 (403 on every protected endpoint), spine S28 (agent draft, post refused, owner approval).

## Pros and Cons of the Options

### Read and draft tools

* Good, because they are safe by construction.

### Write tools with prompts

* Bad, because a prompt can be bypassed by a misbehaving client, which violates I-10.

### No MCP

* Bad, because it loses the agent-ready positioning.

## More Information

rmcp 3.4.1 features verified on docs.rs (2026-10-10).
