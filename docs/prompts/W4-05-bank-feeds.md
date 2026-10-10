# W4-05: Bank feeds: SimpleFIN and credential storage

## Goal

Add live bank feeds behind the `BankProvider` trait in `crates/banking/src/feeds/`: the file provider and SimpleFIN (setup token, claim, account linking, scheduled sync into the review queue with dedupe), with credentials stored only through `SecretStore`, and the routes in `crates/api/src/routes/feeds.rs`.

## Wave and concurrency

- Wave 4, batch A (with W4-03 and W4-04). Paths do not overlap.
- Agent: `bank-feeds-engineer`. A `security-reviewer` pass is required in Weave 4.
- Timebox: two sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/banking/src/feeds/**`, `crates/banking/src/lib.rs`, `crates/banking/tests/feeds_*.rs`, `crates/banking/fixtures/simplefin/**`, `crates/api/src/routes/feeds.rs`
- `docs/coordination/CCR/CCR-W4-05-*.md`, `docs/coordination/handoffs/W4-05.md`

In `crates/banking/src/lib.rs`, the only change allowed is adding `BankFeeds` to `CAPABILITIES`.

Read-only: everything else, including the rest of `crates/banking` (W2-03's import, review and dedupe code: call it).

## Read first

1. `CLAUDE.md` and `.claude/agents/bank-feeds-engineer.md`.
2. ADR-0018 and `docs/architecture/ARCHITECTURE.md` §8 (`BankProvider`, `SecretStore`) and §13.
3. `docs/architecture/LEDGER_SPEC.md` §11 (dedupe and review).
4. `docs/architecture/API.md` §5.5 (`bank-feeds` endpoints).
5. The SimpleFIN protocol documentation (simplefin.org) and the brief §7.1 (cost and request limits).
6. The merged `crates/banking`.

## Preconditions

| Precondition | Check |
|---|---|
| Weave 3 is merged | `git log origin/main --format=%s \| grep -q '^Weave 3: '` |
| The feeds module and route are pre-registered | `git show origin/main:crates/banking/src/feeds/mod.rs > /dev/null && git show origin/main:crates/api/src/routes/feeds.rs > /dev/null` |

## Scope in/out

In:

- **Providers:** `FileProvider` wrapping W2-03's statement import; `SimpleFin`: decode the setup token to its claim URL, claim it once to obtain the access URL, store that credential through `SecretStore` (OS keychain on desktop, envelope encryption on the server), list provider accounts for linking to BooksCraft bank or card accounts, and fetch transactions since a date into `bank_txn` with provider ids so W2-03's dedupe applies; at most 24 requests per connection per day; HTTPS only, to the host in the stored access URL.
- **Sync:** a `bank_sync` job per linked feed (manual sync and a daily schedule), running as the feed's owner; connection status and last error shown on the feed.
- **Credential safety:** `bank_feed` stores only a `credential_ref`; credentials never appear in logs, audit events, exports, problem details or `Debug` output; when the secret store refuses the write (no OS keychain on the desktop, for example), connecting fails with `banking.credential_store_unavailable`, an explanation, and nothing stored.
- **Registration:** `banking::feeds::providers(secrets)` (ARCHITECTURE §4.5) returns `FileProvider` and `SimpleFin`; fill in the feed functions in `feeds/mod.rs` that `BankingService` (W2-03) already delegates to for the feed operations and the `bank_sync` job, keeping their signatures.
- **Routes:** `GET /bank-feeds`, `POST /bank-feeds` (connect with a setup token), `POST /bank-feeds/{id}/link`, `/sync` (202 with a job) and `/disable`, with permissions (`bank.feeds.manage`, sync also `bank.review`) and OpenAPI metadata; agents may only list.
- **Capability:** `BankFeeds` when complete.

Out: Teller and Plaid (v1, server mode, system browser), any money movement.

## Tasks

1. `FileProvider` and `banking::feeds::providers`.
2. SimpleFIN claim, credential storage and fetch.
3. Sync job, status and rate limit.
4. Routes; recorded fixtures; tests.

Fixtures are hand-written from the protocol documentation with invented institutions, accounts and amounts.

## Invariants touched

| Invariant | Test |
|---|---|
| I-7 | fetched lines dedupe by provider id; a second sync of the same window inserts nothing |
| I-11 | the feed only reads; no endpoint moves money (T-SCOPE-1 covers the routes) |
| I-6 | connect, link, sync and disable are audited (credentials never in the audit) |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | The SimpleFIN adapter works against recorded fixtures | tests: claim, account list, transactions into `bank_txn`; a second sync of the same window adds 0 lines |
| AC-2 | The rate limit holds | test with a fake clock: the 25th request in a day is refused without a network call |
| AC-3 | No secret is serialized | test: the claimed access URL (a unique fixture string) appears in none of: logs, audit events, the company file's bytes (so no export can contain it), problem details, `Debug` output |
| AC-4 | A refused secret store is handled | test with a `SecretStore` whose `put` fails: connect returns `banking.credential_store_unavailable` and no `bank_feed` row exists afterwards |
| AC-5 | Sync runs as a job with status | tests: `POST /sync` returns 202 and a job; a provider error is recorded on the feed and the job retries per the store's schedule |
| AC-6 | Routes behave per API.md §5.5 | contract tests, including an agent token refused on connect, link, sync and disable |
| AC-7 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W4-05` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-banking -p bookscraft-api --all-targets -- -D warnings
cargo test --locked -p bookscraft-banking -p bookscraft-api
cargo xtask lint
cargo xtask spine
cargo xtask scope W4-05
```

Do not commit `docs/architecture/openapi.json` or `error-codes.md`: Weave 4 regenerates them.

## Deliverables

- Branch: `wp/W4-05-bank-feeds`
- PR title: `W4-05: SimpleFIN bank feeds and credential storage`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work.
- The SimpleFIN protocol requires something ADR-0018 rules out (a hosted widget, a secret in the binary): stop and raise a CCR.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
