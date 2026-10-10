---
name: handoff
description: Write a handoff note so another session can continue the current BooksCraft work package. Use when a session must stop before its work package is done (context nearly full, blocked on a CCR, timebox reached) or when asked to hand off.
---

# Hand off the current work package

1. Run `git branch --show-current`. It must be `wp/<WP>-<slug>`; take `<WP>` from it. On any other branch, stop: Weaves finish or report, they do not hand off.
2. Commit everything you changed, even if it is unfinished, so nothing exists only in this sandbox. Use `wip(<scope>): <what>` for unfinished work. Run `cargo check --locked -p <crate>` for each crate you touched and note in the handoff whether it compiles.
3. Write `docs/coordination/handoffs/<WP>.md`, replacing any earlier note (the old one stays in git history). Use exactly the five sections from `docs/coordination/handoffs/README.md`:
   1. **State:** branch, last commit (`git rev-parse --short HEAD`), pull request link if any, CI status, whether the touched crates compile.
   2. **Done:** acceptance criteria that already pass, each with the command that proves it.
   3. **Next:** the next one to five concrete steps, in order, specific enough to start without rereading everything.
   4. **Open problems:** failing tests (name and one line of the error), unknowns, CCRs raised (links).
   5. **Do not redo:** decisions already taken in this work package and why.
4. Commit it as `docs(<WP>): handoff note` and push: `git push -u origin <branch>`.
5. If a pull request is open (`gh api repos/S0r81/bookscraft/pulls --method GET -f head=S0r81:<branch> -f state=open --jq '.[0].number'`), comment on it with a link to the note: `gh api repos/S0r81/bookscraft/issues/<number>/comments -X POST -f body="Handoff: docs/coordination/handoffs/<WP>.md at <commit>"`.
6. End with the note's **Next** list and this line for the owner: "Continue in a new session with `/start-wp <WP>`."
