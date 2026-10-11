---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect
---

# Background jobs: in-process runner over a jobs table in the system file

## Context and Problem Statement

Email sends, imports, exports, bank syncs, backups, verify runs and scheduled reversing entries run outside a request (G-21). The desktop has no external services, and the server should stay one binary.

## Decision Drivers

* No external queue or broker.
* Jobs survive restarts.
* Same behaviour on desktop and server.

## Considered Options

* `job` table in the system file plus one runner thread per process (`app`)
* An external queue (Redis, NATS)
* A job-queue crate (apalis 0.7)

## Decision Outcome

Chosen option: **in-process runner**.

* The runner claims due jobs (`status = queued AND run_after <= now`, oldest first) inside a transaction.
* It runs each job as its creating principal and records the result or a problem-details error.
* Retries back off at 1, 5 and 30 minutes, then the job fails.
* The CLI runs jobs inline.
* Job kinds are a closed enum in `domain` (contract).

### Consequences

* Good, because there are no extra moving parts, and jobs can be inspected with the API (`GET /jobs/{id}`).
* Bad, because there is no horizontal scaling. Not needed: one process owns each company file.

### Confirmation

W1-05 tests: claim is exclusive, retry and backoff, and a crash leaves the job `queued` (runner restart). W4-02 tests: CLI inline run.

## Pros and Cons of the Options

### In-process runner

* Good, because it is simple, durable and identical in every mode.

### External queue

* Bad, because it is another service to run and breaks "one binary".

### apalis

* Neutral, because it is capable.
* Bad, because it is async-first, a large dependency surface, and duplicates the store's transaction handling.

## More Information

schema-system.sql `job`; ARCHITECTURE §12.
