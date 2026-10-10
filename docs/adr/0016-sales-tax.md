---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, ledger-engineer
---

# Manual sales tax in MVP; automated rates behind a provider trait

## Context and Problem Statement

The brief contradicts itself: §7.3 puts manual sales tax in MVP, while §3 and §9 put it in v1 (C-1). Invoices and the QBO migrator, both MVP, carry tax lines. Automated US rates span thousands of jurisdictions.

## Decision Drivers

* MVP invoices for taxable goods must be correct.
* Imported QBO tax must keep its amounts and per-agency liabilities.
* Thresholds and rates change every year (CV-8): data, never code.

## Considered Options

* MVP: manual agencies, rates and tax codes, per-agency liability, liability report; `TaxRateProvider` trait for later automation
* Defer all sales tax to v1
* Build an address-based rate engine

## Decision Outcome

Chosen option (owner default, Q-7):

* **MVP** ships tax agencies (each with its own liability account), rates (percent), tax codes (groups of rates), per-component computation and rounding (LEDGER_SPEC §4.1 and §8.1), the sales tax liability report, and imported amounts kept as received.
* **v1** adds tax payment and filing records.
* **Later**, automated providers implement `TaxRateProvider`.
* Paying tax in MVP is an expense against the agency's liability account.

### Consequences

* Good, because agencies' invoices are correct from day one, and the migrator preserves QBO tax exactly.
* Bad, because users must maintain their rates manually until a provider exists.

### Confirmation

Spine S06 (INV-1002: tax 62.70 on a 760.00 base), the sales tax liability golden in Appendix A, T-POST-3 goldens for tax-inclusive and discount cases.

## Pros and Cons of the Options

### Manual MVP plus provider trait

* Good, because it is correct, small and extensible.

### Defer to v1

* Bad, because MVP invoices could not carry tax, and the migrator would lose data.

### In-house engine

* Bad, because it is huge, and the tax data changes constantly (brief §7.3).

## More Information

LEDGER_SPEC §4.18; ARCHITECTURE §8.
