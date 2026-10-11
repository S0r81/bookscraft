---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, ledger-engineer
---

# Own account classification with explicit system roles

## Context and Problem Statement

The brief suggests a "QBO-API-shaped schema" and a QBO-compatible type taxonomy (C-12). The QBO AccountType list is in the unverified Caveats (CV-7). Special behaviour (AR, AP, undeposited funds, retained earnings) must key off something stable.

## Decision Drivers

* No architectural decision may depend on the Caveats.
* Clean room: our model, mapped to QBO's at the edge.
* Reports need a small, fixed set of classes.

## Considered Options

* Five classes with subtypes, plus explicit `system_role`; the QBO mapping is a data table in the `qbo` crate
* QBO AccountType and DetailType as the core taxonomy
* A free-form tag model

## Decision Outcome

Chosen option:

* **Classes:** asset, liability, equity, income, expense.
* **Subtypes** (15): bank, accounts_receivable, other_current_asset, fixed_asset, other_asset, accounts_payable, credit_card, other_current_liability, long_term_liability, equity, income, other_income, cost_of_sales, expense, other_expense.
* **System roles** (12): accounts_receivable, accounts_payable, undeposited_funds, retained_earnings, opening_balance_equity, discounts_given, rounding, fx_gain_loss, uncategorized_income, uncategorized_expense, uncategorized_asset, and sales_tax_payable (one per tax agency).
* Behaviour keys off `system_role` and `subtype` only.
* An optional `detail` text keeps any source detail type.
* The QBO mapping is data in `qbo`, verified against Intuit's API reference in W3-03.

### Consequences

* Good, because it does not depend on the unverified list, and the reports are simple.
* Good, because unlimited accounts and sub-accounts are allowed (I-9).
* Bad, because a QBO detail type with special behaviour that we do not model is kept only as text. Such cases surface in migration validation.

### Confirmation

Schema CHECKs (class and subtype pairs, role and subtype pairs, unique singleton roles; T-STORE-17); the `qbo` mapping golden test (T-MIG-2).

## Pros and Cons of the Options

### Own taxonomy plus roles

* Good, because it is stable, small and clean-room.

### QBO taxonomy as core

* Bad, because it couples the core to Intuit's evolving list and depends on CV-7.

### Free-form tags

* Bad, because the reports cannot rely on them.

## More Information

LEDGER_SPEC §2; DATA_MODEL §8; BRIEF_AUDIT C-12, CV-7, G-15.
