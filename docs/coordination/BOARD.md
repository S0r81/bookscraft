# Board

One row per work package (WP). Only lead-architect sessions edit this file: when they open a wave (ready) and during the Weave (in review, merged, blocked). Builders report progress through their PR. `/status` combines this board with live PR and CI state.

States: `planned` → `ready` (dependencies merged) → `in_progress` (session started) → `in_review` (PR open, checks green) → `merged`. A WP can also be `blocked` (CCR or failure, reason in Notes).

| WP | Wave | Title | Agent | Branch | PR | State | Notes |
|---|---|---|---|---|---|---|---|
| W0-01 | 0 | Workspace bootstrap, toolchain, xtask, CI matrix | platform-release-engineer | wp/W0-01-workspace | — | ready | Wave 0 order 1. Needs the merged architecture PR, the cloud environment and the sign-off identity (playbook §1–§2) |
| W0-02 | 0 | Contracts: money, domain, api-types | lead-architect | wp/W0-02-contracts | — | planned | Wave 0 order 2: after W0-01 is merged |
| W0-03 | 0 | Test harness and scenario spine | qa-verifier | wp/W0-03-spine | — | planned | Wave 0 order 5: after W0-04 is merged |
| W0-04 | 0 | Storage engine and migration framework | storage-engineer | wp/W0-04-store | — | planned | Wave 0 order 4: after W0-05 is merged |
| W0-05 | 0 | Ledger core and posting framework | ledger-engineer | wp/W0-05-ledger | — | planned | Wave 0 order 3: after W0-02 is merged |
| W0-06 | 0 | UI framework spike (timeboxed) | ui-engineer | wp/W0-06-ui-spike | — | planned | Runs beside W0-02..W0-05 once W0-01 is merged; owner verifies on Fedora |
| W0-W | 0 | Weave 0 | lead-architect | weave/W0 | — | planned | Merges each Wave 0 PR as it turns green, then closes the wave after W0-01..W0-06 |
| W1-01 | 1 | Posting rules for every MVP document type | ledger-engineer | wp/W1-01-posting-rules | — | planned | |
| W1-02 | 1 | Books service | ledger-engineer | wp/W1-02-books | — | planned | |
| W1-03 | 1 | Identity | api-engineer | wp/W1-03-identity | — | planned | security review in Weave 1 |
| W1-04 | 1 | Interchange, OFX and IIF libraries | import-migration-engineer | wp/W1-04-formats | — | planned | |
| W1-05 | 1 | API framework, composition root, company, identity and books routes | api-engineer | wp/W1-05-api | — | planned | |
| W1-W | 1 | Weave 1 | lead-architect | weave/W1 | — | planned | |
| W2-01 | 2 | Sales service and routes | ledger-engineer | wp/W2-01-sales | — | planned | |
| W2-02 | 2 | Purchases service and routes | ledger-engineer | wp/W2-02-purchases | — | planned | |
| W2-03 | 2 | Banking: deposits, transfers, statement import, review, rules, reconciliation | bank-feeds-engineer | wp/W2-03-banking | — | planned | |
| W2-04 | 2 | Reports engine and routes | ledger-engineer | wp/W2-04-reports | — | planned | |
| W2-05 | 2 | UI foundation, books, settings and session screens | ui-engineer | wp/W2-05-ui-foundation | — | planned | needs ADR-0002 accepted |
| W2-W | 2 | Weave 2 | lead-architect | weave/W2 | — | planned | |
| W3-01 | 3 | UI: sales screens | ui-engineer | wp/W3-01-ui-sales | — | planned | |
| W3-02 | 3 | UI: purchases and banking screens | ui-engineer | wp/W3-02-ui-purchases-banking | — | planned | |
| W3-03 | 3 | QBO mapper (MIT) | import-migration-engineer | wp/W3-03-qbo-mapper | — | planned | |
| W3-04 | 3 | Migration pipeline, CSV lists, parity validation, rollback, export | import-migration-engineer | wp/W3-04-migrate | — | planned | |
| W3-05 | 3 | Platform services and desktop shell | platform-release-engineer | wp/W3-05-desktop | — | planned | owner verifies on Fedora |
| W3-W | 3 | Weave 3 | lead-architect | weave/W3 | — | planned | |
| W4-01 | 4 | UI: reports, close, audit, migration wizard | ui-engineer | wp/W4-01-ui-reports-close | — | planned | |
| W4-02 | 4 | Server composition and CLI | api-engineer | wp/W4-02-cli | — | planned | |
| W4-03 | 4 | QBO connector | import-migration-engineer | wp/W4-03-qbo-connector | — | planned | needs the owner's Intuit app for live checks |
| W4-04 | 4 | Render: PDF, preview, email | api-engineer | wp/W4-04-render | — | planned | |
| W4-05 | 4 | Bank feeds: SimpleFIN and credential storage | bank-feeds-engineer | wp/W4-05-bank-feeds | — | planned | security review in Weave 4 |
| W4-W | 4 | Weave 4 | lead-architect | weave/W4 | — | planned | |
| W5-01 | 5 | Linux packaging and release workflow | platform-release-engineer | wp/W5-01-packaging | — | planned | |
| W5-02 | 5 | MCP server (MVP stretch) | api-engineer | wp/W5-02-mcp | — | planned | may slip to v1 |
| W5-03 | 5 | UI: print, email, polish, accessibility pass | ui-engineer | wp/W5-03-ui-print-polish | — | planned | |
| W5-04 | 5 | End-to-end suite, pilot runbook, release checklist | qa-verifier | wp/W5-04-e2e-pilot | — | planned | |
| W5-W | 5 | Weave 5 and MVP release candidate | lead-architect | weave/W5 | — | planned | full security review |
