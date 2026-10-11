# BooksCraft: standing rules for every Claude Code session

BooksCraft is an open-source, community-built alternative to QuickBooks Online for US small businesses. It is 100% Rust, desktop first-class (Linux first), with a server mode from the same core.

- Source of truth for scope: [`docs/research/bookscraft-brief.md`](docs/research/bookscraft-brief.md). Read-only, forever.
- Owner overrides and resolved conflicts: [`docs/architecture/BRIEF_AUDIT.md`](docs/architecture/BRIEF_AUDIT.md).
- Specs: [ARCHITECTURE](docs/architecture/ARCHITECTURE.md) · [LEDGER_SPEC](docs/architecture/LEDGER_SPEC.md) · [DATA_MODEL](docs/architecture/DATA_MODEL.md) + [schema.sql](docs/architecture/schema.sql) · [API](docs/architecture/API.md) · [MIGRATION_SPEC](docs/architecture/MIGRATION_SPEC.md) · [ADRs](docs/adr/)
- Process: [PARALLEL_DEV_PLAYBOOK](docs/process/PARALLEL_DEV_PLAYBOOK.md) · [OWNERSHIP](docs/coordination/OWNERSHIP.md) · [BOARD](docs/coordination/BOARD.md) · [prompts index](docs/prompts/00-INDEX.md)

## 1. Start of every session

1. You work on exactly one work package (WP). Run `/start-wp <WP>` (for example `/start-wp W1-02`). It loads `docs/prompts/<WP>-*.md`, checks preconditions, creates or resumes branch `wp/<WP>-<slug>`, and reads any handoff note.
2. Read your role file in `.claude/agents/<agent>.md`, then the prompt's **Read first** list, in full.
3. Restate your owned paths and acceptance criteria to yourself before editing anything.
4. A Weave session runs `/weave <wave>` instead and acts as `lead-architect`.

## 2. Locked invariants

Full text and the test for each: LEDGER_SPEC §13. Violating one is never acceptable.

| ID | Rule |
|---|---|
| I-1 | Money is `i64` minor units + ISO 4217 code. FX rates, quantities and prices are decimals (`TEXT` in SQLite). No `f32`/`f64` in `money`, `ledger`, `posting`. Rounding residues go to the `rounding` account. |
| I-2 | Documents are separate from postings. `posting::post` is pure, deterministic and versioned (`rules_version`), with no I/O. |
| I-3 | Postings are append-only and every entry balances. This is enforced by `ledger::BalancedEntry` and by the storage finalize trigger. An edit is a reversal plus a new entry; a void is a reversal; posted documents are never deleted. |
| I-4 | One accrual ledger. Cash basis is derived from settlements at report time (LEDGER_SPEC §7). |
| I-5 | Periods are open, soft-locked or hard-locked. Hard-locked periods are immutable. Every override is audited. |
| I-6 | Append-only, hash-chained audit log with actor type (`user`, `api`, `agent`) and before/after state. Every mutating command writes one. |
| I-7 | Imported rows keep external ids (`external_ref`, FITID). Imports are idempotent. |
| I-8 | Dimensions are generic and uncapped; Class, Location and Project are presets. |
| I-9 | No tier gating, no count limits. |
| I-10 | AI and agent actions create drafts only. Posting needs an audited human approval. Agents get 403 `auth.agent_forbidden` on post, approve, void and other protected actions (API.md §6). |
| I-11 | Payroll processing, money movement and tax filing are out of core forever. |
| I-12 | The app is AGPL-3.0-only. `money`, `ledger`, `interchange`, `iif`, `ofx` and `qbo` are MIT and depend only on MIT or permissive crates. |
| I-13 | CI on Linux, Windows and macOS. OS-specific code only in `crates/platform`. No shelling out (`std::process::Command` only in `xtask`). Platform-standard directories. LF line endings. Tests assume neither `/` paths nor a case-sensitive filesystem. |

## 3. Crates and ownership

- Crate map and dependency rules D-1..D-10: ARCHITECTURE §2–§3.
- Who may change which paths: OWNERSHIP.md. **You may modify only your WP's owned paths**, plus your own `docs/coordination/CCR/CCR-<WP>-*.md` and `docs/coordination/handoffs/<WP>.md`. On `wp/*` branches a hook refuses other edits, and CI job `scope` fails the PR.
- **After Wave 0, only a Weave changes** the manifests and `Cargo.lock`, the contract crates (`money`, `domain`, `api-types`), `store` and its migrations, the registration points (`crates/app`, `crates/api/src/routes/mod.rs`, `crates/ui/src/routes.rs`), `xtask`, `.github`, `.claude`, this file and the docs. The few exceptions are named in OWNERSHIP.md ("Paths only a Weave changes after Wave 0").
- **Need a change outside your paths?** Run `/ccr`, then continue with what you can do. Never make the change yourself.

## 4. Commands

Always pass `--locked`. Prefer `-p <crate>` while iterating; full-workspace builds compile Tauri and Typst.

| Command | Use |
|---|---|
| `cargo xtask doctor` | Toolchain, components, targets, tools present? (`--fix` installs components and targets; `--tools` installs the pinned cargo tools) |
| `cargo check --locked -p bookscraft-<crate> --all-targets` | Fast feedback |
| `cargo test --locked -p bookscraft-<crate>` | Your crate's tests |
| `cargo clippy --locked -p bookscraft-<crate> --all-targets -- -D warnings` | Lints, warnings are errors |
| `cargo fmt --all -- --check` | Formatting (a hook formats edited `.rs` files) |
| `cargo xtask lint` | Dependency rules, SPDX headers, ownership mirror, error-code uniqueness, file-type allowlist |
| `cargo xtask scope <WP>` | Prove your branch touches only owned paths |
| `cargo xtask spine` | Scenario spine: passed, failed, pending steps |
| `cargo xtask ci` | Everything CI runs, locally |
| `INSTA_UPDATE=always cargo test --locked -p <crate>` | Write new golden files, then review them with `git diff` before committing |

## 5. Conventions

- **Rust:** edition 2024; `rustfmt` defaults plus `rustfmt.toml`; clippy with `-D warnings`. `#![forbid(unsafe_code)]` everywhere except `platform`, where any `unsafe` needs a `// SAFETY:` comment and a review.
- **Headers:** every `.rs` file starts with `// SPDX-License-Identifier: AGPL-3.0-only`, or `MIT` in the MIT crates.
- **Errors:** `thiserror` in libraries, `anyhow` only in binaries and `xtask`. Domain errors carry a stable code `<namespace>.<name>` defined as a constant in the owning crate. No `unwrap`, `expect` or `panic!` outside tests and provably infallible spots (`expect("reason")`).
- **Services:** synchronous `domain::ports` traits. HTTP handlers call them in `spawn_blocking`. Every write runs in one `BEGIN IMMEDIATE` transaction and appends its audit event in the same transaction.
- **Types:** API DTOs (`api-types`) stay separate from domain types; convert in `api`. Money crosses the wire only as decimal strings.
- **Logging:** `tracing`. Never log secrets, tokens, tax ids or request bodies.
- **Clean-room UI copy:** BooksCraft's own words (ARCHITECTURE §11). "QuickBooks" appears only in factual interoperability statements.
- **Commits:** Conventional Commits (`feat(sales): ...`, `fix(store): ...`, `test(posting): ...`, `docs: ...`). Small and logical. **Push after every meaningful commit**: cloud sandboxes can restart from a fresh clone and lose uncommitted work.
- **Branches:** `wp/<WP>-<slug>` for work packages, `weave/W<n>` for Weaves. Never commit to `main`.
- **PRs:** title `<WP>: <title>`, body from `.github/pull_request_template.md`, including the sign-off line in §8.

## 6. Testing requirements

| Kind | Required for |
|---|---|
| Unit tests | Every module with logic |
| Property tests (`proptest`) | `money`, `ledger`, `posting`, allocation, cash basis, settlement bounds, parsers |
| Golden files (`insta`) | Every posting rule (per document type and rules version), every report, every importer mapping, every Typst template |
| Storage tests | Every trigger and constraint you rely on (DATA_MODEL §6) |
| Audit assertion | Every mutating service command: `test_support::assert_audited(...)` (T-AUDIT-1) |
| Spine | Must stay green. Register a capability only when its feature is complete; that activates the matching spine steps. |
| Platform independence | Use `tempfile` and `Path::join`; no hard-coded `/tmp` or `C:\` |

Tests use fixed clocks and ids (`test_support::FixedClock`, `SeqIds`). They never touch the network: use recorded fixtures. Never assert that a stub or placeholder another work package will replace stays unimplemented (a 501, `api.not_implemented`, a "coming soon" page): test your own handling of that answer instead, so the test survives when the other package lands. The only exception is a test file your prompt names as owned by the replacing package.

## 7. Definition of done

A WP is done only when every item is true:

1. Every acceptance criterion in the prompt passes, with command output pasted in the PR.
2. Every command in the prompt's **Verify** section passes locally: fmt, clippy `-D warnings`, tests, `cargo xtask lint`, `cargo xtask spine` (no failed steps).
3. `cargo xtask scope <WP>` reports only owned paths.
4. No new `TODO` without an owner and a default (`TODO(W3-04): ... default: ...`).
5. Docs inside your owned paths are updated. Docs outside them are listed in the PR as follow-ups for the Weave.
6. Every needed contract change is filed as a CCR and linked in the PR.
7. The PR is open with the template filled and CI green.

If you cannot finish, run `/handoff`. Never claim done without the output.

## 8. Sign-off (DCO)

Every PR description ends with the owner's DCO line, which becomes part of the squash commit message (CONTRIBUTING.md):

```text
Signed-off-by: SIGNOFF_NAME <SIGNOFF_EMAIL>
```

The owner replaces the placeholder before W0-01 (playbook §1). While it is still a placeholder, stop and ask; CI job `dco` rejects it.

## 9. Audit-before-edit and zero data loss

- Read a file in full before you modify it. List a directory before you create files in it.
- Never delete or overwrite a file you have not read. Never delete user data or company files.
- **Never** force-push, rebase, amend, `reset --hard`, or rewrite history. To update a branch, merge `origin/main` into it.
- Keep generated output out of git (`target/`, `ui-dist/`) unless a prompt says otherwise.
- `docs/research/bookscraft-brief.md` is never edited.

## 10. Clean room

Build compatibility only from Intuit's public API documentation and published file formats (IIF, OFX, QFX, QBO, CSV). Never use or copy Intuit UI text, screenshots, icons, sample data or trademarks. No QBW file reading. Fixtures are hand-written from the public API reference.

## 11. Never

- Never edit paths you do not own, or change a contract instead of filing a CCR.
- Never use `f32`/`f64` for money, or `REAL`/`NUMERIC` columns.
- Never update or delete postings, journal entries, audit events, settlements, clearing events or bank history.
- Never let an `agent` principal post, approve, void or move money.
- Never add a dependency (CCR only), and never run `cargo update` (exception: a Weave applying a version bump runs `cargo update --workspace`, which touches only workspace members).
- Never use `std::process::Command` outside `xtask`, or `cfg(target_os)` outside `crates/platform`.
- Never write JavaScript, TypeScript, Python or shell scripts, or use npm, npx or node. The only exception is `.claude/hooks/session-start.sh` (ADR-0030).
- Never commit secrets, tokens, real customer data or `.env` files.
- Never mark an acceptance criterion done without running it.
- Never call real external services (Intuit, SimpleFIN, SMTP) in tests.

## 12. Stop conditions (all WPs)

Stop that line of work, and run `/ccr` or `/handoff` as appropriate, when:

- you need to modify an unowned path;
- a locked invariant would be violated;
- a precondition is false;
- a spec is contradictory or silent on something that changes stored data;
- the same failure persists after two different fix attempts;
- the prompt's timebox is reached.

Report precisely what is blocked and what still works.

## 13. Cloud session notes

- Network: crates.io, static.rust-lang.org and GitHub git operations work. GitHub release downloads for repositories not attached to the session do not, so tools are built from crates.io (`cargo install --locked`).
- Machine: about 4 vCPU and 16 GB RAM. Build single crates and run long commands with a generous timeout.
- `gh`: prefer REST (`gh api repos/S0r81/bookscraft/...`). Most GraphQL calls are blocked through the session proxy.
