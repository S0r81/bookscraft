---
name: weave
description: Run a BooksCraft Weave - the lead-architect session that closes a wave by verifying and merging its pull requests in order, deciding CCRs, and updating the board, specs and prompts. Use when asked to run, start or continue the Weave for a wave, for example "/weave 1".
argument-hint: "<wave number, 0 to 5>"
---

# Weave $0

Work as `lead-architect`: read `.claude/agents/lead-architect.md`, then the Weave prompt `docs/prompts/W$0-W-weave.md` and `docs/process/PARALLEL_DEV_PLAYBOOK.md` §5. GitHub calls use the REST API (`gh api`); GraphQL is blocked in cloud sessions.

## 1. Prepare

1. Run `git fetch origin --prune`. Read the wave's rows in `docs/coordination/BOARD.md`.
2. Check branch protection: `gh api repos/S0r81/bookscraft/branches/main/protection --jq '.required_status_checks.contexts'` must list the ten checks in ARCHITECTURE §15. If it does not, stop and point the owner to playbook §1. (Weave 0 checks it after W0-01's CI has run once and the owner has turned protection on.)
3. Create or resume the Weave branch: `git switch -c weave/W$0 origin/main`, or switch to the existing `weave/W$0` and run `git merge --no-edit origin/main`. A second Weave pull request in the same wave uses `weave/W$0-2`.

## 2. Collect

1. List the wave's open pull requests:
   `gh api repos/S0r81/bookscraft/pulls --method GET -f state=open -f per_page=100 --jq '.[] | select(.head.ref | startswith("wp/W$0-")) | [.number, .head.ref, .head.sha, .title] | @tsv'`
2. For each one, read its checks (`gh api repos/S0r81/bookscraft/commits/<sha>/check-runs --method GET -f per_page=100 --jq '.check_runs[] | [.name, .conclusion] | @tsv'`) and its files (`gh api repos/S0r81/bookscraft/pulls/<number>/files --method GET -f per_page=100 --jq '.[].filename'`), and note the CCR files it adds.
3. A work package without a pull request, or with red checks: ask the owner whether to wait for it or defer it (BOARD `blocked`, with the reason).

## 3. Verify

For each pull request, spawn a fresh `qa-verifier` subagent and give it only the pull request number, the branch and the prompt path. Spawn `security-reviewer` for the work packages listed in `lead-architect.md`. Never fix a work package's code on its branch yourself: send fixes back to that work package (`/start-wp <WP>` in a new session), or record a follow-up.

## 4. Decide CCRs

For each CCR raised in the wave: accept, reject or supersede it, with a reason. A blocking CCR that a work package needs before it can pass is implemented first, in its own Weave pull request titled `Weave $0 (interim): <summary>`, so that work package can merge `origin/main` and finish. Only the pull request that closes the wave is titled `Weave $0: <summary>`, because later prompts check for that title. Fill in each CCR's Decision table on the Weave branch.

## 5. Merge, one pull request at a time

Order: the Weave contract pull request (if any), then the work packages in the order the Weave prompt lists. For each pull request:

1. If it is behind `main`: `gh api repos/S0r81/bookscraft/pulls/<number>/update-branch -X PUT`. This makes a merge commit on the branch; never force-push.
2. Wait until every required check is green (poll the check runs every few minutes).
3. Save its description: `gh api repos/S0r81/bookscraft/pulls/<number> --jq .body > <file>`. It must end with a `Signed-off-by:` line.
4. Squash-merge it with the title and description as the commit message:
   `gh api repos/S0r81/bookscraft/pulls/<number>/merge -X PUT -f merge_method=squash -f commit_title="<title> (#<number>)" -F commit_message=@<file>`
   The owner approves each merge. Say what you are merging and why it is ready.

## 6. Close the wave

1. On the Weave branch, run `git merge --no-edit origin/main`, then `cargo xtask ci`. Record the spine's passed, failed and pending counts.
2. Update `BOARD.md` (merged, deferred and the next wave's `ready` rows), CCR decisions, ADRs, specs, prompts of later waves if a CCR changed them, and generated docs (`cargo xtask docs`).
3. Commit, push, and open the Weave pull request titled `Weave $0: <summary>` with `gh api repos/S0r81/bookscraft/pulls -X POST ...`. When it is green, merge it as in step 5.

## 7. Report

List the merged pull requests, the CCR decisions, the spine counts against the plan in `docs/prompts/00-INDEX.md`, anything deferred, and which prompts the owner should launch next.
