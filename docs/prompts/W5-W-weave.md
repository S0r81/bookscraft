# W5-W: Weave 5 and the MVP release

## Goal

Verify and merge Wave 5, run the full security review, cut release candidate `v0.1.0-rc.1` for the owner's pilot, write the M-WM prompts, and, once the owner's pilot meets the MVP exit (ROADMAP §2), cut `v0.1.0`.

## Wave and concurrency

- Wave 5, in two parts:
  - **Part A**, after W5-01, W5-03 and W5-04 have green PRs (W5-02 may be deferred to v1 by the owner): merges, security review, release candidate, M-WM prompts. Branch `weave/W5`.
  - **Part B**, after the owner has closed one real month in BooksCraft and confirmed the trial balance match: the final release. Branch `weave/W5-2`.
- Agent: `lead-architect`. The owner approves every merge, pushes the tags and publishes the releases.
- Timebox: two sessions for Part A, one for Part B.

## Owned paths (may modify) / Read-only paths

May modify: everything (`**`) on `weave/W5` and `weave/W5-2`, limited to what the wave's PRs, its CCRs and this prompt require.

Read-only: `docs/research/bookscraft-brief.md`.

## Read first

1. `CLAUDE.md`, `.claude/agents/lead-architect.md`, `.claude/skills/weave/SKILL.md`, `.claude/agents/security-reviewer.md`.
2. `docs/roadmap/ROADMAP.md` §2 (MVP exit) and §5 (M-WM items).
3. `docs/process/PARALLEL_DEV_PLAYBOOK.md` §1.3 (branch protection) and §5; `docs/prompts/00-INDEX.md` (prompt format, Weave checklist).
4. The four Wave 5 prompts, their PRs and CCR files.
5. `docs/process/RELEASE_CHECKLIST.md` and `docs/process/PILOT_RUNBOOK.md` once W5-04 is merged.
6. ADR-0026 (release workflow, application identifier) and ADR-0028 (repository policy, required checks).

## Preconditions

| Precondition | Check |
|---|---|
| Weave 4 is merged | `git log origin/main --format=%s \| grep -q '^Weave 4: '` |
| W5-01, W5-03 and W5-04 are green (W5-02 green or deferred by the owner) | the `/weave` collect step |
| Branch protection is on | `gh api repos/S0r81/bookscraft/branches/main/protection --jq '.required_status_checks.contexts \| length'` prints `10` (or `11` if an earlier Weave made `e2e (ubuntu-latest)` required) |
| Part B only: Part A is merged and the owner has confirmed the pilot | `git log origin/main --format=%s \| grep -q '^Weave 5: '`, and the owner's confirmation (below) is in the Part B PR |

## Scope in/out

In, Part A:

- The `/weave 5` procedure: merge order W5-02 (if ready), W5-01, W5-03, W5-04; a fresh `qa-verifier` per PR (W5-04 by a reviewer that did not build it).
- A full `security-reviewer` pass over the integrated product (authentication and sessions, tokens and scopes, the agent rule over HTTP and MCP, secrets in keychain and envelope storage, the QBO connector, SMTP, bank feeds, the desktop protocol and its lack of a listener, archive and file imports, the release workflow's permissions), plus the per-PR review of W5-02 if merged.
- The end-to-end decision: make `e2e (ubuntu-latest)` a required check when it has been green on every Weave since Weave 3 and on this branch; otherwise keep it optional and record why. Record the decision in ADR-0028, update ARCHITECTURE §15, playbook §1.3, the Weave checklist count, the protection check in `.claude/skills/weave/SKILL.md` and the check list in `CONTRIBUTING.md`, and give the owner the `gh api` command that updates branch protection. Add a CI job for `cargo xtask e2e --desktop` only if it ran green in W5-04 here.
- Version `0.1.0` in `[workspace.package]`, then `cargo update --workspace` (it rewrites only the workspace members in `Cargo.lock`; `git diff Cargo.lock` must show no other change). Release candidates are tags (`v0.1.0-rc.1`, `-rc.2`, …) on a build whose version is already `0.1.0`, which keeps pre-release suffixes out of the deb and rpm version fields.
- `docs/releases/v0.1.0-rc.1.md` (what works, known gaps, Linux only, how to report problems).
- The M-WM prompts `docs/prompts/WM-01-windows-installer.md`, `WM-02-macos-dmg.md`, `WM-03-updater.md`, `WM-04-platform-qa.md` with the 12 sections, from ROADMAP §5; their OWNERSHIP rows as wave 6 (extend the ownership parser's wave range and its rule text in the same commit) and their BOARD rows; the index updated.
- CCR decisions and implementation; `cargo xtask docs`; BOARD.md.

After the Part A PR merges (the owner, on Fedora): `git fetch origin && git tag v0.1.0-rc.1 origin/main && git push origin v0.1.0-rc.1`; the release workflow builds, smoke-tests and drafts the pre-release; the owner publishes it and follows `PILOT_RUNBOOK.md` with those packages.

In, Part B:

- The owner's confirmation in the PR, as a summary only (PILOT_RUNBOOK): the month closed, the date compared, the number of accounts compared, zero differences, and that migration validation passed. No balances, names or files from the real company.
- `RELEASE_CHECKLIST.md` filled in, every item with its proof or link.
- `docs/releases/v0.1.0.md`; README status changed from pre-alpha to the honest new status (first release, Linux packages, Windows and macOS in M-WM). The version stays `0.1.0`.

After the Part B PR merges, the owner tags `v0.1.0` the same way and publishes the release.

Out: feature work; patching a work package's branch; v1 planning (a later planning Weave).

## Tasks

1. Part A: collect, verify, security review, CCR decisions; merge in order.
2. Part A: end-to-end decision; version and release notes; M-WM prompts with ownership and board rows; docs; board.
3. Part B: owner confirmation, release checklist, version, release notes, README.

## Invariants touched

All, through the Weave checklist and the full security review; specifically I-10 (MCP and HTTP agent rule), I-12 (licenses in packages and metainfo), I-13 (Linux packages from the same core; Windows and macOS still in CI).

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | The Wave 5 PRs are merged in the planned order, or a deferral is recorded | `git log origin/main --reverse --format=%s \| grep -E '^W5-0[1-4]: '` shows W5-02 (if merged), W5-01, W5-03, W5-04; a deferral of W5-02 is in BOARD.md with the owner's reason |
| AC-2 | Verification and the full security review are recorded | the Part A PR links each qa-verifier report and the security report; no open high or critical finding |
| AC-3 | No merged PR changed paths outside its row | each PR's `scope` check is green |
| AC-4 | The product is green end to end | `cargo xtask spine` prints `spine: 31 passed, 0 failed, 0 pending`; `cargo xtask e2e --web` and `cargo xtask e2e --desktop` pass |
| AC-5 | The end-to-end decision is recorded consistently | ADR-0028, ARCHITECTURE §15, playbook §1.3, the Weave checklist, the weave skill and CONTRIBUTING.md name the same required checks |
| AC-6 | Part A: the version is set without dependency changes | `cargo metadata --locked --format-version 1 --no-deps` lists every member at `0.1.0`; `git diff origin/main -- Cargo.lock` changes only workspace members' versions |
| AC-7 | The M-WM prompts are ready | the four prompt files exist with exactly the 12 sections; `cargo xtask lint` accepts their OWNERSHIP rows (wave 6) |
| AC-8 | Part B: the MVP exit is met and documented | the owner's summary confirmation is in the Part B PR; every line of `RELEASE_CHECKLIST.md` has its proof or link |
| AC-9 | Generated docs are current | `cargo xtask docs --check` exits 0 |
| AC-10 | The repository is consistent | `cargo xtask ci` passes; CI green on three OSes |
| AC-11 | The board shows the state | BOARD.md: W5-* `merged` (or W5-02 `deferred`), WM-01..WM-04 `ready` |

## Verify

```sh
git fetch origin --prune
cargo xtask ci
cargo xtask e2e --web
cargo xtask e2e --desktop
cargo xtask docs --check
cargo xtask lint
cargo xtask spine
```

## Deliverables

- Part A: branch `weave/W5`, PR title `Weave 5: <summary>`.
- Part B: branch `weave/W5-2`, PR title `Weave 5 (release): v0.1.0`.

## Stop conditions

- Needing to touch an unowned path means raise a CCR and stop that line of work. In a Weave the only unowned path is `docs/research/bookscraft-brief.md`.
- A security finding rated high or critical: do not merge that PR or cut a release until it is fixed.
- The owner's pilot shows any difference, or validation fails: do not start Part B; record what differed (without real data) and plan the fix as a CCR or a new work package.
- Any step would put real company data in the repository, an issue or a PR: stop.
- Branch protection is off, or a merge would leave `main` red: stop merging and tell the owner.
- The same failure persists after two different fix attempts.
