# CCR-<WP>-<n>: <one-line title>

Copy this file to `docs/coordination/CCR/CCR-<WP>-<n>-<slug>.md` (for example `CCR-W2-01-1-payment-discount-field.md`), fill in every field, commit it on your WP branch, and list it in your PR description. Do not change the contract yourself. Continue with the work that does not depend on it. Only a Weave decides and implements a CCR.

| Field | Value |
|---|---|
| ID | CCR-<WP>-<n> |
| Raised by | <WP id>, <agent role> |
| Date | <YYYY-MM-DD> |
| Status | open |
| Contract affected | <exact paths and items, e.g. `crates/domain/src/documents.rs` `Document::discount`> |
| Blocking? | <yes: which acceptance criteria cannot pass until it is resolved / no: workaround in place> |

## Problem

What you need, why the current contract cannot express it, and the evidence (spec section, failing test, error).

## Proposed change

The exact change: new or changed signatures, fields, error codes, SQL (for schema changes, the full migration SQL), DTO shape. Keep it minimal.

```rust
// proposed signature or type
```

## Alternatives considered

At least one, including "do nothing", and why each is worse.

## Impact

Crates, WPs and docs affected (other concurrent WPs, spine steps, API.md, DATA_MODEL.md, ADRs).

## Workaround in place

What you did meanwhile inside your owned paths (for example a local helper, or a test marked `#[ignore = "CCR-W2-01-1"]`), and how to remove it once the CCR lands.

---

## Decision (filled in by the Weave)

| Field | Value |
|---|---|
| Decision | accepted / rejected / superseded by CCR-… |
| Decided in | Weave <n>, <date> |
| Reason | |
| Implemented in | <PR link / commit> |
| Docs updated | <list> |
| Follow-up for the raising WP | <what to do next, if anything> |
