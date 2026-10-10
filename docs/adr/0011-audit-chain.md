---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, storage-engineer, security-reviewer
---

# One hash-chained audit log per file

## Context and Problem Statement

I-6 requires an append-only, hash-chained audit log with the actor type (user, api, agent) and before and after state. The brief proposed two chains, one on journal entries and one on audit events (C-4).

## Decision Drivers

* Tamper evidence that one tool can verify.
* No duplicate integrity mechanisms to keep in sync.
* Must work in SQLite without extensions.

## Considered Options

* One chain in `audit_event`; journal entries carry a `content_hash` committed by the posting's audit event
* Two chains (journal entries and audit events)
* No chain, only an append-only table

## Decision Outcome

Chosen option: **one chain per file** (company file, system file).

* Each event's `hash = SHA-256(prev_hash ‖ "\n" ‖ canonical JSON of the row)`.
* The `document.post` event includes the `content_hash` of each new entry, so the chain also covers the ledger.
* Storage triggers refuse updates, deletes, sequence gaps and wrong `prev_hash` links. The writer computes hashes.
* `bookscraft verify` recomputes everything (quick mode on every open).
* Actor types are exactly user, api and agent; `via` records the channel.

### Consequences

* Good, because there is one place to verify and one algorithm.
* Bad, because it is tamper-evident, not tamper-proof: whoever holds the file can rewrite the whole chain (R-5). Hosted or third-party anchoring of the head hash is a later option.

### Confirmation

T-STORE-5 (triggers), T-STORE-6 (verify detects edits), T-AUDIT-1 (every mutating command audits with the right actor).

## Pros and Cons of the Options

### One chain

* Good, because it is simple and covers documents and ledger together.

### Two chains

* Bad, because it duplicates logic, and the chains can disagree.

### No chain

* Bad, because it does not meet I-6.

## More Information

LEDGER_SPEC §10; schema.sql section 7.
