# Prompts index

Every work package (WP) has one prompt here. A session starts it with `/start-wp <WP>`; a Weave starts with `/weave <wave>`. The prompt is the contract for that session: it says what to build, which paths it may change, how success is measured and when to stop.

## Prompt format

Every prompt has exactly these sections, in this order:

1. **Goal**: one sentence.
2. **Wave and concurrency**: wave, order or batch, what runs beside it, agent role, timebox.
3. **Owned paths (may modify) / Read-only paths**: the WP's row in [OWNERSHIP.md](../coordination/OWNERSHIP.md), plus its own CCR and handoff files.
4. **Read first**: files to read in full before editing.
5. **Preconditions**: each with a command that checks it against `origin/main`.
6. **Scope in/out.**
7. **Tasks.**
8. **Invariants touched**: with the test ids from LEDGER_SPEC §13.
9. **Acceptance criteria**: each one failable, with how it is checked.
10. **Verify**: the exact commands, all of which must pass.
11. **Deliverables**: branch and PR title.
12. **Stop conditions**: always including "needing to touch an unowned path means raise a CCR and stop that line of work".

A merged WP is recognized by its squash commit title on `main`, which starts with `<WP>: `. Only the Weave pull request that closes wave `n` is titled `Weave <n>: …`; any other Weave pull request in that wave (a contract PR for blocking CCRs, or an interim Wave 0 merge) is titled `Weave <n> (interim): …`. Preconditions use these titles: `git log origin/main --format=%s | grep -q '^W0-02: '`, or `grep -q '^Weave 1: '` for a closed wave.

## All prompts

| WP | Wave | Title | Agent | Depends on (merged) | Prompt |
|---|---|---|---|---|---|
| W0-01 | 0 | Workspace bootstrap, toolchain, xtask, CI matrix | platform-release-engineer | architecture PR | [W0-01-workspace.md](W0-01-workspace.md) |
| W0-02 | 0 | Contracts: money, domain, api-types | lead-architect | W0-01 | [W0-02-contracts.md](W0-02-contracts.md) |
| W0-05 | 0 | Ledger core and posting framework | ledger-engineer | W0-02 | [W0-05-ledger.md](W0-05-ledger.md) |
| W0-04 | 0 | Storage engine and migration framework | storage-engineer | W0-05 | [W0-04-store.md](W0-04-store.md) |
| W0-03 | 0 | Test harness and scenario spine | qa-verifier | W0-04 | [W0-03-spine.md](W0-03-spine.md) |
| W0-06 | 0 | UI framework spike (timeboxed) | ui-engineer | W0-01 | [W0-06-ui-spike.md](W0-06-ui-spike.md) |
| W0-W | 0 | Weave 0 | lead-architect | each Wave 0 PR as it turns green | [W0-W-weave.md](W0-W-weave.md) |
| W1-01 | 1 | Posting rules for every MVP document type | ledger-engineer | Weave 0 | [W1-01-posting-rules.md](W1-01-posting-rules.md) |
| W1-02 | 1 | Books service | ledger-engineer | Weave 0 | [W1-02-books.md](W1-02-books.md) |
| W1-03 | 1 | Identity | api-engineer | Weave 0 | [W1-03-identity.md](W1-03-identity.md) |
| W1-04 | 1 | Interchange and OFX libraries | import-migration-engineer | Weave 0 | [W1-04-formats.md](W1-04-formats.md) |
| W1-05 | 1 | API framework, composition root, company, identity and books routes | api-engineer | Weave 0 | [W1-05-api.md](W1-05-api.md) |
| W1-W | 1 | Weave 1 | lead-architect | W1-01..W1-05 PRs green | [W1-W-weave.md](W1-W-weave.md) |
| W2-01 | 2 | Sales service and routes | ledger-engineer | Weave 1 | [W2-01-sales.md](W2-01-sales.md) |
| W2-02 | 2 | Purchases service and routes | ledger-engineer | Weave 1 | [W2-02-purchases.md](W2-02-purchases.md) |
| W2-03 | 2 | Banking: deposits, transfers, statement import, review, rules, reconciliation | bank-feeds-engineer | Weave 1 | [W2-03-banking.md](W2-03-banking.md) |
| W2-04 | 2 | Reports engine and routes | ledger-engineer | Weave 1 | [W2-04-reports.md](W2-04-reports.md) |
| W2-05 | 2 | UI foundation, books, settings and session screens | ui-engineer | Weave 1; ADR-0002 accepted | [W2-05-ui-foundation.md](W2-05-ui-foundation.md) |
| W2-W | 2 | Weave 2 | lead-architect | W2-01..W2-05 PRs green | [W2-W-weave.md](W2-W-weave.md) |
| W3-01 | 3 | UI: sales screens | ui-engineer | Weave 2 | [W3-01-ui-sales.md](W3-01-ui-sales.md) |
| W3-02 | 3 | UI: purchases and banking screens | ui-engineer | Weave 2 | [W3-02-ui-purchases-banking.md](W3-02-ui-purchases-banking.md) |
| W3-03 | 3 | QBO mapper (MIT) | import-migration-engineer | Weave 2 | [W3-03-qbo-mapper.md](W3-03-qbo-mapper.md) |
| W3-04 | 3 | Migration pipeline, CSV lists, parity validation, rollback, export | import-migration-engineer | Weave 2 | [W3-04-migrate.md](W3-04-migrate.md) |
| W3-05 | 3 | Platform services and desktop shell | platform-release-engineer | Weave 2 | [W3-05-desktop.md](W3-05-desktop.md) |
| W3-W | 3 | Weave 3 | lead-architect | W3-01..W3-05 PRs green | [W3-W-weave.md](W3-W-weave.md) |
| W4-01 | 4 | UI: reports, close, audit, migration wizard | ui-engineer | Weave 3 | [W4-01-ui-reports-close.md](W4-01-ui-reports-close.md) |
| W4-02 | 4 | Server composition and CLI | api-engineer | Weave 3 | [W4-02-cli.md](W4-02-cli.md) |
| W4-03 | 4 | QBO connector | import-migration-engineer | Weave 3 | [W4-03-qbo-connector.md](W4-03-qbo-connector.md) |
| W4-04 | 4 | Render: PDF, preview, email | api-engineer | Weave 3 | [W4-04-render.md](W4-04-render.md) |
| W4-05 | 4 | Bank feeds: SimpleFIN and credential storage | bank-feeds-engineer | Weave 3 | [W4-05-bank-feeds.md](W4-05-bank-feeds.md) |
| W4-W | 4 | Weave 4 | lead-architect | W4-01..W4-05 PRs green | [W4-W-weave.md](W4-W-weave.md) |
| W5-01 | 5 | Linux packaging and release workflow | platform-release-engineer | Weave 4 | [W5-01-packaging.md](W5-01-packaging.md) |
| W5-02 | 5 | MCP server (MVP stretch) | api-engineer | Weave 4 | [W5-02-mcp.md](W5-02-mcp.md) |
| W5-03 | 5 | UI: print, email, polish, accessibility pass | ui-engineer | Weave 4 | [W5-03-ui-print-polish.md](W5-03-ui-print-polish.md) |
| W5-04 | 5 | End-to-end suite, pilot runbook, release checklist | qa-verifier | Weave 4 | [W5-04-e2e-pilot.md](W5-04-e2e-pilot.md) |
| W5-W | 5 | Weave 5 and the MVP release | lead-architect | W5-01, W5-03, W5-04 PRs green (W5-02 may be deferred) | [W5-W-weave.md](W5-W-weave.md) |

## Batches and merge order

Batches assume 3 concurrent sessions (decision Q-3). With fewer, launch in the order listed. Work packages of one wave never share owned paths (checked by `cargo xtask lint`), so any subset can run at once.

| Wave | Batch A (start first) | Batch B | Merge order in the Weave |
|---|---|---|---|
| 0 | W0-01, then W0-02 with W0-06 beside it, then W0-05, W0-04, W0-03 | — | W0-01, W0-02, W0-05, W0-04, W0-03; W0-06 whenever ready |
| 1 | W1-01, W1-02, W1-05 | W1-03, W1-04 | W1-04, W1-01, W1-02, W1-03, W1-05 |
| 2 | W2-01, W2-02, W2-03 | W2-04, W2-05 | W2-04, W2-01, W2-02, W2-03, W2-05 |
| 3 | W3-03, W3-04, W3-05 | W3-01, W3-02 | W3-03, W3-04, W3-05, W3-01, W3-02 |
| 4 | W4-03, W4-04, W4-05 | W4-01, W4-02 | W4-04, W4-05, W4-03, W4-02, W4-01 |
| 5 | W5-01, W5-03, W5-04 | W5-02 (stretch) | W5-02 (if ready), W5-01, W5-03, W5-04 |

## Scenario spine plan

| After | Passed | Failed | Pending |
|---|---|---|---|
| Weave 0 | 0 | 0 | 31 |
| Weave 1 | 2 | 0 | 29 |
| Weave 2 | 31 | 0 | 0 |
| Weaves 3, 4, 5 | 31 | 0 | 0 |

Between Weaves, a merge may move steps from pending to passed; no merge may leave a failed step. Details: [ROADMAP §4](../roadmap/ROADMAP.md).

## Weave checklist

Every Weave prompt's acceptance criteria include these, in addition to its own:

1. Every WP PR of the wave is merged or deferred, with the reason in BOARD.md.
2. Zero files changed outside owned paths in the merged PRs: each PR's `cargo xtask scope` output is clean.
3. Every PR had a fresh `qa-verifier` pass, and the work packages listed in `lead-architect.md` a `security-reviewer` pass; their verdicts are linked in the Weave PR.
4. Every CCR raised in the wave has a filled-in Decision table. Any accepted CCR that changes a decision has a new or updated ADR (numbers assigned only in a Weave).
5. Schema changes (if any) are a new migration plus the matching `schema.sql` change in the same commit.
6. `cargo xtask ci` passes on the Weave branch after merging `origin/main`; CI is green on all three OSes; the spine counts match the plan above.
7. BOARD.md, OWNERSHIP.md (if paths moved), specs, generated docs (`cargo xtask docs --check` passes) and the next wave's prompts are up to date.
8. Branch protection is still on with the ten required checks.
