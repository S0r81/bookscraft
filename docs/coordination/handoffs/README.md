# Handoff notes

When a session must stop before its work package (WP) is done (context nearly full, blocked, or out of time), it runs `/handoff`. That writes `docs/coordination/handoffs/<WP>.md` on the WP branch, commits and pushes it, and comments on the open PR with a link to the note (a handoff never edits the PR description, which the opening session wrote, sign-off line included). The next session for the same WP starts with `/start-wp <WP>`, which finds the branch and the note and continues from it.

A handoff note has exactly these sections:

1. **State:** branch, last commit, PR link, CI status.
2. **Done:** acceptance criteria already passing, with the command that proves each.
3. **Next:** the next 1–5 concrete steps, in order.
4. **Open problems:** failing tests, unknowns, CCRs raised (with links).
5. **Do not redo:** decisions already taken in this WP and why.

Each WP owns only its own note, so concurrent sessions never edit the same file. Notes stay in the history after merge.
