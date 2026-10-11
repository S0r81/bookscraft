---
name: ccr
description: Raise a contract change request (CCR) for the current BooksCraft work package. Use whenever the work needs a change outside the work package's owned paths - a shared type, a service port, a schema migration, a dependency, a route or page registration, another crate's code - instead of making that change yourself.
argument-hint: "<one-line title of the change>"
---

# Raise a CCR: $ARGUMENTS

1. Run `git branch --show-current`. It must be `wp/<WP>-<slug>`; take `<WP>` from it. On a `weave/*` branch you are the decider: implement the change directly instead.
2. Pick the number: list `docs/coordination/CCR/CCR-<WP>-*.md`; `<n>` is one more than the highest number there, or 1.
3. Copy `docs/coordination/CCR/TEMPLATE.md` to `docs/coordination/CCR/CCR-<WP>-<n>-<slug>.md` (`<slug>`: three to five lower-case words joined by hyphens). Fill in every field:
   - **Contract affected:** exact paths and items (type, field, trait method, table, crate version).
   - **Blocking?:** yes with the acceptance criteria that cannot pass, or no with the workaround.
   - **Problem:** what you need and the evidence: spec section, failing test name and output, or error.
   - **Proposed change:** the exact signature, struct, DTO, error code or SQL. For schema changes, the full migration SQL. Keep it minimal.
   - **Alternatives considered:** at least one, including doing nothing.
   - **Impact:** crates, work packages, spine steps and docs affected.
   - **Workaround in place:** what you did inside your owned paths, and how to remove it once the CCR lands.
   Leave the **Decision** section empty: only a Weave fills it in.
4. Do not make the contract change. If you can, keep working with a workaround inside your owned paths, for example a local helper, or a test marked `#[ignore = "CCR-<WP>-<n>"]`.
5. Commit it as `docs(ccr): CCR-<WP>-<n> <title>` and push.
6. List the CCR under "CCRs raised" in the pull request description. If the pull request already exists, add a comment that links the CCR file.
7. Continue with the work that does not depend on the CCR. If every remaining acceptance criterion depends on it, run `/handoff` and stop.
