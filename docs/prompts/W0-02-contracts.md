# W0-02: Contracts: money, domain, api-types

## Goal

Make the shared contracts complete for the MVP: exact money arithmetic and document totals in `money`, every type, port, permission rule and error code in `domain`, and every wire DTO in `api-types`, so later work packages build against fixed interfaces.

## Wave and concurrency

- Wave 0, order 2. Starts when W0-01 is merged. W0-06 (UI spike) may run at the same time; its paths do not overlap.
- Agent: `lead-architect`.
- Timebox: three sessions, then `/handoff`.

## Owned paths (may modify) / Read-only paths

May modify:

- `crates/money/**`, `crates/domain/**`, `crates/api-types/**`, `crates/app/src/**`, `Cargo.lock`
- `docs/coordination/CCR/CCR-W0-02-*.md`, `docs/coordination/handoffs/W0-02.md`

Read-only: everything else. In particular the service crates' `build` functions must keep compiling without edits: the skeleton names from W0-01 (port trait names, `Services`, `Infra`, the three port bundles, `Capability` variants, `stubs::Unimplemented`) are fixed.

## Read first

1. `CLAUDE.md`.
2. `docs/architecture/ARCHITECTURE.md` §4 (all subsections) and §8.
3. `docs/architecture/API.md` in full: conventions (§2), errors (§4), every endpoint (§5), permissions and scopes (§6), DTO shapes (§7).
4. `docs/architecture/LEDGER_SPEC.md` §1–§8 (amounts, templates, settlements, revisions, cash basis, rounding).
5. `docs/architecture/DATA_MODEL.md` §1, §3 and §4.1.
6. ADR-0006 (money and decimals), 0012 (identity and external refs), 0013 (account classification), 0014 (dimensions), 0021 (API conventions), 0022 (MCP surface), 0023 (roles), 0024 (job kinds).

## Preconditions

| Precondition | Check |
|---|---|
| W0-01 is merged | `git log origin/main --format=%s \| grep -q '^W0-01: '` |
| The skeleton exists | `git show origin/main:crates/domain/src/lib.rs > /dev/null` |

## Scope in/out

In:

- **`money` (MIT, pure):** `Minor(i64)` with checked `add`, `sub`, `neg`, `mul_int` returning `money.overflow`; `Currency` (ISO 4217 code plus minor digits, a table of every active code); `Money { minor, currency }` with `money.currency_mismatch`; decimal helpers over `rust_decimal`; rounding of a decimal to minor units (`round_half_up` away from zero, `round_half_even`); `allocate(target, weights)` exactly as LEDGER_SPEC §7; `calc::document_totals` implementing the LEDGER_SPEC §4.1 amount rules (line amounts, percent or amount discount, taxable share of the discount, per-rate tax rounded separately with a selectable mode, tax modes `exclusive`, `inclusive` with per-line tax by `allocate`, and `none`); strict decimal-string serde for `Money` (`{"amount": "5097.70", "currency": "USD"}`); en-US display formatting (`5,097.70`, negatives as `-15.00`). Error codes are `&'static str` constants in `money::codes`.
- **`domain` (AGPL, pure):** every module in ARCHITECTURE §4.1 with its contents; every port trait method, one per API operation (ARCHITECTURE §4.2, synchronous, `&Ctx` first); the infrastructure trait methods of ARCHITECTURE §8; `Infra`, `Services` and the port bundles unchanged in shape; `stubs::Unimplemented` implementing every method with `Err(DomainError::not_implemented())`; `JobKind` (closed enum: `email_send`, `import`, `export`, `bank_sync`, `backup`, `verify`, `reversing_entry`), with `run_job(&self, ctx: &Ctx, job: &Job) -> Result<serde_json::Value, DomainError>` on each kind's owning port and `ports::JOB_OWNERS` mapping every kind to that port (ARCHITECTURE §12); `auth::permits(principal, permission)` with roles, scopes and the agent rule exactly as API.md §6; the error codes `domain` owns (ARCHITECTURE §4.6: `validation.*`, `api.not_implemented`, `auth.forbidden`, `auth.agent_forbidden`, `auth.scope_missing`); `ports::OPERATIONS`, a table from every API operation id in API.md §5 to its port method.
- **`api-types` (AGPL, pure, WASM):** request and response DTOs for every endpoint in API.md §5, grouped in the modules of ARCHITECTURE §4.3; `deny_unknown_fields` on requests; `MoneyDto` is `money::Money`; `ProblemDetails`, `FieldError`, `Page`, `Paged<T>`, `Version`; feature `openapi` adds `utoipa::ToSchema` derives.
- **`app`:** only the changes the contracts force (none expected).

Out: any implementation of a service, storage, posting rules, HTTP handlers or UI.

## Tasks

1. Implement `money`, then its tests (T-MONEY-1, 3, 4 and the totals cases below).
2. Write `domain` module by module in the order ids, time, entities, documents, ledger_view, commands, queries, reports, errors, auth, context, capability, ports.
3. Derive each port's methods from API.md §5: one method per operation (for example `SalesService::save_invoice`, `BooksService::post_journal_entry`, `ReportsService::trial_balance`). Fill `ports::OPERATIONS` as you go.
4. Implement `stubs::Unimplemented` for every method.
5. Write `api-types` from API.md §5 and §7.
6. If the specs are silent on a contract detail, decide it, and list it in the PR under "Spec decisions" so Weave 0 can update the docs.
7. Run `cargo build --locked --workspace` to prove the service crates still compile unchanged.

## Invariants touched

| Invariant | Test |
|---|---|
| I-1 money exact | T-MONEY-1 (checked arithmetic), T-MONEY-3 (`allocate`), T-MONEY-4 (serde) |
| I-2 pure crates | D-2 lint over `domain` and `api-types` |
| I-8 generic dimensions | dimension values are maps keyed by dimension id, never fixed fields (reviewed) |
| I-9 no caps | `count-limits` lint |
| I-10 agents draft only | T-ID-1 (exhaustive permission table including the agent rule) |
| I-12 licensing | D-1 lint over `money` |

## Acceptance criteria

| Id | Criterion | How it is checked |
|---|---|---|
| AC-1 | T-MONEY-1: checked arithmetic never wraps, including at `i64::MIN` and `i64::MAX` | proptest with at least 1,000 cases passes |
| AC-2 | T-MONEY-3: `allocate` always sums to the target, for random targets and weights including negatives; and `allocate(-250000, [-450000, -80000, 26500, -4750, -1520]) == [-220688, -39233, 12996, -2330, -745]` (LEDGER_SPEC §7 example) | proptest (1,000 cases) and a unit test pass |
| AC-3 | T-MONEY-4: `Money` round-trips through JSON; parsing rejects `"5097.7"` and `"5,097.70"` and `"5.0977e3"` and a JSON number for USD, and accepts `"500"` for JPY | tests pass |
| AC-4 | `calc::document_totals` reproduces INV-1002: lines 4,500.00 (not taxable) and 800.00 (taxable), 5% discount, tax after discount, rates 6.25% and 2.00% give subtotal 5,300.00, discount 265.00, taxable base 760.00, tax 47.50 and 15.20, total 5,097.70 | unit test passes |
| AC-5 | Inclusive tax splits exactly: the per-line tax amounts sum to the per-rate totals, and tax mode `none` produces zero tax | unit tests pass |
| AC-6 | T-ID-1: `permits` matches API.md §6 for every role and permission, every scope, and the agent rule (an agent is refused every protected permission whatever its scopes) | a table test with the expected matrix written out literally passes |
| AC-7 | Every API operation has a port method | test `ports_cover_api_operations` reads `docs/architecture/API.md`, collects every operation id in §5, expanding the abbreviations by the rule in API.md §5 (generic list and typed-document rows, slash cells), and fails if one is missing from `ports::OPERATIONS` or if `OPERATIONS` has an id API.md lacks |
| AC-8 | The stub answers `api.not_implemented` | a test calls one method of each service trait on `stubs::Unimplemented` and checks the code |
| AC-9 | The Document DTO matches API.md §7.1 | a test deserializes the §7.1 JSON example and serializes it back to an equal `serde_json::Value`; a request with an unknown field is rejected |
| AC-10 | `api-types` builds for WebAssembly and with OpenAPI derives | `cargo check --locked -p bookscraft-api-types --target wasm32-unknown-unknown` and `cargo check --locked -p bookscraft-api-types --features openapi` exit 0 |
| AC-11 | The skeleton is unchanged: the service crates compile without edits | `cargo build --locked --workspace` exits 0 and `cargo xtask scope W0-02` lists no service crate |
| AC-12 | Lints pass | `cargo xtask lint` exits 0 |
| AC-13 | Every job kind has exactly one owning port | a test iterates every `JobKind` variant and finds exactly one entry in `ports::JOB_OWNERS`, matching ARCHITECTURE §12 |

## Verify

```sh
cargo fmt --all -- --check
cargo clippy --locked -p bookscraft-money -p bookscraft-domain -p bookscraft-api-types -p bookscraft-app --all-targets -- -D warnings
cargo test --locked -p bookscraft-money -p bookscraft-domain -p bookscraft-api-types -p bookscraft-app
cargo check --locked -p bookscraft-api-types --target wasm32-unknown-unknown
cargo check --locked -p bookscraft-api-types --features openapi
cargo build --locked --workspace
cargo xtask lint
cargo xtask spine
cargo xtask scope W0-02
```

## Deliverables

- Branch: `wp/W0-02-contracts`
- PR title: `W0-02: Contracts for money, domain and api-types`
- PR description: the template plus a "Spec decisions" list (every place the specs were silent and what you chose).

## Stop conditions

- Needing to touch an unowned path means raise a CCR (`/ccr`) and stop that line of work. In particular, a change that would force edits in a service crate's `build` is a skeleton change: stop and record it as a CCR for Weave 0.
- A contract would contradict a locked invariant or an accepted ADR.
- A precondition is false.
- The same failure persists after two different fix attempts.
- The timebox is reached: run `/handoff`.
