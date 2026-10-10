# W2-W: Weave 2

## Goal

Verify and merge Wave 2 in the order W2-04, W2-01, W2-02, W2-03, W2-05, until the whole scenario spine passes (31 of 31) with the golden reports of LEDGER_SPEC Appendix A, regenerate the OpenAPI document and error-code table, settle Wave 2's CCRs and open Wave 3.

## Wave and concurrency

- Wave 2, after W2-01..W2-05 have green PRs (or the owner defers one).
- Agent: `lead-architect`. The owner approves every merge and confirms the W2-05 Orca check.
- Timebox: two sessions.

## Owned paths (may modify) / Read-only paths

May modify: everything (`**`) on `weave/W2` (or `weave/W2-2`), limited to what the wave's PRs and CCRs require.

Read-only: `docs/research/bookscraft-brief.md`.

## Read first

1. `CLAUDE.md`, `.claude/agents/lead-architect.md`, `.claude/skills/weave/SKILL.md`.
2. `docs/process/PARALLEL_DEV_PLAYBOOK.md` §5 and `docs/prompts/00-INDEX.md`.
3. The five Wave 2 prompts, their PRs and CCR files.
4. `docs/architecture/LEDGER_SPEC.md` Appendix A (the numbers the spine must now reproduce).

## Preconditions

| Precondition | Check |
|---|---|
| Weave 1 is merged | `git log origin/main --format=%s \| grep -q '^Weave 1: '` |
| Each Wave 2 PR is green or deferred by the owner | the `/weave` collect step |
| Branch protection is on | `gh api repos/S0r81/bookscraft/branches/main/protection --jq '.required_status_checks.contexts \| length'` prints `10` |

## Scope in/out

In: the `/weave 2` procedure; after each merge, `cargo xtask spine` on `main` must show no failed step (pending only decreases); if a step fails once two features combine, find the responsible PR and send the fix back before merging more; CCR decisions and implementation; `cargo xtask docs` (OpenAPI now includes sales, purchases, banking and reports; the error-code table); BOARD.md; updating Wave 3 prompts if a CCR changed what they assume.

Out: feature work; patching a work package's branch; changing a golden number in the spine (only a spec correction through a CCR, with the owner's approval, can do that).

## Tasks

1. Collect, verify (a fresh qa-verifier per PR), decide CCRs.
2. Merge in order: W2-04, W2-01, W2-02, W2-03, W2-05, checking the spine after each.
3. Close: full CI, spine 31/0/0, docs, board, Wave 3 prompts.

## Invariants touched

All, through the Weave checklist; specifically I-3 and I-4 (T-PROP-1 and T-SPINE-CASH become active), I-7 (S27 re-import), I-10 (S28) and I-5 (S30).

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | The five PRs are merged in the planned order, or a deferral is recorded | `git log origin/main --reverse --format=%s \| grep -E '^W2-0[1-5]: '` shows W2-04, W2-01, W2-02, W2-03, W2-05 |
| AC-2 | Independent verification passed for each PR | the Weave PR links each qa-verifier report with `VERDICT: pass` |
| AC-3 | No merged PR changed paths outside its row | each PR's `scope` check is green |
| AC-4 | The whole spine passes | `cargo xtask spine` prints `spine: 31 passed, 0 failed, 0 pending`, including the golden trial balance (52,181.10), both profit and loss bases (9,751.60 and 7,185.85), both balance sheets, agings, sales tax liability and the S29 reconciliation |
| AC-5 | T-PROP-1 runs and passes | its test reports active and passing in `cargo test --locked -p bookscraft-scenarios` |
| AC-6 | Generated docs are current | `cargo xtask docs --check` exits 0 after regeneration |
| AC-7 | Every Wave 2 CCR has a decision; accepted ones are implemented with docs and ADRs updated | the Decision tables |
| AC-8 | The repository is consistent | `cargo xtask ci` passes on the Weave branch; CI green on three OSes |
| AC-9 | Wave 3 is open | BOARD.md: W2-* `merged`, W3-01..W3-05 `ready` |

## Verify

```sh
git fetch origin --prune
cargo xtask ci
cargo xtask docs --check
cargo xtask lint
cargo xtask spine
cargo test --locked -p bookscraft-scenarios
```

## Deliverables

- Branch: `weave/W2`
- PR title: `Weave 2: <summary>`

## Stop conditions

- Needing to touch an unowned path means raise a CCR and stop that line of work. In a Weave the only unowned path is `docs/research/bookscraft-brief.md`.
- A spine golden number fails and the code looks right: stop and bring both computations to the owner; never edit the golden to match the code.
- Branch protection is off, or a merge would leave `main` red: stop merging and tell the owner.
- A CCR would weaken a locked invariant: reject it.
- The same failure persists after two different fix attempts.
