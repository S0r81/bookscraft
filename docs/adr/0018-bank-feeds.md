---
status: accepted
date: 2026-10-10
decision-makers: Owner (S0r81), lead-architect, bank-feeds-engineer, security-reviewer
---

# Bank feeds: one provider trait, provider-agnostic staging, user-owned credentials

## Context and Problem Statement

The brief wants file import, SimpleFIN, Teller and Plaid behind one interface, with no schema change per provider and credentials encrypted and user-owned. Teller and Plaid enrollment flows likely require vendor-hosted JavaScript widgets (unverified, OV-8).

## Decision Drivers

* No schema change per provider.
* Credentials never in plain configuration, logs or exports.
* Desktop users must have a working live feed without running a server.
* The regulatory backdrop (CFPB §1033) is in flux (R-10).

## Considered Options

* `BankProvider` trait with file, SimpleFIN, Teller and Plaid implementations over one `bank_txn` staging table; secrets by reference
* A table per provider
* Credentials in the company file

## Decision Outcome

Chosen option:

* `domain::ports::BankProvider` (`connect`, `fetch`) feeds normalized lines into `bank_txn`, deduplicated by provider id or hash.
* `bank_feed` stores only a `credential_ref`. Secrets go through `SecretStore`: the OS keychain on desktop (`platform`), envelope encryption on the server (`identity`).
* **Order:** file import (W2-03), then SimpleFIN in late MVP (W4-05, desktop and self-host default: the user pastes a setup token, no widget), then Teller and Plaid in v1 in server mode, with enrollment opened in the system browser.

### Consequences

* Good, because adding a provider adds no tables, and the user owns their aggregator relationship.
* Good, because file import always works when a feed breaks.
* Bad, because desktop credential storage depends on a working Secret Service (GNOME Keyring or KWallet) on Linux. If none is present, the app refuses to save the feed and explains why.

### Confirmation

T-BANK-1 (dedupe), a SimpleFIN adapter test against a recorded fixture (W4-05), security review of credential handling (W4-05 Weave), and a lint check that no secret field is serialized into exports or logs (W4-05).

## Pros and Cons of the Options

### One trait, one staging table

* Good, because it is extensible, with one review flow and one dedupe.

### Table per provider

* Bad, because of schema churn and duplicated review logic.

### Credentials in the company file

* Bad, because copying the file would leak bank access.

## More Information

LEDGER_SPEC §11; ARCHITECTURE §8 and §9; brief §7.1.
