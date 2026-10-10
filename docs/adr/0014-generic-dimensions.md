---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, ledger-engineer
---

# Generic dimensions with Class, Location and Project presets

## Context and Problem Statement

I-8 requires generic, uncapped dimensions with Class, Location and Project as presets. The brief puts the dimension feature in v1 but needs dimension refs in the MVP migrator (C-5).

## Decision Drivers

* No caps (I-9).
* The migrator must keep QBO Class and Department refs.
* Reports filter and group by dimension.

## Considered Options

* `dimension` and hierarchical `dimension_value` tables; link tables for document, line and posting dimensions
* A JSON column of dimension values on postings (brief §4.2)
* Fixed class and location columns

## Decision Outcome

Chosen option:

* Link tables `document_dimension`, `document_line_dimension` and `posting_dimension`, with one value per dimension per row, indexed by value.
* Presets `class` (line level), `location` (document level) and `project` (line level) are created with every company.
* Line values win over document values when copied to postings.
* MVP ships the schema, posting propagation, import and report filters. The dimension management UI is v1 (C-5).

### Consequences

* Good, because grouping and filtering use plain indexed joins, with no JSON parsing in reports.
* Good, because there are no limits.
* Bad, because there are more rows per posting. Indexed link tables handle the volume.

### Confirmation

T-BOOKS-2 (200 dimensions × 1,000 values), T-POST-4 (propagation golden), spine steps S06 and S15.

## Pros and Cons of the Options

### Link tables

* Good, because they are relational, indexable and unlimited.

### JSON on postings

* Bad, because they are hard to index and validate in SQLite.

### Fixed columns

* Bad, because they cap dimensions at two (I-8).

## More Information

LEDGER_SPEC §3 rule 7; schema.sql sections 2 to 4.
