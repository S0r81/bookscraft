# W4-03: QBO connector

## Goal

Build the QuickBooks Online API connector in `crates/migrate/src/qbo/`: pluggable token sources (authorization code with PKCE in server mode, pasted tokens on the desktop), paginated entity reads, the Reports API for validation, attachment downloads, rate limiting and retries, wired into the pipeline so `ImportQbo` runs end to end against recorded fixtures.

## Wave and concurrency

- Wave 4, batch A (with W4-04 and W4-05). Paths do not overlap.
- Agent: `import-migration-engineer`. A `security-reviewer` pass is required in Weave 4. The owner provides an Intuit developer app and confirms endpoint facts.
- Timebox: two sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/migrate/src/qbo/**`, `crates/migrate/src/lib.rs`, `crates/migrate/tests/qbo_*.rs`, `crates/migrate/fixtures/qbo_http/**`
- `docs/coordination/CCR/CCR-W4-03-*.md`, `docs/coordination/handoffs/W4-03.md`

In `crates/migrate/src/lib.rs`, the only change allowed is adding `ImportQbo` to `CAPABILITIES`.

Read-only: everything else, including the rest of `crates/migrate` (W3-04's pipeline), `crates/qbo` and `crates/api/src/routes/imports.rs`.

## Read first

1. `CLAUDE.md` and `.claude/agents/import-migration-engineer.md`.
2. `docs/architecture/MIGRATION_SPEC.md` §4 (access, order, mapping) and §6 (validation inputs).
3. ADR-0017 and `docs/architecture/BRIEF_AUDIT.md` §7.4–§7.5 (secondary-source facts that must be re-checked).
4. `docs/architecture/ARCHITECTURE.md` §8 (`SecretStore`), §13.
5. The merged `crates/migrate` (pipeline, `ImportService`, the `qbo` placeholder) and `crates/qbo`.
6. Intuit's current documentation for OAuth 2.0, the query endpoint, `minorversion`, the Reports API (TrialBalance, AgedReceivables, AgedPayables, ProfitAndLoss) and Attachable downloads.

## Preconditions

| Precondition | Check |
|---|---|
| Weave 3 is merged | `git log origin/main --format=%s \| grep -q '^Weave 3: '` |
| The QBO placeholder module exists | `git show origin/main:crates/migrate/src/qbo/mod.rs > /dev/null` |

## Scope in/out

In:

- **Token sources:** a `TokenSource` with two implementations: authorization code with PKCE (server mode; state and verifier in `oauth_state` with a 10-minute single-use expiry, bound to the user and company that started the connection, which is how the callback authenticates, API.md §5.7; redirect `https://<server>/api/v1/companies/{cid}/imports/qbo/callback`) and pasted tokens (desktop). The owner's client id and secret come from the server config or desktop settings through `SecretStore`; BooksCraft ships no secret. Tokens are stored through `SecretStore` (purpose `qbo_oauth`), refreshed when expired, and deleted after the run unless the user keeps the connection.
- **Reads:** `SELECT * FROM <Entity> STARTPOSITION n MAXRESULTS 1000` through the query endpoint, in MIGRATION_SPEC §4.2 order, with `minorversion` from configuration; `COUNT(*)` queries for the request estimate (`ImportService::qbo_estimate`, API.md §5.7) shown before starting.
- **Limits:** at most 4 concurrent requests and 300 per minute per realm; retry 429 and 5xx with exponential backoff from 1 to 32 seconds, 6 attempts.
- **Reports:** month-end TrialBalance (accrual), AgedReceivables and AgedPayables at the last imported date, ProfitAndLoss on cash basis per month, converted into the pipeline's source-report inputs. (Cut-over mode is v1; the MVP imports full history.)
- **Attachments:** download through the Attachable temporary URL only from Intuit hosts; deduplicate by SHA-256.
- **Wiring:** `ImportService`'s QBO methods (connect, callback, token, estimate, start with source `qbo_api`) call into this module; the run maps entities with `crates/qbo` and feeds the W3-04 pipeline; register `ImportQbo` when complete.
- **Fixtures:** hand-written HTTP exchanges in `crates/migrate/fixtures/qbo_http/` following the public reference, with invented companies and amounts (no real data, no Intuit sample data); a fake HTTP layer replays them in tests.
- **Endpoint verification:** before relying on an endpoint name, parameter or `minorversion`, check Intuit's current documentation; list each fact and its source in the PR.

Out: a hosted OAuth relay (v1, gated on the owner's review of Intuit's terms), the wizard UI (W4-01), live calls in tests.

## Tasks

1. Token sources and secret handling.
2. Query client with pagination, limits and retries.
3. Reports and attachments.
4. Wiring into `ImportService` and the pipeline.
5. Fixtures and tests; endpoint verification list.

## Invariants touched

| Invariant | Test |
|---|---|
| I-7 | T-MIG-1 (W4-03 part): the recorded QBO fixture imported end to end twice creates nothing the second time |
| I-1 | source amounts flow unchanged through `qbo` mapping into the pipeline |
| — | T-MIG-7: connector against recorded fixtures (pagination, 429 retry, token refresh) |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | T-MIG-7 | tests: a 2,500-row entity read across three pages; a 429 followed by success after backoff; an expired access token refreshed once and the request retried |
| AC-2 | T-MIG-1 (W4-03 part) | test: the full recorded company imported twice; the second run reports only duplicates |
| AC-3 | Validation uses QBO's reports | test: recorded TrialBalance and aging responses become source-report inputs and the run passes validation |
| AC-4 | OAuth follows ADR-0017 | tests: PKCE verifier and challenge, state checked and single use, expired state refused; no client secret in code or fixtures (test scans the crate) |
| AC-5 | Limits hold | test with a fake clock: never more than 4 requests in flight and 300 per minute |
| AC-6 | Attachments come only from Intuit hosts | test: a download URL on another host is refused |
| AC-7 | Endpoint facts are verified | the PR lists each endpoint, parameter and the `minorversion` with its documentation source, or an owner checklist for anything that could not be fetched |
| AC-8 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W4-03` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-migrate --all-targets -- -D warnings
cargo test --locked -p bookscraft-migrate
cargo xtask lint
cargo xtask spine
cargo xtask scope W4-03
```

## Deliverables

- Branch: `wp/W4-03-qbo-connector`
- PR title: `W4-03: QBO API connector`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work (the pipeline outside `src/qbo/`, the routes, the `qbo` crate).
- Intuit's documentation contradicts MIGRATION_SPEC on an endpoint, parameter or report shape: raise a CCR quoting it.
- Any step would need a client secret in the repository or in a binary: stop.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
