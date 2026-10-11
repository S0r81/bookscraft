---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, ledger-engineer
---

# Document revisions and versioned posting rules

## Context and Problem Statement

Users edit posted documents. Posting rules will change over time. How do we keep history reproducible and know which rule produced each entry?

## Decision Drivers

* I-2: posting is a pure, deterministic, versioned function.
* I-3: posted content never changes; edits are reversals plus new entries.
* Audit needs to show what the document looked like at each posting.

## Considered Options

* Document revisions (lines stored per revision, immutable once posted) plus a `rules_version` per entry
* Repost in place with one global rules version
* Event-sourced documents (store only commands)

## Decision Outcome

Chosen option:

* A document starts as a draft (`revision = 0`, lines at revision 0, mutable).
* Posting copies the lines to revision 1 and posts entry `E1`.
* An edit writes lines at revision n+1, reverses `E_n` and posts `E_{n+1}`, in one transaction.
* Every entry stores `rules_version` (for example `invoice@1`).
* Old entries are never re-posted under new rules. A new rules version applies only to documents posted or edited after it ships.
* Each rules version has its own golden files.

### Consequences

* Good, because any past posting can be reproduced from its revision snapshot and rules version.
* Good, because the audit log, revisions and entries line up.
* Bad, because storage grows with every edit. That is acceptable: edits are rare compared with documents.

### Confirmation

T-POST-1 (determinism), T-POST-3 (golden files per type and version), schema triggers `document_line_snapshot_*` and `document_posted_financial_fields` (T-STORE-7, T-STORE-8).

## Pros and Cons of the Options

### Revisions plus rules versions

* Good, because it is reproducible and auditable.

### Repost in place

* Bad, because history is lost and rule changes silently restate the past.

### Event sourcing

* Good, because it is the most complete history.
* Bad, because it is complex for builders, and reporting would need projections. That is overkill for MVP.

## More Information

LEDGER_SPEC §3 and §6; DATA_MODEL §4.2 and §4.3; BRIEF_AUDIT G-5.
