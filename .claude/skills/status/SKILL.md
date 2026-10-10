---
name: status
description: Show BooksCraft project status - the board, open pull requests with their checks, open CCRs, and what can be launched next. Use when asked for status, progress, what is blocked, or what to start next.
---

# BooksCraft status

This skill only reads. It changes no file. GitHub calls use the REST API (`gh api`).

1. Run `git fetch origin --prune --quiet`. Read the board as it is on `main`: `git show origin/main:docs/coordination/BOARD.md`.
2. List open pull requests: `gh api "repos/S0r81/bookscraft/pulls?state=open&per_page=100" --jq '.[] | [.number, .head.ref, .head.sha, .title] | @tsv'`.
3. For each pull request, read its check runs: `gh api "repos/S0r81/bookscraft/commits/<sha>/check-runs?per_page=100" --jq '.check_runs[] | [.name, .status, .conclusion] | @tsv'`. Summarize as green, red (name the failing jobs) or running.
4. CCRs: read the Status field of each `docs/coordination/CCR/CCR-*.md` on `origin/main` (`git ls-tree --name-only origin/main docs/coordination/CCR/`), and list CCR files added by open pull requests (`gh api "repos/S0r81/bookscraft/pulls/<number>/files?per_page=100" --jq '.[].filename'`).
5. Print one table with the columns WP, wave, board state, pull request, checks, CCRs, next action. Then list:
   - work packages ready to launch (their wave is open and their preconditions are merged) that have no branch yet (`git ls-remote --heads origin "wp/*"`);
   - work packages that are blocked, and why;
   - whether the wave is ready for its Weave (every pull request green, or deferred).
