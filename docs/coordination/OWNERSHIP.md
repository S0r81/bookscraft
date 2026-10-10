# Ownership

A crate, or a listed file inside one, is an ownership boundary. A work package (WP) may change only its owned paths. Everything else is read-only to it. The table below is machine-read by `cargo xtask scope <WP>` (CI job `scope`) and by the `cargo xtask hook guard` PreToolUse hook on `wp/*` branches. It is mirrored in [`.github/CODEOWNERS`](../../.github/CODEOWNERS); `cargo xtask lint` checks the mirror.

Format rules for the table (the parser depends on them):

* One row per WP.
* The **Owned paths** cell is a comma-separated list of backticked globs relative to the repository root (`**` matches across directories).

Every WP also owns two coordination files, which are not repeated in the rows:

* its CCR files `docs/coordination/CCR/CCR-<WP>-*.md`;
* its handoff note `docs/coordination/handoffs/<WP>.md`.

## Work packages

| WP | Wave | Agent | Branch | Owned paths |
|---|---|---|---|---|
| W0-01 | 0 | platform-release-engineer | wp/W0-01-workspace | `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `.cargo/**`, `rustfmt.toml`, `clippy.toml`, `deny.toml`, `deny-mit.toml`, `.gitattributes`, `.gitignore`, `.github/workflows/**`, `xtask/**`, `crates/**`, `tests/scenarios/**`, `tests/e2e/**` |
| W0-02 | 0 | lead-architect | wp/W0-02-contracts | `crates/money/**`, `crates/domain/**`, `crates/api-types/**`, `crates/app/src/**`, `Cargo.lock` |
| W0-03 | 0 | qa-verifier | wp/W0-03-spine | `crates/test-support/**`, `tests/scenarios/**`, `Cargo.lock` |
| W0-04 | 0 | storage-engineer | wp/W0-04-store | `crates/store/**`, `Cargo.lock` |
| W0-05 | 0 | ledger-engineer | wp/W0-05-ledger | `crates/ledger/**`, `crates/posting/**`, `Cargo.lock` |
| W0-06 | 0 | ui-engineer | wp/W0-06-ui-spike | `spikes/ui/**`, `docs/adr/0002-ui-framework.md` |
| W0-W | 0 | lead-architect | weave/W0 | `**` |
| W1-01 | 1 | ledger-engineer | wp/W1-01-posting-rules | `crates/posting/src/rules/**`, `crates/posting/tests/**`, `crates/posting/golden/**` |
| W1-02 | 1 | ledger-engineer | wp/W1-02-books | `crates/books/src/**`, `crates/books/tests/**`, `crates/books/templates/**` |
| W1-03 | 1 | api-engineer | wp/W1-03-identity | `crates/identity/src/**`, `crates/identity/tests/**` |
| W1-04 | 1 | import-migration-engineer | wp/W1-04-formats | `crates/interchange/src/**`, `crates/interchange/tests/**`, `crates/ofx/src/**`, `crates/ofx/tests/**`, `crates/iif/src/**`, `crates/iif/tests/**`, `docs/architecture/interchange-v1.md` |
| W1-05 | 1 | api-engineer | wp/W1-05-api | `crates/api/src/**`, `crates/api/tests/**`, `crates/app/src/**`, `crates/app/tests/**`, `docs/architecture/openapi.json` |
| W1-W | 1 | lead-architect | weave/W1 | `**` |
| W2-01 | 2 | ledger-engineer | wp/W2-01-sales | `crates/sales/src/**`, `crates/sales/tests/**`, `crates/api/src/routes/sales.rs` |
| W2-02 | 2 | ledger-engineer | wp/W2-02-purchases | `crates/purchases/src/**`, `crates/purchases/tests/**`, `crates/api/src/routes/purchases.rs` |
| W2-03 | 2 | bank-feeds-engineer | wp/W2-03-banking | `crates/banking/src/**`, `crates/banking/tests/**`, `crates/api/src/routes/banking.rs` |
| W2-04 | 2 | ledger-engineer | wp/W2-04-reports | `crates/reports/src/**`, `crates/reports/tests/**`, `crates/api/src/routes/reports.rs` |
| W2-05 | 2 | ui-engineer | wp/W2-05-ui-foundation | `crates/ui/src/**`, `crates/ui/tests/**`, `crates/ui/index.html`, `crates/ui/style/**`, `crates/ui/assets/**`, `xtask/src/ui.rs`, `xtask/src/e2e.rs`, `tests/e2e/src/**`, `tests/e2e/tests/ui_foundation.rs` |
| W2-W | 2 | lead-architect | weave/W2 | `**` |
| W3-01 | 3 | ui-engineer | wp/W3-01-ui-sales | `crates/ui/src/pages/sales/**`, `tests/e2e/tests/ui_sales.rs` |
| W3-02 | 3 | ui-engineer | wp/W3-02-ui-purchases-banking | `crates/ui/src/pages/purchases/**`, `crates/ui/src/pages/banking/**`, `tests/e2e/tests/ui_purchases_banking.rs` |
| W3-03 | 3 | import-migration-engineer | wp/W3-03-qbo-mapper | `crates/qbo/src/**`, `crates/qbo/tests/**`, `crates/qbo/fixtures/**` |
| W3-04 | 3 | import-migration-engineer | wp/W3-04-migrate | `crates/migrate/src/**`, `crates/migrate/tests/**`, `crates/migrate/fixtures/**`, `crates/api/src/routes/imports.rs` |
| W3-05 | 3 | platform-release-engineer | wp/W3-05-desktop | `crates/platform/src/**`, `crates/platform/tests/**`, `crates/desktop/src/**`, `crates/desktop/tests/**`, `crates/desktop/build.rs`, `crates/desktop/tauri.conf.json`, `crates/desktop/capabilities/**`, `crates/desktop/icons/**` |
| W3-W | 3 | lead-architect | weave/W3 | `**` |
| W4-01 | 4 | ui-engineer | wp/W4-01-ui-reports-close | `crates/ui/src/pages/reports/**`, `crates/ui/src/pages/close/**`, `crates/ui/src/pages/audit/**`, `crates/ui/src/pages/migrate/**`, `tests/e2e/tests/ui_reports_close.rs` |
| W4-02 | 4 | api-engineer | wp/W4-02-cli | `crates/cli/src/**`, `crates/cli/tests/**` |
| W4-03 | 4 | import-migration-engineer | wp/W4-03-qbo-connector | `crates/migrate/src/qbo/**`, `crates/migrate/tests/qbo_*.rs`, `crates/migrate/fixtures/qbo_http/**` |
| W4-04 | 4 | api-engineer | wp/W4-04-render | `crates/render/src/**`, `crates/render/tests/**`, `crates/render/templates/**`, `crates/render/fonts/**`, `crates/api/src/routes/render.rs` |
| W4-05 | 4 | bank-feeds-engineer | wp/W4-05-bank-feeds | `crates/banking/src/feeds/**`, `crates/banking/tests/feeds_*.rs`, `crates/banking/fixtures/simplefin/**`, `crates/api/src/routes/feeds.rs` |
| W4-W | 4 | lead-architect | weave/W4 | `**` |
| W5-01 | 5 | platform-release-engineer | wp/W5-01-packaging | `packaging/**`, `.github/workflows/release.yml`, `xtask/src/package.rs`, `crates/desktop/tauri.conf.json`, `crates/desktop/icons/**` |
| W5-02 | 5 | api-engineer | wp/W5-02-mcp | `crates/mcp/src/**`, `crates/mcp/tests/**` |
| W5-03 | 5 | ui-engineer | wp/W5-03-ui-print-polish | `crates/ui/src/components/**`, `crates/ui/src/shell/**`, `crates/ui/src/pages/**`, `crates/ui/tests/**`, `crates/ui/style/**`, `tests/e2e/tests/ui_print_polish.rs` |
| W5-04 | 5 | qa-verifier | wp/W5-04-e2e-pilot | `xtask/src/e2e.rs`, `tests/e2e/src/**`, `tests/e2e/tests/api_*.rs`, `tests/e2e/tests/desktop_*.rs`, `docs/process/PILOT_RUNBOOK.md`, `docs/process/RELEASE_CHECKLIST.md` |
| W5-W | 5 | lead-architect | weave/W5 | `**` |

## Paths only a Weave changes after Wave 0

The rows above are authoritative. No row in Waves 1–5 covers the paths below, except the files named in the **Row exceptions** column, which the named WP creates or owns.

| Path | Row exceptions | Why |
|---|---|---|
| `Cargo.toml`, `Cargo.lock`, `crates/*/Cargo.toml`, `tests/*/Cargo.toml`, `xtask/Cargo.toml`, `rust-toolchain.toml`, `deny.toml`, `deny-mit.toml`, `.cargo/**` | none | Dependencies are pinned once; CI builds with `--locked` |
| `crates/domain/**`, `crates/api-types/**`, `crates/money/**` | none | Shared contracts |
| `crates/store/**` (including `crates/store/migrations/**`) | none | Schema and write path are contracts; migrations are numbered only in a Weave |
| `crates/app/src/**`, `crates/api/src/lib.rs`, `crates/api/src/routes/mod.rs` | W1-05 creates them | Registration points (ARCHITECTURE.md §7) |
| `crates/ui/src/lib.rs`, `crates/ui/src/routes.rs` | W2-05 creates them | UI registration points |
| `xtask/**` | `xtask/src/ui.rs` (W2-05), `xtask/src/e2e.rs` (W2-05, then W5-04), `xtask/src/package.rs` (W5-01) | Tooling |
| `crates/test-support/**`, `tests/scenarios/**` | none | Shared test harness and the scenario spine: only QA (W0-03) and Weaves change them (ADR-0029) |
| `.github/**` | `.github/workflows/release.yml` (W5-01) | CI and repository settings |
| `.claude/**`, `CLAUDE.md`, `README.md`, `CONTRIBUTING.md`, `LICENSE`, `LICENSES/**` | none | Process and policy |
| `docs/architecture/**` | `docs/architecture/interchange-v1.md` (W1-04), `docs/architecture/openapi.json` (W1-05) | Specs |
| `docs/adr/**`, `docs/prompts/**`, `docs/roadmap/**`, `docs/coordination/OWNERSHIP.md`, `docs/coordination/BOARD.md`, `docs/coordination/CCR/TEMPLATE.md`, `docs/coordination/handoffs/README.md` | `docs/adr/0002-ui-framework.md` (W0-06, Wave 0) | Decisions and coordination |
| `docs/process/**` | `docs/process/PILOT_RUNBOOK.md`, `docs/process/RELEASE_CHECKLIST.md` (W5-04) | Process |
| `docs/research/bookscraft-brief.md` | never changed by anyone | Source of truth for scope |

## Ownership checks (`cargo xtask lint`, from W0-01)

| Check | Rule |
|---|---|
| Parse | Every row has a WP id, a wave 0–5, an agent that exists in `.claude/agents/`, a branch `wp/<WP>-<slug>` or `weave/W<n>`, and at least one backticked glob. |
| Disjoint within a wave | For any two rows of the same wave (Waves 1–5, and W0-06 against the other Wave 0 rows), no path can match a glob of both rows. Globs are compared segment by segment: `**` matches zero or more segments, `*` matches within one segment. Weave rows (`**`) are exempt; W0-01..W0-05 are exempt because they run one after another. |
| Weave-only paths | No glob of a Wave 1–5 row can match a path in the table above, unless that glob is listed in the row exceptions or the exception names the row's WP as the creator. |
| Mirror | `.github/CODEOWNERS` lists the same globs per WP, in the same order (generated by `cargo xtask lint --fix-codeowners`). |

## Hotspot rules

| Hotspot | Rule |
|---|---|
| Migrations | Only a Weave adds `crates/store/migrations/NNNN_<slug>.sql`, numbered sequentially, and updates `docs/architecture/schema.sql` in the same commit. A builder that needs a schema change raises a CCR containing the proposed SQL and stops that line of work. |
| Feature registration | Services register through their fixed `build` constructor and `CAPABILITIES` const (ARCHITECTURE.md §4.4–4.5). A builder adds capabilities only in its own crate, and only when the feature is complete and tested. |
| Error enums | Error codes are constants in the owning crate, inside its namespace (API.md §4). There are no shared error enums to edit. `cargo xtask lint` rejects a duplicate code string. The code table `docs/architecture/error-codes.md` is regenerated only in a Weave (`cargo xtask docs`). |
| UI routes | `crates/ui/src/routes.rs` lists every MVP route (W2-05). A page WP fills only its own `pages/<area>/` directory and never edits `routes.rs`. A missing route or shared component is a CCR; until it is resolved, the WP builds a local component inside its own directory. |
| HTTP routes | `crates/api/src/routes/mod.rs` merges every area module (W1-05). An area WP edits only its own `routes/<area>.rs`. |
| `Cargo.lock` | Changes only in W0-01, in Wave 0 WPs listed above, and in Weaves. Every command uses `--locked`, so an accidental change fails fast. A dependency need is a CCR. |
| Coordination files | Builders never edit `BOARD.md` or `OWNERSHIP.md`. Each WP writes only its own CCR and handoff files, so concurrent PRs never touch the same coordination file. |
| Docs generated from code | `docs/architecture/openapi.json` is written by W1-05, then only by `cargo xtask docs` in a Weave; `docs/architecture/error-codes.md` only in Weaves. CI checks both on Weave PRs, so work package PRs never edit them and never conflict over them. |
