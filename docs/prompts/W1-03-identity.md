# W1-03: Identity

## Goal

Implement `IdentityService`, `Authenticator` and the server-side `SecretStore` in `crates/identity`: users, memberships, sessions, API and agent tokens with scopes, password hashing, login rate limiting, the desktop principal and envelope-encrypted secrets, all audited in the system file.

## Wave and concurrency

- Wave 1, batch B (with W1-04). Paths do not overlap with any other Wave 1 work package.
- Agent: `api-engineer`. A `security-reviewer` pass is required in Weave 1.
- Timebox: two sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/identity/src/**`, `crates/identity/tests/**`
- `docs/coordination/CCR/CCR-W1-03-*.md`, `docs/coordination/handoffs/W1-03.md`

Read-only: everything else, including `crates/domain` (`auth`, `ports`) and `crates/store` (system file access).

## Read first

1. `CLAUDE.md` and `.claude/agents/api-engineer.md`.
2. `docs/architecture/API.md` §2 (CSRF header, limits), §3, §4 (`auth` codes), §5.1 and §6 (roles, scopes, agent rule).
3. `docs/architecture/ARCHITECTURE.md` §8 (`SecretStore`), §13 (security model).
4. `docs/architecture/schema-system.sql` (`user`, `membership`, `session`, `api_token`, `secret`, `oauth_state`, `audit_event`) and `DATA_MODEL.md` §7.
5. `docs/architecture/LEDGER_SPEC.md` §10 (the system file's audit chain follows the same rules).
6. ADR-0023 and ADR-0022 (agent tokens).
7. `.claude/agents/security-reviewer.md` (what the reviewer will check).

## Preconditions

| Precondition | Check |
|---|---|
| Weave 0 is merged | `git log origin/main --format=%s \| grep -q '^Weave 0: '` |

## Scope in/out

In:

- **Users:** create, update, disable, set password; usernames lower-case and unique; installation admins (`is_admin`); the OS-profile user that the desktop principal maps to.
- **Memberships:** set and remove a role per user per company (owner, admin, accountant, bookkeeper, viewer).
- **Sessions:** login creates a session token (32 random bytes), stored as SHA-256; absolute lifetime 7 days and idle timeout 12 hours (constants); logout deletes it.
- **Login rate limiting:** in memory, per username and per client address: after 5 failures in 15 minutes, `auth.rate_limited` until the window passes.
- **Tokens:** `bc_` followed by 32 random bytes in base64url without padding; shown once; stored as SHA-256; actor type `api` or `agent`; scopes from API.md §6; optional company restriction and expiry; revoke; list. An agent token can never receive `books:write` (`auth.scope_not_allowed`).
- **Authenticator:** cookie session or bearer token to a `Principal` (user and memberships, or token with actor type and scopes), with `auth.required`, `auth.invalid_token` and `auth.session_expired`; the desktop principal for desktop mode.
- **Passwords:** argon2id with memory 19,456 KiB, 2 iterations, parallelism 1 (constants), PHC string storage; comparisons of hashes and tokens in constant time.
- **Secrets (server mode):** `identity::secrets::Envelope` implementing `SecretStore`: AES-256-GCM, a random 96-bit nonce per encryption, data keys wrapped by a key-encryption key read from the server configuration or `BOOKSCRAFT_KEK` (base64, 32 bytes), with `kek_version` for rotation; rows in the system file's `secret` table; returned by the fixed constructor `identity::infra::envelope_secrets` (ARCHITECTURE §4.5), whose signature stays as W0-01 wrote it.
- **Audit:** every mutating command appends to the system file's audit chain through the store.
- **Capability:** `Identity` when complete.

Out: HTTP handlers and cookies on the wire (W1-05), OIDC and custom roles (v1), the desktop keychain (W3-05).

## Tasks

1. Users and memberships; password hashing.
2. Sessions, login and rate limiting.
3. Tokens and scopes; the Authenticator.
4. Envelope secrets.
5. Audit for every command; tests.

## Invariants touched

| Invariant | Test |
|---|---|
| I-6 | every mutating command appends a system-file audit event (`assert_audited`) |
| I-9 | T-LIMIT-1 (identity part): 100 users with no limit error |
| I-10 | T-ID-2: an agent token cannot be created or updated with `books:write` |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | T-ID-2 | test: creating an agent token with `books:write` fails with `auth.scope_not_allowed`; with `books:read`, `reports:read` and `drafts:write` it succeeds |
| AC-2 | T-ID-3: password hashes use the fixed argon2id parameters, and verification works | test parses the PHC string (algorithm, `m`, `t`, `p`) and checks a right and a wrong password |
| AC-3 | Raw tokens are never stored | test: after creating a token and a session, no column in the system file contains the raw token text; the stored value equals its SHA-256 |
| AC-4 | Login is rate limited | test: five wrong passwords then a sixth attempt (even with the right password) gives `auth.rate_limited`; after the window (injected clock) login works |
| AC-5 | Sessions expire | tests with an injected clock: idle past 12 hours and past 7 days both give `auth.session_expired` |
| AC-6 | The Authenticator resolves every case | tests: valid cookie, valid bearer `api` and `agent` tokens with their scopes, revoked token, expired token, malformed header, desktop principal |
| AC-7 | Envelope secrets round-trip and fail safely | tests: put then get returns the bytes; a different KEK fails to decrypt with an error (no panic); 1,000 encryptions use 1,000 distinct nonces; no secret appears in `Debug` output of the types that hold it |
| AC-8 | T-LIMIT-1 (identity part) | test creates 100 users and memberships |
| AC-9 | Every mutating command is audited in the system file | `assert_audited` in each command's test |
| AC-10 | Lints pass and only owned paths changed | `cargo xtask lint` and `cargo xtask scope W1-03` exit 0 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-identity --all-targets -- -D warnings
cargo test --locked -p bookscraft-identity
cargo xtask lint
cargo xtask spine
cargo xtask scope W1-03
```

## Deliverables

- Branch: `wp/W1-03-identity`
- PR title: `W1-03: Identity, tokens and server secrets`

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work.
- A security requirement in ARCHITECTURE §13 cannot be met with the pinned crates: stop and raise a CCR naming the gap.
- A locked invariant would be violated, or a precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
