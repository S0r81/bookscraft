# W3-W: Weave 3

## Goal

Verify and merge Wave 3 in the order W3-03, W3-04, W3-05, W3-01, W3-02, with security reviews of the migration pipeline and the desktop shell and the owner's Fedora checks, keep the spine green with the interchange round trip, settle Wave 3's CCRs and open Wave 4.

## Wave and concurrency

- Wave 3, after W3-01..W3-05 have green PRs (or the owner defers one).
- Agent: `lead-architect`. The owner approves every merge and confirms the W3-03 reference checklist and the W3-05 Fedora checks.
- Timebox: two sessions.

## Owned paths (may modify) / Read-only paths

May modify: everything (`**`) on `weave/W3` (or `weave/W3-2`), limited to what the wave's PRs and CCRs require.

Read-only: `docs/research/bookscraft-brief.md`.

## Read first

1. `CLAUDE.md`, `.claude/agents/lead-architect.md`, `.claude/skills/weave/SKILL.md`, `.claude/agents/security-reviewer.md`.
2. `docs/process/PARALLEL_DEV_PLAYBOOK.md` §4.4 and §5; `docs/prompts/00-INDEX.md`.
3. The five Wave 3 prompts, their PRs and CCR files.

## Preconditions

| Precondition | Check |
|---|---|
| Weave 2 is merged | `git log origin/main --format=%s \| grep -q '^Weave 2: '` |
| Each Wave 3 PR is green or deferred by the owner | the `/weave` collect step |
| Branch protection is on | `gh api repos/S0r81/bookscraft/branches/main/protection --jq '.required_status_checks.contexts \| length'` prints `10` |

## Scope in/out

In: the `/weave 3` procedure; security reviews of W3-04 (archives, imports) and W3-05 (custom protocol, no listener, secrets); the owner's confirmation of W3-03's reference checklist (if any) and of W3-05's Fedora checks before merging those PRs; CCR decisions and implementation; `cargo xtask docs`; BOARD.md; updating Wave 4 prompts if needed.

Out: feature work; patching a work package's branch.

## Tasks

1. Collect, verify (qa-verifier per PR; security-reviewer for W3-04 and W3-05), owner confirmations, CCR decisions.
2. Merge in order: W3-03, W3-04, W3-05, W3-01, W3-02.
3. Close: full CI, spine, docs, board, Wave 4 prompts.

## Invariants touched

All, through the Weave checklist; specifically I-7 (T-MIG-1 part one), I-13 (platform crate on three OSes).

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | The five PRs are merged in the planned order, or a deferral is recorded | `git log origin/main --reverse --format=%s \| grep -E '^W3-0[1-5]: '` shows W3-03, W3-04, W3-05, W3-01, W3-02 |
| AC-2 | Verification, security reviews and owner confirmations are recorded | the Weave PR links the qa-verifier reports, the security reports for W3-04 and W3-05 (no open high or critical finding), and the owner's confirmations |
| AC-3 | No merged PR changed paths outside its row | each PR's `scope` check is green |
| AC-4 | The spine stays green and the spine company round-trips | `cargo xtask spine` prints `spine: 31 passed, 0 failed, 0 pending`; T-MIG-3 passes in `cargo test --locked -p bookscraft-migrate` |
| AC-5 | The UI end-to-end tests pass | `cargo xtask e2e --web` passes `ui_foundation.rs`, `ui_sales.rs` and `ui_purchases_banking.rs` |
| AC-6 | Generated docs are current | `cargo xtask docs --check` exits 0 after regeneration |
| AC-7 | Every Wave 3 CCR has a decision; accepted ones are implemented with docs and ADRs updated | the Decision tables |
| AC-8 | The repository is consistent | `cargo xtask ci` passes; CI green on three OSes |
| AC-9 | Wave 4 is open | BOARD.md: W3-* `merged`, W4-01..W4-05 `ready` |

## Verify

```sh
git fetch origin --prune
cargo xtask ci
cargo xtask e2e --web
cargo xtask docs --check
cargo xtask lint
cargo xtask spine
```

## Deliverables

- Branch: `weave/W3`
- PR title: `Weave 3: <summary>`

## Stop conditions

- Needing to touch an unowned path means raise a CCR and stop that line of work. In a Weave the only unowned path is `docs/research/bookscraft-brief.md`.
- A security finding rated high or critical, or a missing owner confirmation: do not merge that PR.
- Branch protection is off, or a merge would leave `main` red: stop merging and tell the owner.
- A CCR would weaken a locked invariant: reject it.
- The same failure persists after two different fix attempts.
