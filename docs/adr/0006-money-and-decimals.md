---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, ledger-engineer
---

# Money as i64 minor units; decimals for rates and quantities; no REAL columns

## Context and Problem Statement

I-1 fixes money as `i64` minor units plus an ISO 4217 code, with FX rates as decimals and no floats. Still open:

* How are quantities, unit prices and tax rates represented?
* How are decimals stored in SQLite without float coercion?
* What exactly is the rounding rule?

## Decision Drivers

* Exactness to the cent (MVP exit criterion).
* SQLite's `NUMERIC` and `REAL` affinities can silently store decimals as 8-byte floats.
* Imported documents must keep the source's amounts.

## Considered Options

* `i64` minor units for amounts; `rust_decimal` for rates, quantities and prices, stored as canonical `TEXT`
* `i128` amounts
* Decimal amounts everywhere
* Scaled integers for rates (for example rate × 10^10 in an `INTEGER`)

## Decision Outcome

Chosen option:

* **`money::Minor(i64)`** amounts with a `Currency`, using checked arithmetic that returns `money.overflow`.
* **`rust_decimal::Decimal`** for quantities, unit prices, percentages and FX rates, stored as canonical `TEXT` (`normalize()`, no exponent). No `REAL` or `NUMERIC` column exists anywhere.
* Line amounts are rounded once, at entry, with `round_half_up` and stored; stored amounts are authoritative.
* Tax per component uses the company setting `rounding.tax` (`half_up` default, `half_even` optional).
* Splits use `money::allocate` (largest remainder; LEDGER_SPEC §7), which leaves no residue.
* Residues that cannot be avoided (FX base conversion, source-side rounding on import up to ±2 minor units) post to the account with system role `rounding`.

### Consequences

* Good, because sums are exact and serialization is lossless (`"5097.70"` strings).
* Good, because `i64` covers ±92 quadrillion minor units, enough for any small business.
* Bad, because `TEXT` decimals cannot be summed in SQL. Nothing needs to: SQL sums only the integer amounts.

### Confirmation

* Clippy `disallowed-types` (`f32`, `f64`) in `money`, `ledger` and `posting`, plus the `cargo xtask lint` token scan (T-MONEY-2).
* Proptests T-MONEY-1 (overflow), T-MONEY-3 (allocate), T-MONEY-4 (serde round trip).
* Schema CHECKs on every decimal column (schema.sql).

## Pros and Cons of the Options

### i64 minor units + TEXT decimals

* Good, because it is exact and simple.
* Neutral, because currency minor digits come from an ISO 4217 table in `money`.

### i128

* Bad, because SQLite integers are 64-bit, so storage would need TEXT or BLOB.

### Decimal amounts everywhere

* Bad, because they invite fractional cents and need rounding discipline at every boundary.

### Scaled-integer rates

* Bad, because a fixed scale must be chosen for every kind of rate, and it is easy to mis-scale.

## More Information

LEDGER_SPEC §8; DATA_MODEL §1; BRIEF_AUDIT OV-3, G-1, G-2.
