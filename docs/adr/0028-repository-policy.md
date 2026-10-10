---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect
---

# Repository policy: public repo, protected main, squash merges, required checks

## Context and Problem Statement

`main` must stay green while agents merge often. GitHub Free protects branches only on public repositories, and private repositories pay for macOS CI minutes (BRIEF_AUDIT R-8).

## Decision Drivers

* Free CI on Linux, Windows and macOS.
* Branch protection with required checks.
* Linear, readable history; no force pushes or history rewrites (owner rule).

## Considered Options

* Public `S0r81/bookscraft` with protected `main`, required checks, squash merges, linear history and branch auto-delete
* A private repo with a paid plan
* A private repo on Free without protection

## Decision Outcome

Chosen option: the first one (owner default, Q-2).

* **Required checks:** `fmt`, `clippy`, `lint`, `test (ubuntu-latest)`, `test (windows-latest)`, `test (macos-latest)`, `deny`, `spine`, `scope`, `dco`.
* **Merging:**
  * branches must be up to date before merging;
  * squash merge only, using the PR title and description as the commit message;
  * linear history;
  * no force pushes or deletions of `main`;
  * head branches deleted automatically.
* **Reviews:** no required approving review, because the owner authors the PRs through Claude and GitHub forbids self-approval. Reviews are done by the Weave's reviewer agents and the owner's merge decision.

### Consequences

* Good, because CI is free on three OSes, and `main` is always green.
* Bad, because "up to date" forces sequential merges. Merge queues are unavailable for user-owned repositories, so the Weave merges in a defined order, updating each branch through GitHub's update-branch action (a merge commit, never a force push).

### Confirmation

[PARALLEL_DEV_PLAYBOOK.md](../process/PARALLEL_DEV_PLAYBOOK.md) §1 gives the exact settings; the Weave prompts verify protection is active before merging (`gh api repos/S0r81/bookscraft/branches/main/protection`).

## Pros and Cons of the Options

### Public + protected

* Good, because it is free, safe and transparent: a community project.

### Private + paid

* Good, because it keeps the code private until launch.
* Bad, because it costs money every month and charges macOS minutes.

### Private on Free

* Bad, because there is no protection and limited CI minutes.

## More Information

GitHub docs on protected branches and Actions billing (BRIEF_AUDIT §7.3).
