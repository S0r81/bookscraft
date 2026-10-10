---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, ledger-engineer
---

# Cash basis derived from the settlement graph at report time

## Context and Problem Statement

I-4: one accrual ledger; cash basis is derived from the payment-application graph, never stored. What exactly is the algorithm?

## Decision Drivers

* No second ledger.
* Exact cents: a fully paid document recognizes exactly its accrual amounts.
* Deterministic and testable.

## Considered Options

* Report-time recognition by cumulative allocation over active settlements
* Storing cash-basis postings alongside accrual
* Recognizing whole documents only when fully paid

## Decision Outcome

Chosen option: the algorithm in LEDGER_SPEC §7.

* Documents without AR/AP postings are recognized at their date.
* Payments and refunds recognize their money lines at their date and an "unapplied" report line for open credit.
* Accrual documents recognize their non-AR/AP postings at each settlement date, by `allocate(−cum_k, w) − allocate(−cum_{k−1}, w)`, where `cum_k` is the running total of settled amounts, each signed by the side of the document it settles (so documents with AR or AP postings in both directions also recognize exactly their accrual amounts).

### Consequences

* Good, because it is exact, deterministic and stores nothing derived.
* Good, because partial payments recognize proportional income and sales tax.
* Bad, because cash-basis figures can differ from QuickBooks's own allocation in the last cent. MVP measures cash-basis parity but does not gate on it (R-3).

### Confirmation

T-REP-1 (proptest: the cash trial balance balances, and fully settled documents equal accrual), T-SPINE-CASH (spine golden: net income 7,185.85 for March 2026).

## Pros and Cons of the Options

### Cumulative allocation at report time

* Good, because it is correct by construction, with no drift.

### Stored cash postings

* Bad, because it is a second ledger that must be kept in sync (violates I-4).

### Whole-document recognition

* Bad, because partial payments would misstate income.

## More Information

LEDGER_SPEC §7 and Appendix A.
