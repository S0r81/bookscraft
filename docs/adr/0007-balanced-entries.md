---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, ledger-engineer, storage-engineer
---

# Balanced entries: a type that cannot be unbalanced plus a finalize-on-post trigger

## Context and Problem Statement

I-3 requires balance enforcement in both the type system and storage. SQLite has no deferred constraints, which the brief's PostgreSQL design relied on. How do we enforce "every entry sums to zero" and "postings are append-only"?

## Decision Drivers

* Defense in depth: an application bug must not be able to write an unbalanced entry.
* Postings are immutable after posting; a void is a reversal.
* It must work in SQLite (ADR-0003).

## Considered Options

* `ledger::BalancedEntry` (validating constructor only) plus a two-phase `open` → `final` entry, with a trigger that checks the sums at finalize and freezes everything after
* Application-only checks
* Per-row running-sum constraints

## Decision Outcome

Chosen option:

1. **Type level.** `BalancedEntry::new` is the only way to build an entry. It rejects fewer than two lines, a non-zero base sum, and, when every line shares a currency, a non-zero transaction sum.
2. **Storage level.** Entries are inserted `open`, then their postings, then one `UPDATE ... SET state = 'final'`. The `journal_entry_finalize` trigger checks line count, both sums, period locks, and that a reversal mirrors its original. After `final`, triggers refuse every update and delete of the entry, its postings and its posting dimensions. A transaction never commits with an `open` entry (store pre-commit check).
3. **Drafts** are documents, never journal entries.

### Consequences

* Good, because both layers enforce the same rules, and error codes are shared (`ledger.unbalanced`, ...).
* Good, because an edit is a reversal plus a new entry, so history is complete.
* Bad, because there are two code paths to keep consistent. Shared test vectors run against both.

### Confirmation

T-LEDGER-1 (proptest on the constructor), T-STORE-1..4 (one test per trigger), T-PROP-1 (random document sequences keep the trial balance at zero). The 78-case trigger smoke test used to write the schema is the seed for T-STORE.

## Pros and Cons of the Options

### Type plus finalize trigger

* Good, because it is enforced where data is written, even by a buggy service.
* Neutral, because the finalize step is one extra UPDATE per entry.

### Application only

* Bad, because a single bug corrupts the books silently.

### Running-sum constraints

* Bad, because SQLite cannot express them without triggers on every insert, and partial entries would fail mid-insert.

## More Information

[schema.sql](../architecture/schema.sql) section 4; DATA_MODEL §4.3 and §5; BRIEF_AUDIT OV-9.
