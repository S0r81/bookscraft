---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect
---

# Parallel development model: contract-first waves, ownership, CCRs, Weaves

## Context and Problem Statement

Several Claude Code sessions build BooksCraft at the same time. Their work must merge cleanly, and `main` must stay green. How do we organize work?

## Decision Drivers

* Sessions share nothing but the repository.
* Shared files are where merges break (BRIEF_AUDIT R-4).
* Accounting code needs independent verification (R-6).

## Considered Options

* Contract-first Wave 0, then waves of 3–5 work packages with disjoint owned paths; contract changes only through CCRs processed in a Weave at the end of each wave
* Trunk-based development without ownership
* One long-lived branch per area merged at the end

## Decision Outcome

Chosen option: the first one.

**Wave 0** runs sequentially and fixes the workspace, pinned dependencies, contracts (`domain`, `api-types`, `money`), the test harness and spine, storage and the ledger core.

**Later waves:**

* Each work package owns specific paths ([OWNERSHIP.md](../coordination/OWNERSHIP.md), mirrored in CODEOWNERS).
* Packages run concurrently and depend only on merged contracts.
* A builder that needs a shared change writes a CCR and continues with what it can do.
* Each wave ends with a Weave by the lead-architect, which:
  * merges in order;
  * runs the full suite on three OSes plus the spine;
  * processes CCRs;
  * updates docs and the board.

**Hotspot rules** are in ARCHITECTURE §7 and OWNERSHIP.md.

**Enforcement:**

* the `cargo xtask scope <WP>` check in CI (`scope` job);
* a PreToolUse hook that refuses edits outside owned paths on `wp/*` branches;
* `--locked` builds;
* fixed constructors and pre-registered modules.

### Consequences

* Good, because merges are mechanical and conflicts are rare and confined to Weaves.
* Bad, because Wave 0 is a sequential bottleneck, and a missing contract stalls a line of work until the next Weave. CCRs keep the rest of the package moving.

### Confirmation

The `scope` and `lint` CI jobs are required; each Weave prompt's acceptance includes "zero files changed outside owned paths in merged PRs".

## Pros and Cons of the Options

### Contract-first waves

* Good, because parallelism is safe and responsibility is clear.

### Trunk-based without ownership

* Bad, because parallel agents collide in shared files.

### Long-lived branches

* Bad, because integration comes late, as a big bang.

## More Information

[PARALLEL_DEV_PLAYBOOK.md](../process/PARALLEL_DEV_PLAYBOOK.md); [docs/prompts/00-INDEX.md](../prompts/00-INDEX.md).
