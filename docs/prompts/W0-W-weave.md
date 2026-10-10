# W0-W: Weave 0

## Goal

Merge Wave 0's pull requests one by one as each turns green, in the order W0-01, W0-02, W0-05, W0-04, W0-03 (W0-06 whenever ready), then close the wave: decide ADR-0002 with the owner, settle every CCR and spec decision raised in Wave 0, and open Wave 1.

## Wave and concurrency

- Wave 0. Run `/weave 0` after each Wave 0 PR turns green; each run merges what is ready, in order, and updates the board. The closing steps run once all six are merged.
- Agent: `lead-architect`. The owner approves every merge.
- Timebox: one session per run; the closing run may take two.

## Owned paths (may modify) / Read-only paths

May modify: everything (`**`) on `weave/W0` (or `weave/W0-<k>` for a second Weave PR), but only what the wave's PRs, CCRs and spec decisions require.

Read-only: `docs/research/bookscraft-brief.md` (never changed).

## Read first

1. `CLAUDE.md`, `.claude/agents/lead-architect.md`, `.claude/skills/weave/SKILL.md`.
2. `docs/process/PARALLEL_DEV_PLAYBOOK.md` §1.3, §4.3 and §5.
3. `docs/prompts/00-INDEX.md` (Weave checklist and spine plan) and every Wave 0 prompt.
4. `docs/coordination/BOARD.md` and `docs/coordination/OWNERSHIP.md`.
5. Each Wave 0 PR's description, CCR files, and the "Spec decisions" list of W0-02.

## Preconditions

| Precondition | Check |
|---|---|
| For a merging run: at least one Wave 0 PR is open with green checks | the `/weave` skill's collect step lists it |
| Before merging W0-01: branch protection is on with the ten checks | `gh api repos/S0r81/bookscraft/branches/main/protection --jq '.required_status_checks.contexts \| length'` prints `10` |
| For the closing run: W0-01..W0-06 are merged | `git log origin/main --format=%s \| grep -cE '^W0-0[1-6]: '` prints `6` |

## Scope in/out

In:

- Verifying each PR with a fresh `qa-verifier` subagent; merging in order; after each merge, setting the next WP to `ready` on the board.
- Confirming or rejecting every license W0-01 added to `deny.toml`.
- W0-02's spec decisions: update ARCHITECTURE, DATA_MODEL, API and LEDGER_SPEC so they describe the merged contracts.
- Every Wave 0 CCR: decide, implement accepted ones (a schema change is a migration plus the matching `schema.sql` change in one commit), fill in the Decision tables, write an ADR for any changed decision.
- ADR-0002 with the owner: if accepted, nothing else changes; if the spike failed for framework reasons, add a work package for a Dioxus 0.7 rerun of the spike (prompt and board row) before Wave 2's UI work; if it failed for webview reasons, write down the owner's decision in a new ADR that supersedes ADR-0002, and rewrite the UI prompts (W2-05, W3-01, W3-02, W4-01, W5-03), ARCHITECTURE §10 and ADR-0019's UI pins to match.
- `cargo xtask docs` (nothing to generate may be the result), `cargo xtask lint --fix-codeowners` if OWNERSHIP changed.
- Checking that the cloud setup script's toolchain version (playbook §2.2) equals `rust-toolchain.toml`.
- Board: Wave 0 rows `merged`, Wave 1 rows `ready`.

Out: any new feature work; changing a work package's code to make it pass (send it back instead).

## Tasks

1. Per run: `/weave 0` steps 1–5 for the PRs that are green.
2. Closing run: steps 6–7, plus the ADR-0002 decision, spec updates and Wave 1 opening above.

## Invariants touched

All of them indirectly: the Weave checks that each merged PR kept its invariant tests (00-INDEX Weave checklist) and that no CCR weakens an invariant.

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | The six Wave 0 PRs are merged, W0-01..W0-05 in the planned order | `git log origin/main --reverse --format=%s \| grep -E '^W0-0[1-5]: '` lists W0-01, W0-02, W0-05, W0-04, W0-03 in that order |
| AC-2 | Each merged PR had a passing independent verification | the Weave PR links each qa-verifier report with `VERDICT: pass` |
| AC-3 | No merged PR changed paths outside its row | each PR's `scope` check is green, and the Weave PR lists their `cargo xtask scope` outputs |
| AC-4 | The spine matches the plan | `cargo xtask spine` on the Weave branch prints `spine: 0 passed, 0 failed, 31 pending` |
| AC-5 | ADR-0002 is decided | its status is `accepted`, or it is `superseded by ADR-NNNN` with that ADR present, or a spike-rerun work package is on the board with the owner's decision recorded in the Weave PR |
| AC-6 | Every Wave 0 CCR and spec decision is settled | every `docs/coordination/CCR/CCR-W0-*.md` has a filled Decision table; each W0-02 spec decision is reflected in the named spec (listed in the Weave PR) |
| AC-7 | Branch protection is on | the Weave PR shows `gh api repos/S0r81/bookscraft/branches/main/protection --jq '.required_status_checks.contexts'` with the ten checks |
| AC-8 | The repository is consistent | `cargo xtask ci` passes on the Weave branch; `cargo xtask docs --check` and `cargo xtask lint` pass |
| AC-9 | Wave 1 is open | BOARD.md shows W0-* `merged` and W1-01..W1-05 `ready` |

## Verify

```sh
git fetch origin --prune
cargo xtask ci
cargo xtask docs --check
cargo xtask lint
cargo xtask spine
gh api repos/S0r81/bookscraft/branches/main/protection --jq '.required_status_checks.contexts'
```

## Deliverables

- Branch: `weave/W0` (a second Weave PR in the same wave uses `weave/W0-2`)
- PR title: `Weave 0: <summary>`, for example `Weave 0: close Wave 0, accept ADR-0002, open Wave 1`

## Stop conditions

- Needing to touch an unowned path means raise a CCR and stop that line of work. In a Weave the only unowned path is `docs/research/bookscraft-brief.md`, which nobody changes.
- Needing to change a work package's code to make it pass: send it back to that work package; never patch a WP branch in the Weave.
- Branch protection is off, or a merge would leave `main` red: stop merging and tell the owner.
- A CCR would weaken a locked invariant: reject it.
- A decision is the owner's (ADR-0002 after a webview failure, a license question, anything expensive to reverse): stop and ask.
- The same failure persists after two different fix attempts.
