# W4-04: Render: PDF, preview, email

## Goal

Implement `RenderService` in `crates/render`: deterministic Typst rendering of sales documents to PDF and to SVG preview pages, and sending them by email over SMTP as `email_send` jobs, with the routes in `crates/api/src/routes/render.rs`.

## Wave and concurrency

- Wave 4, batch A (with W4-03 and W4-05). Paths do not overlap.
- Agent: `api-engineer`. A `security-reviewer` pass is required in Weave 4 (SMTP credentials, template data).
- Timebox: two sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/render/src/**`, `crates/render/tests/**`, `crates/render/templates/**`, `crates/render/fonts/**`, `crates/api/src/routes/render.rs`
- `docs/coordination/CCR/CCR-W4-04-*.md`, `docs/coordination/handoffs/W4-04.md`

Read-only: everything else.

## Read first

1. `CLAUDE.md` and `.claude/agents/api-engineer.md`.
2. `docs/architecture/ARCHITECTURE.md` §4.5 (`render::infra::mailer`), §4.6 (data access), §10 (print and PDF), §11 (terminology), §12 (jobs, email, rendering).
3. `docs/architecture/API.md` §5.1 (email settings and test), §5.4 (`pdf`, `preview`, `send`), §6 (`installation.manage`).
4. ADR-0025 and ADR-0024.
5. `docs/architecture/LEDGER_SPEC.md` §4.1 (the INV-1002 worked example).
6. The merged `domain` render port and the document DTOs.

## Preconditions

| Precondition | Check |
|---|---|
| Weave 3 is merged | `git log origin/main --format=%s \| grep -q '^Weave 3: '` |
| The render route module is pre-registered | `git show origin/main:crates/api/src/routes/render.rs > /dev/null` |

## Scope in/out

In:

- **Typst world:** templates as data files in `crates/render/templates/` (`.typ`), a JSON data input generated from the stored document, embedded fonts (from `typst-kit`, or OFL-licensed files in `crates/render/fonts/` with their license texts), no system font scan, a fixed creation timestamp so output is reproducible.
- **Template:** one sales-document template used by invoices, estimates, sales receipts, credit memos and refund receipts (title and fields per type, company details, addresses, lines, discount, tax by rate, totals, terms and due date, memo). Wording is BooksCraft's own; layout is original.
- **Outputs:** PDF (`typst-pdf`) for download and email; SVG pages (`typst-svg`) for the in-app preview. Drafts render too (marked "Draft").
- **Email:** the installation's SMTP settings (`email.get`, `email.set`, `email.test` at `/api/v1/settings/email`, permission `installation.manage`, stored in the system file's `setting` table with the password through `SecretStore`); `render::infra::mailer` returns `render::mail::Smtp` (lettre over TLS, reading those settings at send time); `send` accepts posted documents only (drafts and voided documents get `render.not_sendable`) and enqueues an `email_send` job; `RenderService::run_job` renders the PDF, sends it as an attachment, and records `last_sent_at` with an audit event in one transaction; an SMTP failure returns `render.smtp_failed` so the store retries the job; the settings screen's test email runs through the same job kind.
- **Routes:** `GET /documents/{id}/pdf`, `GET /documents/{id}/preview`, `POST /documents/{id}/send` (API.md §5.4) and the email settings routes (API.md §5.1), all in `routes/render.rs`, with permissions and OpenAPI metadata.
- **Capabilities:** `RenderPdf`, `Email` when complete.

Out: report and statement PDFs (report screens print through the webview, ARCHITECTURE §10), the print and email UI (W5-03), provider email APIs (later).

## Tasks

1. Typst world, fonts and determinism.
2. Template and data generation.
3. PDF and SVG outputs; routes.
4. Mailer, `send`, the `email_send` job and the test email.
5. Tests.

## Invariants touched

| Invariant | Test |
|---|---|
| I-1 | amounts printed from `money` formatting of stored values, never recomputed (test: INV-1002 prints 5,097.70 with tax lines 47.50 and 15.20) |
| I-6 | `last_sent_at` changes only with an audit event (T-AUDIT-1 through `test_support::assert_audited`) |
| I-13 | no shelling out and no system fonts (lint; tests run on three OSes) |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | Rendering is deterministic | test: rendering INV-1002 twice produces byte-identical PDFs; the page count is 1 |
| AC-2 | The content is right | test extracts the text from the compiled Typst document's frames and compares it with a golden (company, customer, lines, discount 265.00, tax 47.50 and 15.20, total 5,097.70, due date 2026-04-01) |
| AC-3 | Previews are stable | insta snapshots of the SVG pages for INV-1002, an estimate and a credit memo |
| AC-4 | Email jobs work | tests with lettre's stub transport: the message has the PDF attachment and the right recipients; `last_sent_at` is set and audited; an SMTP failure returns `render.smtp_failed` and leaves the job for retry |
| AC-5 | Only posted documents are sent | tests: `send` on a draft and on a voided document returns `render.not_sendable` and enqueues nothing |
| AC-6 | Secrets stay secret | test: the SMTP password never appears in logs, the job record or error output |
| AC-7 | Routes behave per API.md | contract tests: `application/pdf` content type, preview JSON with SVG pages, `send` returns 202 with a job, an agent may read PDFs but not send |
| AC-8 | Fonts are licensed for redistribution | every font file in the crate has its license text beside it, or fonts come from `typst-kit` (stated in the PR) |
| AC-9 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W4-04` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-render -p bookscraft-api --all-targets -- -D warnings
cargo test --locked -p bookscraft-render -p bookscraft-api
cargo xtask lint
cargo xtask spine
cargo xtask scope W4-04
```

Do not commit `docs/architecture/openapi.json` or `error-codes.md`: Weave 4 regenerates them.

## Deliverables

- Branch: `wp/W4-04-render`
- PR title: `W4-04: PDF, preview and email`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work.
- A font or template asset with an unclear license: do not add it; use `typst-kit`'s fonts.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
