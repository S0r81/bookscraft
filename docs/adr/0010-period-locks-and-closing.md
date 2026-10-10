---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, ledger-engineer
---

# Period locks as two lock dates; no closing entries

## Context and Problem Statement

I-5 requires open, soft-locked and hard-locked periods, with hard-locked periods immutable and every override audited. The brief's `period_lock(lock_date, kind)` is a lock-date model (C-8). The MVP exit compares the trial balance with QuickBooks, which posts no closing entries (C-9).

## Decision Drivers

* A locked period must never follow an open one.
* Overrides are explicit, reasoned and audited.
* Trial balance parity with QBO.

## Considered Options

* Two dates per company (`hard_locked_through` ≤ `soft_locked_through`) plus per-entry `lock_override` rows; retained earnings computed at report time
* A per-period status table (open, soft, hard per month)
* Posting year-end closing entries to retained earnings

## Decision Outcome

Chosen option:

* Two lock dates on `company`, with a CHECK keeping hard ≤ soft.
* The finalize trigger refuses entries dated on or before the hard date.
* For soft-locked dates it requires a `lock_override` row (reason of 5 or more characters, actor) for that entry. Only `period.override` holders can create one, and each creates an audit event.
* Moving the hard date earlier requires the owner role and a reason.
* No closing entries: retained earnings and current-year net income are computed by the reports.

### Consequences

* Good, because the rule is simple and order-preserving by construction.
* Good, because trial balances compare with QuickBooks's directly.
* Bad, because there are no per-period exceptions (for example re-opening only March). That is intentional: a correction goes into an open period.

### Confirmation

T-STORE-12 (trigger), T-BOOKS-1 (audited lock changes, owner-only unlock), spine step S30.

## Pros and Cons of the Options

### Two dates

* Good, because it cannot represent a locked-after-open state.

### Per-period table

* Bad, because it allows holes, and the rules get complicated.

### Closing entries

* Bad, because they break trial balance parity with QBO and add entries users did not make.

## More Information

LEDGER_SPEC §9; schema.sql `company`, `lock_override`, `journal_entry_finalize`.
