---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect
---

# Record architecture decisions as MADR files

## Context and Problem Statement

BooksCraft is built by several parallel Claude Code sessions with no shared memory beyond the repository. Decisions must be findable, reviewable and changeable through one process.

## Decision Drivers

* Builder sessions have zero context beyond the repo.
* Decisions must state the alternatives considered (owner rule).
* Changing a contract goes through a Weave, so decisions need a stable home to point at.

## Considered Options

* MADR 4.0 files in `docs/adr/`, one per decision
* Decisions recorded only inside the specs
* A wiki outside the repository

## Decision Outcome

Chosen option: MADR 4.0 files in `docs/adr/NNNN-title.md`, because they live next to the code, are reviewed in PRs and read by every session.

### Consequences

* Good, because every spec can link to the decision behind it.
* Good, because a superseding ADR leaves the old one in place with `status: superseded by ADR-NNNN`, so history is never rewritten.
* Bad, because ADRs and specs can drift; the Weave checks both when a CCR changes either.

### Confirmation

* The Weave checklist ([docs/prompts/00-INDEX.md](../prompts/00-INDEX.md)) requires a new or updated ADR for any accepted CCR that changes a decision.
* Numbers are assigned only in a Weave, which avoids collisions between parallel sessions.

## Pros and Cons of the Options

### MADR files in the repo

* Good, because they are versioned with the code and reviewable.
* Neutral, because the format has a little boilerplate.

### Decisions only in specs

* Bad, because the alternatives and reasons get lost.

### External wiki

* Bad, because builder sessions cannot see it.

## More Information

[MADR](https://adr.github.io/madr/); [BRIEF_AUDIT.md](../architecture/BRIEF_AUDIT.md) §9 holds the original register.
