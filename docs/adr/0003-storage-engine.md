---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, storage-engineer
---

# Storage engine: SQLite only, one file per company

## Context and Problem Statement

The brief proposed PostgreSQL with SQLite as a "solo mode". The owner made desktop a first-class target and asked for one engine unless two can be justified. How should data be stored?

## Decision Drivers

* Local-first: a company is one file the user owns, backs up and moves.
* One engine keeps the test matrix single (two engines would double it).
* Server mode must come from the same core.
* Balance and immutability must be enforced in storage, not only in code (I-3).

## Considered Options

* SQLite only (bundled via rusqlite): one file per company plus one system file
* SQLite for desktop plus PostgreSQL for server
* PostgreSQL only
* sqlx instead of rusqlite as the driver

## Decision Outcome

Chosen option: **SQLite only**, through `rusqlite` 0.40 with the `bundled` feature:

* One company file per company (`*.bookscraft`) plus one system file.
* WAL mode and `STRICT` tables.
* The file is accessed only by the BooksCraft process that holds its lock.
* Forward-only migrations, with a backup before each upgrade.

The same binary runs embedded in the desktop app and standalone as the server.

### Consequences

* Good, because backup, export and ownership are trivial: one file, copied with the online backup API.
* Good, because CI runs one engine on three OSes.
* Good, because triggers enforce the ledger rules ([schema.sql](../architecture/schema.sql), verified against SQLite 3.45.1).
* Bad, because there is one writer per company file. That is fine for small businesses: transactions are short, and `BEGIN IMMEDIATE` plus a 5 s busy timeout handle bursts.
* Bad, because company files must live on local disks (WAL does not work on network filesystems); the UI warns.
* Bad, because there is no encryption at rest in MVP (G-14). SQLCipher is evaluated in v1 and would change the file format, so it is flagged as expensive to reverse.

### Confirmation

* The store test `schema_matches_spec` keeps the migrations equal to `docs/architecture/schema.sql`.
* T-STORE-1 through T-STORE-20 ([DATA_MODEL.md](../architecture/DATA_MODEL.md) §6).
* Lint: no `postgres`, `sqlx` or `diesel` dependency (cargo-deny bans).

## Pros and Cons of the Options

### SQLite only

* Good, because it has zero administration and is embedded.
* Good, because "one company = one file" matches what Desktop users expect.
* Bad, because there is no concurrent multi-writer scaling (not needed by the target users).

### SQLite + PostgreSQL

* Good, because it scales hosted multi-tenant later.
* Bad, because it doubles migrations, triggers and tests, and SQL dialect differences leak into services.

### PostgreSQL only

* Bad, because a desktop app would have to bundle or require a database server.

### sqlx

* Good, because it is async and checks queries at compile time.
* Bad, because the services are synchronous by design (ports), compile-time checking needs a database at build time, and rusqlite gives direct control of pragmas, the backup API and hooks.

## More Information

[DATA_MODEL.md](../architecture/DATA_MODEL.md) §2 (open sequence, locking, concurrency, evolution); BRIEF_AUDIT OV-2, OV-3, G-12, G-13, G-14, G-22.
