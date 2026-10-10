---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, qa-verifier
---

# Scenario spine: a QA-owned month of bookkeeping, activated by capabilities

## Context and Problem Statement

Parallel work packages must prove they weave together. Unit tests per crate cannot show that an invoice, a payment, a deposit and a reconciliation agree end to end. The spine must exist from Wave 0, while most features do not exist yet.

## Decision Drivers

* One executable story that every PR keeps green.
* Builders must never edit the spine (it is a shared hotspot).
* Expected numbers fixed in advance, from the spec, not from the code.

## Considered Options

* A QA-owned crate (`tests/scenarios`) whose steps each declare required capabilities; a step runs when every capability is registered and otherwise reports `pending`; golden reports from LEDGER_SPEC Appendix A
* One end-to-end test that every package edits
* Per-package integration tests only

## Decision Outcome

Chosen option: **capability-gated spine**.

* W0-03 writes all 31 steps and the golden trial balance, P&L (accrual and cash), balance sheet, agings, sales tax liability and reconciliation.
* Steps drive real services through `app::compose` (no HTTP).
* `cargo xtask spine` reports passed, failed and pending steps; CI job `spine` fails on any failed step.
* A crate registers a capability only when it is complete, so pending steps light up as packages merge.
* Only QA and Weave sessions edit the spine.

### Consequences

* Good, because integration is proven continuously, and the expected values were computed independently: the reference model in Appendix A matched the hand calculation to the cent.
* Bad, because a capability registered too early fails the spine. That is intended: the owning package must finish the feature.

### Confirmation

CI `spine` is a required check. Each Weave's acceptance includes the count of pending steps going down, as planned in [00-INDEX.md](../prompts/00-INDEX.md).

## Pros and Cons of the Options

### Capability-gated spine

* Good, because it exists from day one, and no builder edits it.

### Shared end-to-end test

* Bad, because it is a merge hotspot, and its expected values drift with the code.

### Per-package tests only

* Bad, because they do not prove the packages weave together.

## More Information

[LEDGER_SPEC.md](../architecture/LEDGER_SPEC.md) Appendix A; ARCHITECTURE §4.4.
