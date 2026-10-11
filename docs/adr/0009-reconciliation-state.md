---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, bank-feeds-engineer
---

# Reconciliation state lives outside postings, keyed by stable line keys

## Context and Problem Statement

The brief put mutable `cleared_state` and `reconciliation_id` columns on postings (C-3), which contradicts append-only postings (I-3). Also, an edit replaces postings, which would lose their clearing state (G-6).

## Decision Drivers

* Postings never change.
* Clearing must survive edits that leave the bank-side line unchanged.
* Editing a reconciled line must be loud, audited and safe.

## Considered Options

* An append-only `clearing_event` table keyed by (account, line key); reconciliations frozen on completion
* Mutable flags on postings
* Clearing state stored on documents

## Decision Outcome

Chosen option:

* Every posting carries a **stable `line_key`** (LEDGER_SPEC §3), so the money-side line of a document keeps its key across reposts.
* Clearing state is the latest `clearing_event` for (account, line key).
* A completed `reconciliation` freezes its lines (`reconciliation_line`) and a `snapshot_hash`.
* A repost or void that changes a reconciled posting's account, amount or date is refused (`reconciliation.reconciled_line_changed`) until the user unreconciles that line with a reason. That step is audited, and the old reconciliation then shows as discrepant.

### Consequences

* Good, because postings stay immutable, and clearing survives harmless edits (memo, other lines).
* Good, because the reconciliation report is reproducible from its snapshot.
* Bad, because reading the current state is a "latest event" query. It is served by an index and the `clearing_state` view.

### Confirmation

T-BANK-3 (completion rules and snapshot hash), T-BANK-4 (reconciled-line rule), schema triggers on `clearing_event`, `reconciliation` and `reconciliation_line` (T-STORE-14).

## Pros and Cons of the Options

### Clearing events plus line keys

* Good, because it is consistent with append-only design and complete history.

### Mutable posting flags

* Bad, because they violate I-3.

### On documents

* Bad, because a document can have several money-side lines (deposits, journal entries).

## More Information

LEDGER_SPEC §11; schema.sql section 5; BRIEF_AUDIT C-3, G-6.
