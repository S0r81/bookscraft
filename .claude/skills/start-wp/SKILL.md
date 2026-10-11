---
name: start-wp
description: Start or resume a BooksCraft work package by its id. Use when asked to start, resume or continue a work package, for example "/start-wp W1-02" or "continue W2-03".
argument-hint: "<WP id, for example W1-02>"
---

# Start or resume work package $0

Follow these steps in order. Stop and report at the first check that fails. GitHub calls use the REST API (`gh api`), because GraphQL (`gh pr ...`) is blocked in cloud sessions.

## 1. Identify the work package

1. `$0` must look like `W<wave>-<nn>`, for example `W0-01` or `W3-04`. If it ends in `-W` it is a Weave: stop and tell the user to run `/weave <wave>` instead.
2. Find its prompt: `ls docs/prompts/$0-*.md` must list exactly one file. Read it in full.
3. In `docs/coordination/OWNERSHIP.md`, find the row for `$0`. Note its agent and branch. Read `.claude/agents/<agent>.md` in full and work in that role.
4. Read `CLAUDE.md` §8. If the `Signed-off-by` line still says `SIGNOFF_NAME`, stop and ask the owner which name and email to use. Do not commit until the owner has answered and the line is filled in on `main`.

## 2. Check preconditions

1. Run `git fetch origin --prune`.
2. Check every item in the prompt's **Preconditions** section against `origin/main`, using the command the item gives. If any item is false, stop and report which one, with the command output.

## 3. Get onto the branch

Use the branch name from the OWNERSHIP row.

- If `git ls-remote --heads origin <branch>` prints a line, the work package was started before. Run `git switch <branch>`, or `git switch -c <branch> --track origin/<branch>` if there is no local branch. If `origin/main` has commits the branch lacks, run `git merge --no-edit origin/main` (never rebase).
- Otherwise run `git switch -c <branch> origin/main`.

## 4. Pick up earlier work

1. If `docs/coordination/handoffs/$0.md` exists on the branch, read it. Start from its **Next** list. Its **Do not redo** list is binding.
2. Look for an open pull request: `gh api repos/S0r81/bookscraft/pulls --method GET -f head=S0r81:<branch> -f state=open --jq '.[] | [.number, .html_url] | @tsv'`. If there is one, read its description and comments (`gh api repos/S0r81/bookscraft/issues/<number>/comments --jq '.[].body'`).
3. List the CCRs this work package already raised: `ls docs/coordination/CCR/CCR-$0-*.md`.

## 5. Read and plan

1. Read every file in the prompt's **Read first** list, in full.
2. Write a plan of five to ten lines: the owned paths, the acceptance criteria, and the order of the tasks. Then start the first task.

## 6. While working

- Edit only the owned paths. A hook refuses other edits on `wp/*` branches. If you need a change elsewhere, run `/ccr`.
- Make small Conventional Commits and push after each one with `git push -u origin <branch>`. A cloud sandbox can restart from a fresh clone, and anything unpushed is lost.
- If you must stop before the work is done (context nearly full, blocked, timebox reached), run `/handoff`.

## 7. Finish

1. Run every command in the prompt's **Verify** section, then `cargo xtask scope $0`. All of them must pass.
2. Write the pull request description into a temporary file, following `.github/pull_request_template.md`: tick every acceptance criterion and paste the command and its output under it. The last line is the sign-off line from `CLAUDE.md` §8.
3. If no pull request exists, open one with the title from the prompt's **Deliverables** section:
   `gh api repos/S0r81/bookscraft/pulls -X POST -f title="<title>" -f head="<branch>" -f base=main -F body=@<file>`
   If one exists, post the new description as a comment: `gh api repos/S0r81/bookscraft/issues/<number>/comments -X POST -F body=@<file>`.
4. Report the pull request link, the status of each acceptance criterion, the spine summary and any CCRs raised.
