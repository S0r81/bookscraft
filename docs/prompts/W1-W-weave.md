# W1-W: Weave 1

## Goal

Verify and merge Wave 1 in the order W1-04, W1-01, W1-02, W1-03, W1-05, with security reviews of identity and the API framework, settle Wave 1's CCRs, confirm the spine shows S01–S02 passing, and open Wave 2.

## Wave and concurrency

- Wave 1, after W1-01..W1-05 have green PRs (or the owner defers one).
- Agent: `lead-architect`. The owner approves every merge.
- Timebox: two sessions.

## Owned paths (may modify) / Read-only paths

May modify: everything (`**`) on `weave/W1` (or `weave/W1-2`), limited to what the wave's PRs and CCRs require.

Read-only: `docs/research/bookscraft-brief.md`.

## Read first

1. `CLAUDE.md`, `.claude/agents/lead-architect.md`, `.claude/skills/weave/SKILL.md`.
2. `docs/process/PARALLEL_DEV_PLAYBOOK.md` §5 and `docs/prompts/00-INDEX.md` (Weave checklist, spine plan).
3. The five Wave 1 prompts, their PRs and CCR files.
4. `.claude/agents/security-reviewer.md`.

## Preconditions

| Precondition | Check |
|---|---|
| Weave 0 is merged | `git log origin/main --format=%s \| grep -q '^Weave 0: '` |
| Each Wave 1 PR is green or deferred by the owner | the `/weave` collect step |
| Branch protection is on | `gh api repos/S0r81/bookscraft/branches/main/protection --jq '.required_status_checks.contexts \| length'` prints `10` |

## Scope in/out

In: the `/weave 1` procedure; `security-reviewer` passes for W1-03 and W1-05 (findings rated high or critical block the merge); CCR decisions and their implementation (contracts, migrations with `schema.sql`, docs, ADRs); `cargo xtask docs` (OpenAPI and error codes); BOARD.md updates; updating Wave 2 prompts if a CCR changed what they assume.

Out: feature work; patching a work package's branch.

## Tasks

1. Collect, verify (qa-verifier per PR, security-reviewer for W1-03 and W1-05), decide CCRs.
2. Merge in order: W1-04, W1-01, W1-02, W1-03, W1-05.
3. Close: full CI, spine counts, docs, board, Wave 2 prompts.

## Invariants touched

All, through the Weave checklist; specifically I-10 (T-API-1 now covers the core routes) and I-6 (system-file audit from identity).

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | The five PRs are merged in the planned order, or a deferral is recorded on the board | `git log origin/main --reverse --format=%s \| grep -E '^W1-0[1-5]: '` shows W1-04, W1-01, W1-02, W1-03, W1-05 |
| AC-2 | Independent verification and security reviews passed | the Weave PR links each qa-verifier report (`VERDICT: pass`) and the security-reviewer reports for W1-03 and W1-05 with no open high or critical finding |
| AC-3 | No merged PR changed paths outside its row | each PR's `scope` check is green |
| AC-4 | The spine matches the plan | `cargo xtask spine` prints `spine: 2 passed, 0 failed, 29 pending` |
| AC-5 | Generated docs are current | `cargo xtask docs --check` exits 0, and `docs/architecture/error-codes.md` lists the codes of every merged crate |
| AC-6 | Every Wave 1 CCR has a decision; accepted ones are implemented with docs and ADRs updated | the Decision table of each `docs/coordination/CCR/CCR-W1-*.md` |
| AC-7 | The repository is consistent | `cargo xtask ci` passes on the Weave branch; CI green on three OSes |
| AC-8 | Wave 2 is open | BOARD.md: W1-* `merged`, W2-01..W2-05 `ready` (W2-05 only if ADR-0002 is accepted) |

## Verify

```sh
git fetch origin --prune
cargo xtask ci
cargo xtask docs --check
cargo xtask lint
cargo xtask spine
```

## Deliverables

- Branch: `weave/W1`
- PR title: `Weave 1: <summary>`

## Stop conditions

- Needing to touch an unowned path means raise a CCR and stop that line of work. In a Weave the only unowned path is `docs/research/bookscraft-brief.md`.
- A security finding rated high or critical: do not merge that PR; send it back.
- Branch protection is off, or a merge would leave `main` red: stop merging and tell the owner.
- A CCR would weaken a locked invariant: reject it.
- A decision belongs to the owner: stop and ask.
- The same failure persists after two different fix attempts.
