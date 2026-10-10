# W4-W: Weave 4

## Goal

Verify and merge Wave 4 in the order W4-04, W4-05, W4-03, W4-02, W4-01, with security reviews of the QBO connector, rendering and email, and bank feeds, keep the spine and the end-to-end tests green, settle Wave 4's CCRs and open Wave 5.

## Wave and concurrency

- Wave 4, after W4-01..W4-05 have green PRs (or the owner defers one).
- Agent: `lead-architect`. The owner approves every merge and confirms W4-03's endpoint checklist (if any).
- Timebox: two sessions.

## Owned paths (may modify) / Read-only paths

May modify: everything (`**`) on `weave/W4` (or `weave/W4-2`), limited to what the wave's PRs and CCRs require.

Read-only: `docs/research/bookscraft-brief.md`.

## Read first

1. `CLAUDE.md`, `.claude/agents/lead-architect.md`, `.claude/skills/weave/SKILL.md`, `.claude/agents/security-reviewer.md`.
2. `docs/process/PARALLEL_DEV_PLAYBOOK.md` §5 and `docs/prompts/00-INDEX.md`.
3. The five Wave 4 prompts, their PRs and CCR files.

## Preconditions

| Precondition | Check |
|---|---|
| Weave 3 is merged | `git log origin/main --format=%s \| grep -q '^Weave 3: '` |
| Each Wave 4 PR is green or deferred by the owner | the `/weave` collect step |
| Branch protection is on | `gh api repos/S0r81/bookscraft/branches/main/protection --jq '.required_status_checks.contexts \| length'` prints `10` |

## Scope in/out

In: the `/weave 4` procedure; security reviews of W4-03 (OAuth, tokens, outbound requests), W4-04 (SMTP credentials, template data) and W4-05 (feed credentials); the owner's confirmation of W4-03's endpoint facts; CCR decisions and implementation; `cargo xtask docs`; BOARD.md; updating Wave 5 prompts if needed.

Out: feature work; patching a work package's branch.

## Tasks

1. Collect, verify (qa-verifier per PR; security-reviewer for W4-03, W4-04, W4-05), owner confirmation, CCR decisions.
2. Merge in order: W4-04, W4-05, W4-03, W4-02, W4-01.
3. Close: full CI, spine, end-to-end, docs, board, Wave 5 prompts.

## Invariants touched

All, through the Weave checklist; specifically I-7 (T-MIG-1 part two), I-11 (no money movement in feeds), I-6 (audits without secrets).

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | The five PRs are merged in the planned order, or a deferral is recorded | `git log origin/main --reverse --format=%s \| grep -E '^W4-0[1-5]: '` shows W4-04, W4-05, W4-03, W4-02, W4-01 |
| AC-2 | Verification, security reviews and the owner confirmation are recorded | the Weave PR links them; no open high or critical security finding |
| AC-3 | No merged PR changed paths outside its row | each PR's `scope` check is green |
| AC-4 | The spine and end-to-end tests stay green | `cargo xtask spine` prints `spine: 31 passed, 0 failed, 0 pending`; `cargo xtask e2e --web` passes every UI test file |
| AC-5 | `bookscraft serve` runs the whole product | the Weave runs `bookscraft serve` with a temporary config and checks `/`, `/api/v1/health` (every MVP capability except those deferred) and `/mcp` |
| AC-6 | Generated docs are current | `cargo xtask docs --check` exits 0 after regeneration |
| AC-7 | Every Wave 4 CCR has a decision; accepted ones are implemented with docs and ADRs updated | the Decision tables |
| AC-8 | The repository is consistent | `cargo xtask ci` passes; CI green on three OSes |
| AC-9 | Wave 5 is open | BOARD.md: W4-* `merged`, W5-01..W5-04 `ready` |

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

- Branch: `weave/W4`
- PR title: `Weave 4: <summary>`

## Stop conditions

- Needing to touch an unowned path means raise a CCR and stop that line of work. In a Weave the only unowned path is `docs/research/bookscraft-brief.md`.
- A security finding rated high or critical, or a missing owner confirmation: do not merge that PR.
- Branch protection is off, or a merge would leave `main` red: stop merging and tell the owner.
- A CCR would weaken a locked invariant: reject it.
- The same failure persists after two different fix attempts.
