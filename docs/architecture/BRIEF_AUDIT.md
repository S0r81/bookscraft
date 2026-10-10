# Brief audit

Audits [`docs/research/bookscraft-brief.md`](../research/bookscraft-brief.md) (sha256 `440d638f…a477`, 468 lines, read in full on 2026-10-09) against the owner's decisions and locked invariants. Every finding carries a recommended answer and names the ADR or spec document it lands in.

**Checkpoint result (2026-10-10).** The owner answered "defaults (also im on fedora)": every default in §10 is accepted, and Q-1 is confirmed (Fedora, GNOME on Wayland, NVIDIA RTX 3060). Q-9 stays open by its own default (playbook §1.4). The recommendations below are therefore decisions; where an accepted ADR later refined one, §9.1 records the change. The Step 2 self-check (every MVP feature traced to tables, posting, API and prompts; every invariant traced to a test) is in [ROADMAP](../roadmap/ROADMAP.md) §7–§8. The Step 4 independent review is logged in §11.

## 0. Authority and IDs

When sources disagree, the higher one wins:

1. **Owner decisions.** **D-1:** BooksCraft is 100% Rust. Exempt: TOML, YAML, SQL migrations, Markdown, CI workflow files, and the minimal shell needed to install Rust. **D-2:** cross-platform desktop is first-class (Linux first, then Windows and macOS), and server mode comes from the same core.
2. **Locked invariants I-1 to I-13** (short form below; the full text moves to `CLAUDE.md` and `LEDGER_SPEC.md` in Step 2).
3. **The brief.** Its *Caveats* section is treated as unverified (§6).

| ID | Invariant (short form) |
|---|---|
| I-1 | Money is i64 minor units plus an ISO 4217 code; FX rates are decimals; no f32/f64 in the money path (clippy `disallowed-types` in the money and ledger crates); rounding differences post to a rounding account |
| I-2 | Documents are separate from postings; document → postings is pure, deterministic and versioned, in a crate with no I/O |
| I-3 | Postings are append-only and every entry sums to zero, enforced by a type that can't be built unbalanced and by storage (finalize-on-post trigger, frozen lines); edit = reversal + new entry; void = reversal |
| I-4 | One accrual ledger; cash basis is derived from the payment-application graph |
| I-5 | Periods are open, soft-locked or hard-locked; hard-locked periods are immutable; overrides are audited |
| I-6 | Append-only, hash-chained audit log with actor type (user, api, agent) and before/after state |
| I-7 | Imported rows keep external IDs (QBO Id, FITID, IIF ref); imports are idempotent and re-runnable |
| I-8 | Dimensions are generic and uncapped; Class, Location and Project are presets |
| I-9 | No tier gating: users, accounts, dimensions and custom fields are unlimited |
| I-10 | AI and agent actions create drafts only; posting a draft needs an audited human approval |
| I-11 | Payroll processing, money movement and tax filing are permanently out of core (import or integrate only) |
| I-12 | The app is AGPL-3.0; money, ledger core, IIF/OFX parsers and the QBO mapper are MIT; cargo-deny enforces license compatibility; the UI framework's license is compatible |
| I-13 | 3-OS CI from the first build prompt; OS code in one platform crate; no shelling out; platform-standard directories; line endings pinned in `.gitattributes`; tests agnostic to path style and case sensitivity |

Finding prefixes: **OV** = an owner decision changes the brief, **C** = contradiction, **G** = gap (the brief is silent, so a decision is taken), **R** = risk, **CV** = caveat-dependence check.
Severity: **H** = affects correctness or is expensive to reverse, **M** = rework if wrong, **L** = cosmetic or cheap to change.

## 1. Top risks

| Rank | Risk | Why it matters | First mitigation |
|---|---|---|---|
| 1 | R-1 UI stack | Costliest decision to reverse; Linux webview quality varies by GPU, and NVIDIA + Wayland is a known trouble spot | Timeboxed spike W0-06 with failable criteria, checked by hand on the owner's Linux machine before any UI work package |
| 2 | R-2 QBO API access | Production OAuth needs a public HTTPS redirect and a client secret; reads are metered; Intuit's developer terms are unreviewed | File-based import is first-class and lands first; the token source is pluggable; the hosted relay waits for a human read of Intuit's terms |
| 3 | R-3 Parity to the cent | MVP exit compares the trial balance with QuickBooks; rounding, tax and API coverage gaps can break it | Imported amounts are never recomputed; month-end TB and per-contact aging diff tool; residual reconstruction (G-17) |
| 4 | R-4 Merge contention | 3–5 agents in parallel collide in shared files | Wave 0 pre-registers every crate and module; module-file ownership; only the Weave adds migrations or changes contracts |
| 5 | R-6 Agent-written accounting code | Silent ledger errors are the worst failure mode | Property tests per invariant, golden files per posting template, independent qa-verifier, scenario spine on every PR |
| 6 | R-7 Cloud session limits | Cold Rust builds every session; a sandbox can resume from a fresh clone and lose uncommitted work | Push work in progress often; per-crate cargo commands; tools preinstalled by the cached setup script |

## 2. Where D-1 (Rust) and D-2 (desktop) change the brief

| ID | Sev | Brief says | Changes to | Lands in |
|---|---|---|---|---|
| OV-1 | H | §7.4, TL;DR: TypeScript monorepo (Node API, React UI); "TypeScript maximizes contributors" | All code is Rust. UI = Leptos compiled to WASM inside a Tauri 2 shell (provisional, ADR-0002). Build automation is `cargo xtask`. The project authors no JavaScript and uses no Node or npm | ADR-0002, ADR-0030 |
| OV-2 | H | §7.4, §9 Phase 0: PostgreSQL plus Docker Compose; SQLite only for a "solo mode" | SQLite everywhere: one file per company plus one system file, WAL, `STRICT` tables, accessed only through the BooksCraft process. No second engine | ADR-0003 |
| OV-3 | H | §4.2: Postgres DDL (`jsonb`, `NUMERIC(20,10)`, deferred constraint trigger) | SQLite dialect. JSON is `TEXT` with a `json_valid` CHECK. Decimals (FX rates, quantities, unit prices) are canonical `TEXT` with a CHECK, never `NUMERIC` or `REAL`, because NUMERIC affinity can silently store a decimal as an 8-byte float. SQLite has no deferred triggers, so balance is enforced by a finalize-on-post trigger | ADR-0006, ADR-0007, `schema.sql` |
| OV-4 | H | §7.4: "Package desktop/local-first builds with Tauri later" | Desktop is an MVP deliverable. Linux packages first (AppImage, deb, rpm, Flatpak). Windows and macOS are a separate milestone (signing, notarization, auto-update) | ADR-0026, ROADMAP |
| OV-5 | M | §2.10: "responsive PWA first" | Desktop first. Server mode serves the same WASM UI bundle to browsers, so web access needs no second UI. An installable PWA with camera receipt capture moves to v1 | ADR-0002, ROADMAP |
| OV-6 | M | §7.4: self-hosting = Docker Compose (app + Postgres) | One binary (`bookscraft serve`), optionally wrapped in a container image; no external database | ADR-0004 |
| OV-7 | M | §2.8: multi-user and accountant access assume a web app | Multi-user requires server mode (same core, same UI). Desktop solo has one local profile; a desktop app can later act as a client of a remote server | ADR-0004, ADR-0023 |
| OV-8 | M | §7.1: Teller and Plaid as connectors | Their enrollment flows run vendor-hosted JavaScript widgets (unverified, see §7.5), which can't run inside the app without loading third-party JS. They become server-mode connectors opened in the system browser. SimpleFIN (paste a setup token, no widget) is the desktop and self-host default; file import is always available | ADR-0018 |
| OV-9 | M | §7.2: "deferred constraint trigger" | Two layers per I-3: a `BalancedEntry` type with no constructor for unbalanced data, plus a storage trigger at finalize | ADR-0007 |
| OV-10 | M | §4.2: `credentials_ref` in a server database | Desktop: OS keychain through the platform crate. Server: envelope encryption (a per-company data key wrapped by a key-encryption key from server config) | ADR-0018, ADR-0020 |
| OV-11 | L | §4.3: CSV, XLSX and Google Sheets import | CSV and XLSX through Rust crates in MVP; Google Sheets needs an API connector, so it moves to later | MIGRATION_SPEC |
| OV-12 | M | Implicit JS test tooling | Rust test stack: `proptest`, `insta` golden files, end-to-end tests over WebDriver (`fantoccini`) against the web build, with a browser and driver installed by the environment setup script (cloud sessions ship chromedriver but no browser binary was found in this session's VM); desktop smoke tests by hand on Linux | ADR-0019 |

## 3. Contradictions

| ID | Sev | Conflict | Recommended answer | Lands in |
|---|---|---|---|---|
| C-1 | H | Sales tax timing: §7.3 puts manual tax codes, combined rates and a liability report by agency in MVP; §3 and §9 put the same items in v1. Invoices and the QBO migrator are MVP and carry tax lines | MVP: tax agencies, tax codes, combined rates, Sales Tax Payable per agency, liability report, imported tax amounts kept exactly. v1: filing and payment records. Later: automated rates behind a `TaxRateProvider` trait | ADR-0016, LEDGER_SPEC, ROADMAP |
| C-2 | M | §9 Phase 1 (MVP) includes "PWA with receipt upload"; §3 puts receipt capture/OCR and mobile in v1 | MVP: file attachments on documents (also needed to import QBO attachments). v1: PWA, camera capture, OCR to a draft expense | ROADMAP |
| C-3 | H | §2.4 and §4.2 put mutable `cleared_state` and `reconciliation_id` columns on posting rows; §4.2 rule 2 and I-3 make posting rows append-only and frozen | Posting rows never change. Clearing state lives in an append-only `clearing_event` table (posting, state, reconciliation, actor, time); current state is the latest event; a finished reconciliation is an immutable record | ADR-0009, `schema.sql` |
| C-4 | M | §4.2 defines two hash chains: `journal_entry(hash, prev_hash)` and `audit_event(hash_chain)` | One chain, in the audit log (I-6). A journal entry stores a content hash of its canonical lines, and the audit event that posts it commits to that hash | ADR-0011 |
| C-5 | M | §3 and §9 put class/location dimensions in v1; I-8 requires generic dimensions; the MVP migrator imports class and location refs on lines | Schema, posting and import carry dimensions from Wave 0; the dimension management UI ships in v1 | ADR-0014 |
| C-6 | L | §7.5: libraries "MIT/Apache-2.0"; I-12: MIT | MIT only, for the library crates I-12 lists plus `interchange` (C-7) | ADR-0005 |
| C-7 | H | I-12 makes the QBO mapper MIT, but the documents it produces belong to the AGPL app. An MIT crate that depends on an AGPL crate can in practice only be used under AGPL terms | Add an MIT `interchange` crate: the open import/export data model, which is also the documented export bundle promised in §4.3. The QBO mapper and the IIF and CSV paths produce `interchange`; the AGPL `migrate` crate turns it into domain documents. MIT crates depend only on MIT workspace crates and permissive external crates (checked by `xtask` and cargo-deny) | ADR-0005, ARCHITECTURE |
| C-8 | M | §4.2 `period_lock(lock_date, kind)` is a lock-date model; I-5 speaks of per-period states | Two dates per company, `hard_locked_through` ≤ `soft_locked_through`. A period's state is derived from them, so a locked period can never follow an open one. Moving either date is an audited override; moving the hard date requires the owner role and a reason | ADR-0010 |
| C-9 | H | The owner's MVP exit compares the trial balance with QuickBooks to the cent. §2.1: QBO posts no closing entries and rolls net income into Retained Earnings at report time; a close that posted closing entries would make the two TBs differ | No closing entries. Retained earnings is derived at report time and presented so the TB comparison holds | ADR-0010, LEDGER_SPEC |
| C-10 | M | §3: multi-user with basic roles in MVP; D-2 makes desktop solo the primary MVP shell | MVP includes server mode with local accounts and fixed roles. OIDC and the accountant multi-client workspace are v1 | ADR-0023, ROADMAP |
| C-11 | H | §4.3 suggests "third-party QBW readers" for Desktop migration; the owner's clean-room rule allows only Intuit's public API docs and published formats (IIF, OFX/QFX/QBO, CSV) | No QBW reading, directly or through third-party libraries. Desktop users migrate through IIF lists plus report exports (CSV or XLSX), validated by trial balance | MIGRATION_SPEC |
| C-12 | M | TL;DR: "QBO-API-shaped schema"; the Caveats call the QBO AccountType list unverified | BooksCraft has its own classification. QBO shapes live only in the MIT `qbo` crate's mapping tables (CV-7) | ADR-0013 |

## 4. Gaps: the brief is silent, so a decision is taken

| ID | Sev | Open question | Decision (default) | Lands in |
|---|---|---|---|---|
| G-1 | H | What "sums to zero" means with several currencies | Every entry sums to zero in base currency, always. Lines carry a transaction-currency amount and a base amount; transaction amounts also sum to zero when all lines share one currency. FX differences post to FX gain/loss; rounding residue to the rounding account | LEDGER_SPEC, ADR-0006 |
| G-2 | H | Precision of quantity and unit price: §4.2 has `unit_price_minor` (whole minor units), but unit prices can be sub-cent and quantities fractional | `qty` and `unit_price` are decimals stored as canonical `TEXT`. The line amount is i64 minor units and is authoritative. Imported amounts are stored as received, never recomputed | ADR-0006 |
| G-3 | H | External ID keys: §4.2 has `external_ids {qbo_id, iif_ref}`, but a QBO Id is unique only within one company and one entity type | `external_ref(source, realm, entity_type, external_id)` with a UNIQUE constraint. Bank lines are keyed by (bank account, FITID) with a content-hash fallback when the FITID is missing | ADR-0012, `schema.sql` |
| G-4 | M | §4.2 gives a contact a single `kind`, but agencies often buy from and sell to the same party | One contact with role flags (customer, vendor, employee). QBO Customer and Vendor records map to separate external refs | ADR-0012 |
| G-5 | H | How an edit to a posted document maps to entries, and which posting-rules version applies | Documents have revisions. Posting revision N+1 writes a reversal of revision N's entry plus a new entry. Each entry stores its `rules_version`. History is never re-posted under new rules unless a user edits the document | ADR-0008 |
| G-6 | H | How reconciliation survives edit-by-reversal | Each posting carries a stable `line_key` (document + line). Unchanged bank-side lines inherit their clearing state on repost. Changing a cleared line's account, amount or date requires an explicit, audited un-clear | ADR-0009 |
| G-7 | M | Whether document numbers are unique | Not unique: QBO allows duplicates and imports must keep them. The UI and API warn on duplicates | ADR-0012 |
| G-8 | M | Deleting drafts versus voiding | Drafts can be deleted (audited, no ledger effect). Posted documents are only voided, by reversal | ADR-0007 |
| G-9 | M | Dates and time | Accounting dates are civil dates with no time zone. Audit timestamps are UTC. Each company has a fiscal-year start and a time zone used only to default "today" | ADR-0019 |
| G-10 | M | Row identity across files | UUIDv7 for every entity, stable across export, import and moves between desktop and server | ADR-0012 |
| G-11 | M | Audit hash algorithm and canonical form | SHA-256 over a canonical JSON encoding (sorted keys, no whitespace, decimals as strings). `bookscraft verify` recomputes the chain | ADR-0011 |
| G-12 | H | Concurrency inside a company file | One process owns a company file at a time (OS file lock). Inside it: one write connection using `BEGIN IMMEDIATE`, plus a read pool | ADR-0003 |
| G-13 | H | Evolving the schema of company files users already hold | Forward-only migrations; schema version stored in the file; automatic backup before migrating; the app refuses files newer than it understands | ADR-0003 |
| G-14 | M | Encryption of company files at rest | Not in MVP (rely on OS disk encryption). Evaluate SQLCipher in v1. Flagged as expensive to reverse because it changes the file format | ADR-0003 |
| G-15 | H | Account classification and system accounts | Own classification (asset, liability, equity, income, expense, plus subtypes) and explicit system roles: AR, AP, undeposited funds, retained earnings, opening balance equity, sales tax payable per agency, rounding, FX gain/loss, uncategorized. Special behavior keys off system roles, never off a QBO detail type | ADR-0013 |
| G-16 | H | Opening balances and cut-over | Default: full-history import, with the TB matching at every month-end. Option: cut-over import with opening balances through Opening Balance Equity, and open AR/AP items imported as documents so aging matches per contact | MIGRATION_SPEC |
| G-17 | H | GL activity the QBO API may not expose as entities (payroll is the usual suspect; unverified) | After the entity import, diff the TB month by month against QBO's trial balance report. Reconstruct any residual difference from journal or GL report lines as journal entries flagged `residual`, so the totals match and the gaps stay visible | MIGRATION_SPEC, ADR-0017 |
| G-18 | M | Authentication in each mode | Desktop solo: the OS user plus an optional app password. Server: local accounts (Argon2id) in MVP, OIDC in v1. API tokens carry scopes; agent tokens carry actor type `agent` | ADR-0023 |
| G-19 | M | Role model | MVP fixed roles: owner, admin, bookkeeper, viewer, accountant (bookkeeper rights without user admin). Custom roles and record-level scopes in v1 | ADR-0023 |
| G-20 | M | Who approves agent drafts | Any user with post permission for that document type. The approval is its own audited event naming the draft revision it approved | ADR-0022 |
| G-21 | M | Background work (email, bank sync, recurring transactions) | In-process scheduler with a jobs table in the system file; no external queue | ADR-0024 |
| G-22 | M | Backups | SQLite online backup API: scheduled local copies on desktop, per-company snapshots on server. A scenario test covers restore | ADR-0003 |
| G-23 | M | The §4.3 promise that users can leave | MVP: `interchange` JSON bundle plus CSV export. v1: IIF writer. Later: Beancount | ROADMAP |
| G-24 | L | Localization | en-US only in MVP. A locale-pack interface (dates, numbers, chart-of-accounts templates, tax) is defined but has one implementation | ARCHITECTURE |
| G-25 | L | Telemetry | None by default; local logs only (`tracing`, platform log directory) | ADR-0020 |
| G-26 | M | Where "100% Rust" stops for non-code assets: CSS, the HTML page that hosts the WASM UI, Typst invoice templates, the Flatpak manifest, a container file | Proposed: allowed as data or config files. The project authors no JavaScript and needs no Node toolchain; Rust tools in `xtask` process them. Needs owner confirmation (Q-4) | ADR-0030 |

## 5. Risks

| ID | Sev | Risk | Mitigation | Owner |
|---|---|---|---|---|
| R-1 | H | The UI stack is the costliest decision to reverse. On Linux the webview is WebKitGTK, whose rendering and performance vary with distro and GPU; NVIDIA + Wayland is a known trouble spot | Timeboxed spike (W0-06) with failable criteria, verified by hand on the owner's Linux machine before any UI work package. The runner-up framework uses the same webview, so a webview-level failure escalates to the owner (native fallback: Slint) | lead-architect, ui-engineer |
| R-2 | H | QBO API access. Production keys can't use a localhost redirect (secondary source: a public HTTPS redirect is required). The token exchange uses a client secret that can't ship inside open-source binaries. Reads are metered ("CorePlus"; the free Builder tier blocks after 500,000 calls a month). Intuit's developer terms are unreviewed | File-based paths are first-class and land first. The token source is pluggable. MVP uses the owner's own Intuit developer app. A hosted relay waits until a human has read Intuit's terms | import-migration-engineer |
| R-3 | H | Parity to the cent: tax rounding, per-line versus per-document rounding and cash-basis allocation can differ from QBO | Imported amounts are authoritative and never recomputed. Month-end TB and per-contact aging diff tool. Residual reconstruction (G-17). In MVP, cash-basis parity is measured and reported, not promised | import-migration-engineer, qa-verifier |
| R-4 | H | Parallel agents collide in shared files (API types, routes, UI pages, migrations, `Cargo.lock`) | Wave 0 pre-registers every crate and module. Ownership is at crate or module-file level. Only the Weave adds migrations or edits contracts. A fixed `Cargo.lock` resolution rule | lead-architect |
| R-5 | M | Local-first: whoever holds the file can open it in SQLite and drop the triggers | Triggers are guardrails, not security. The hash chain detects tampering; `verify` runs when a file opens and in scenario tests | storage-engineer |
| R-6 | H | Accounting code written by agents | Invariants as property tests; a golden file per posting template; an independent qa-verifier; scenario spine required on every PR; security-reviewer on auth, import and MCP | qa-verifier, security-reviewer |
| R-7 | M | Cloud sessions: about 4 vCPU and 16 GB, cold Rust builds every session, setup-script snapshots only when the script finishes in about 5 minutes, a sandbox that can resume from a fresh clone (uncommitted work lost), GitHub release downloads blocked for repositories not attached to the session | Commit and push work in progress often; per-crate cargo commands; cargo tools compiled in the cached setup script and kept to a minimum; no `cargo-binstall`; heavy crates (Typst, Tauri) isolated so most work packages never build them | platform-release-engineer |
| R-8 | M | GitHub Free protects branches only on public repositories; private repositories get limited Actions minutes, and macOS minutes cost $0.062 each | A public repository from day one (free Actions on all three OSes, protection available), or GitHub Pro | owner (Q-2) |
| R-9 | M | Framework churn: Tauri 3.0, Leptos 0.9 and Dioxus 0.8 all have alphas out | Exact versions pinned in `[workspace.dependencies]`; upgrades only through a CCR processed in a Weave | lead-architect |
| R-10 | M | US bank-data access rules (CFPB §1033) are in flux (brief §7.1) | Provider-agnostic adapter trait; file import always available | bank-feeds-engineer |
| R-11 | M | Clean room and trademarks: brief §2 uses Intuit's UI terms | BooksCraft writes its own UI copy (terminology table in ARCHITECTURE.md). QBO names appear only in the `qbo` mapper and interoperability docs. Trademark clearance of the product name is the owner's call (not legal advice) | lead-architect |
| R-12 | M | Screen-reader support of WebKitGTK on Linux | Spike criterion; keyboard-first design regardless | ui-engineer |
| R-13 | M | DCO with agent-written commits: a sign-off certifies a human's right to submit | The owner decides the `Signed-off-by` identity for agent commits (Q-9); CI checks sign-offs | owner |

## 6. Caveat-dependence check

The brief's Caveats section is unverified, so no architectural decision may rest on it.

| ID | Caveat item | Could a decision depend on it? | How the design avoids it |
|---|---|---|---|
| CV-1 | 2026 QBO pricing history is contested | No, positioning only | README cites no contested figures |
| CV-2 | Advanced may bundle payroll | No | Payroll is out of core either way (I-11) |
| CV-3 | Desktop renewal prices come from a reseller | No | Positioning only |
| CV-4 | Payroll per-employee fees | No | Not used |
| CV-5 | Open-source stars and licenses are snapshots | Could sway licensing | Licensing follows I-12, not competitors |
| CV-6 | Manager.io pricing | No | Not used |
| CV-7 | QBO AccountType list and workflow details (bank-feed tabs, reconciliation steps, multi-currency irreversibility) | Yes: account taxonomy and UI workflow | Own taxonomy (ADR-0013). The QBO-to-BooksCraft type mapping is a data table in the `qbo` crate, built and verified against Intuit's current API reference at the start of the migrator work package. BooksCraft's workflows are specified on their own. Reversible multi-currency is a BooksCraft product rule, not a reaction to QBO behavior |
| CV-8 | Tax rules change often | Yes: thresholds and rates | Thresholds, rates and nexus rules are versioned data, never code (ADR-0016) |

## 7. External facts verified on 2026-10-09

### 7.1 Claude Code (official docs)

| Fact | Source |
|---|---|
| Cloud sessions are available on Pro, Max and Team, and to Enterprise premium seats. They share rate limits with all other Claude usage; the VM has no separate charge | [Use Claude Code in the cloud](https://code.claude.com/docs/en/claude-code-on-the-web) |
| Each cloud session gets a fresh Ubuntu 24.04 x86_64 VM (about 4 vCPU, 16 GB RAM, 30 GB disk) with rustc, cargo, gh, jq, tmux, docker and chromedriver preinstalled; no browser is listed | [Configure cloud environments](https://code.claude.com/docs/en/cloud-environments) |
| A setup script runs as root before Claude Code starts. Its filesystem result is snapshotted and reused when it finishes in about 5 minutes; the snapshot expires after about 7 days and rebuilds when the script or allowed hosts change | [Configure cloud environments](https://code.claude.com/docs/en/cloud-environments) |
| SessionStart hooks from the repo's `.claude/settings.json` run on every start and resume, locally and in the cloud. `CLAUDE_CODE_REMOTE=true` marks the cloud; `CLAUDE_ENV_FILE` persists environment variables | [Configure cloud environments](https://code.claude.com/docs/en/cloud-environments), [Hooks reference](https://code.claude.com/docs/en/hooks) |
| The default "Trusted" network allowlist includes crates.io, index.crates.io, static.crates.io, static.rust-lang.org, rustup.rs and github.com | [Configure cloud environments](https://code.claude.com/docs/en/cloud-environments) |
| The GitHub proxy pushes branches only (no deletions, no tags), serves API and release-asset requests only for repositories attached to the session, and allows only a pinned set of GraphQL operations | [Configure cloud environments](https://code.claude.com/docs/en/cloud-environments) |
| In a single-repository session, `.claude/settings.json` permissions, hooks and `env` apply, and the repo's `CLAUDE.md`, `.claude/rules/`, skills, agents and commands load. User-level `~/.claude` configuration never reaches cloud sessions | [Configure cloud environments](https://code.claude.com/docs/en/cloud-environments), [Settings](https://code.claude.com/docs/en/settings) |
| Hook events include SessionStart, PostToolUse, Stop and SubagentStop. Exit code 2 blocks (on Stop it keeps Claude working). Command hooks time out after 600 s by default. `CLAUDE_PROJECT_DIR` stays at the start directory inside worktrees | [Hooks reference](https://code.claude.com/docs/en/hooks) |
| Bash permission rules use `Bash(cargo *)` (`:*` is equivalent). Deny beats ask beats allow; compound commands are matched per subcommand; a project's `allow` rules apply only after workspace trust | [Configure permissions](https://code.claude.com/docs/en/permissions) |
| Subagents live in `.claude/agents/*.md`. Frontmatter includes `name`, `description`, `tools`, `disallowedTools`, `model`, `permissionMode`, `skills`, `hooks`, `memory`, `effort`, `maxTurns` and `isolation: worktree`. They nest up to three levels and run up to 20 at once by default | [Create custom subagents](https://code.claude.com/docs/en/sub-agents) |
| Custom commands are merged into skills; the docs recommend `.claude/skills/<name>/SKILL.md` for new work (`$ARGUMENTS`, `$0`, `disable-model-invocation`) | [Extend Claude with skills](https://code.claude.com/docs/en/skills) |
| `claude --worktree <name>` creates `.claude/worktrees/<name>/` on branch `worktree-<name>`; `.worktreeinclude` copies gitignored files; subagent worktrees branch from the default branch unless `worktree.baseRef` is `"head"` | [Run parallel sessions with worktrees](https://code.claude.com/docs/en/worktrees) |
| Projects (public beta, Pro and Max): one coordinating conversation starts parallel cloud threads; each thread works on its own branch, opens a PR and watches CI with auto-fix; 200 new threads a day. A thread's sandbox can resume from a fresh clone, losing uncommitted changes | [Projects](https://code.claude.com/docs/en/claude-projects) |
| Keep each `CLAUDE.md` under 200 lines; `.claude/rules/*.md` with `paths:` frontmatter load only for matching files | [How Claude remembers your project](https://code.claude.com/docs/en/memory) |
| Ways to run in parallel: subagents, agent view (`claude agents`), agent teams (experimental), projects, dynamic workflows | [Run agents in parallel](https://code.claude.com/docs/en/agents) |

Observed in this session's VM (a chat-hosted session whose network policy may differ from the owner's Claude Code environment): rustup 1.28.2 with stable 1.97.0, clippy and rustfmt; index.crates.io and static.crates.io reachable; static.rust-lang.org unreachable; GitHub release downloads from unattached repositories return 403.

### 7.2 Candidate crates (crates.io API)

| Crate | Latest stable | Released | License |
|---|---|---|---|
| tauri | 2.12.2 (3.0.0-alpha.0 exists) | 2026-10-09 | Apache-2.0 OR MIT |
| leptos | 0.8.22 (0.9.0-alpha exists) | 2026-10-05 | MIT |
| dioxus | 0.7.10 (0.8.0-alpha.0 exists) | 2026-07-30 | MIT OR Apache-2.0 |
| slint | 1.18.1 | 2026-09-21 | GPL-3.0-only OR Slint Royalty-free 2.0 OR Slint Software 3.0 |
| iced | 0.14.0 | 2025-12-07 | MIT |
| egui | 0.36.2 | 2026-09-08 | MIT OR Apache-2.0 |
| rusqlite | 0.40.2 | 2026-08-08 | MIT |
| sqlx | 0.9.0 | 2026-05-21 | MIT OR Apache-2.0 |
| refinery | 0.10.0 | 2026-10-02 | MIT |
| axum | 0.8.9 | n/a | MIT |
| rmcp (official MCP SDK) | 3.5.1 | 2026-10-05 | Apache-2.0 |
| utoipa | 6.0.0 | 2026-09-22 | MIT OR Apache-2.0 |
| typst | 0.15.1 | 2026-07-17 | Apache-2.0 |
| keyring | 4.2.0 | 2026-08-29 | MIT OR Apache-2.0 |
| rust_decimal | 1.43.0 | n/a | MIT |

Every UI candidate's license is compatible with AGPL-3.0 (Slint through its GPL-3.0 option).

### 7.3 GitHub

| Fact | Source |
|---|---|
| Protected branches: public repositories on GitHub Free; public and private on Pro and Team | [About protected branches](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches) |
| Actions are free for public repositories on standard hosted runners. Private: 2,000 minutes a month on Free, 3,000 on Pro; Linux 2-core $0.006, Windows $0.010, macOS $0.062 per minute | [GitHub Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions) |

### 7.4 Intuit / QuickBooks Online API (secondary sources)

Intuit's developer pages render in the browser and could not be fetched, so these facts come from secondary sources and must be re-checked against Intuit's docs at the migrator work package.

| Fact | Source |
|---|---|
| A `http://localhost` redirect works only for sandbox keys; production apps need a public HTTPS redirect | [Chilkat QuickBooks OAuth2 desktop example](https://www.example-code.com/unicodeCpp/quickbooks_oauth2_desktop_app.asp) |
| The App Partner Program went live on 2025-07-28. Reads, queries and reports are "CorePlus" calls and are metered; writes are free. Builder tier: $0 with 500,000 CorePlus calls a month, blocked beyond that. Silver: $300 a month for 1 million, then $3.50 per 1,000 | [Apideck](https://radar.apideck.com/blog/quickbooks-api-pricing-and-the-intuit-app-partner-program.md), [Truto](https://truto.one/blog/how-much-does-the-quickbooks-api-cost-2026-pricing-rate-limits/) |
| Rate limits: 500 requests a minute per company, 10 concurrent requests per app per company, 40 a minute for batch | [Truto](https://truto.one/blog/how-much-does-the-quickbooks-api-cost-2026-pricing-rate-limits/) |

### 7.5 Not verified: a human checks these before the dependent work package

| Item | Needed by | How to check |
|---|---|---|
| Intuit Developer Terms on competitive use and migrating data out | ADR-0017, migrator WP | Read the supplemental terms for QuickBooks developer apps in a browser |
| What an unlisted app needs to get production keys | Migrator WP | Intuit developer dashboard |
| QBO API coverage of payroll and other GL activity | G-17 | Compare the entity import with QBO's trial balance report on the pilot company |
| Whether Teller Connect and Plaid Link need vendor JavaScript | OV-8 | Vendor docs at the start of the bank-feeds WP |
| An axum `Router` served in-process through a Tauri custom protocol; Leptos 0.8 built with Trunk inside Tauri 2.12 | ADR-0002, ADR-0004 | Spike W0-06 |
| static.rust-lang.org reachable from the owner's Claude Code environment | Toolchain pinning | The first Wave 0 session runs `cargo xtask doctor` |

## 8. Proposed crate map (final version goes to ARCHITECTURE.md)

Package names are `bookscraft-<dir>`. "Pure" means no I/O: no filesystem, network, database or async runtime.

| Crate | License | Pure | Purpose |
|---|---|---|---|
| `money` | MIT | yes | Amounts, currencies, decimal rates, rounding, allocation |
| `ledger` | MIT | yes | `BalancedEntry`, reversal, trial balance, lock evaluation, invariant checks |
| `interchange` | MIT | yes | Open import/export data model (the documented export bundle) |
| `iif` | MIT | yes | IIF parser and writer |
| `ofx` | MIT | yes | OFX/QFX/QBO (Web Connect) parser |
| `qbo` | MIT | yes | QBO API entity types and mapping to `interchange` |
| `domain` | AGPL | yes | Contracts: entities, documents, commands, IDs, error codes, ports (traits) |
| `posting` | AGPL | yes | Document → postings rules, versioned |
| `store` | AGPL | no | SQLite engine, migrations, finalize-on-post, audit chain, file lock, backups |
| `books` | AGPL | no | Chart of accounts, contacts, items, tax codes, dimensions, journal entries, periods, approvals |
| `sales` | AGPL | no | AR: estimates, invoices, sales receipts, credit memos, refunds, payments, deposits |
| `purchases` | AGPL | no | AP: bills, bill payments, vendor credits, expenses, checks, card charges |
| `banking` | AGPL | no | Bank import, review, rules, reconciliation, bank provider adapters |
| `reports` | AGPL | no | Report engine, accrual and derived cash basis |
| `migrate` | AGPL | no | QBO API client, CSV/IIF import, parity validation |
| `identity` | AGPL | no | Accounts, sessions, roles, API tokens, scopes |
| `render` | AGPL | no | PDF and preview (Typst), email delivery |
| `api-types` | AGPL | yes | HTTP request/response types; compiles to WASM |
| `api` | AGPL | no | axum router, middleware, OpenAPI |
| `mcp` | AGPL | no | MCP tools (drafts only) |
| `ui` | AGPL | n/a | Leptos app compiled to WASM |
| `platform` | AGPL | no | All OS-specific code |
| `desktop` | AGPL | no | Tauri shell binary |
| `cli` | AGPL | no | `bookscraft` binary: `serve`, `mcp`, `import`, `verify`, `backup`, `export` |
| `test-support` | AGPL | n/a | Fixtures, golden-file helpers, proptest strategies (dev-only) |
| `tests/scenarios` | AGPL | n/a | Scenario spine (QA-owned) |
| `xtask` | AGPL | n/a | Build automation |

Dependency rules (each one is checked by `cargo xtask lint` from Wave 0):

1. An MIT crate depends only on MIT workspace crates and on external crates with permissive licenses.
2. A pure crate never depends on `tokio`, `rusqlite`, `reqwest` or any crate that does I/O.
3. `ui` depends on `api-types` and UI libraries only, never on `domain` or `store`.
4. `cfg(target_os = …)`, `cfg(windows)` and `cfg(unix)` appear only in `platform`.
5. `money` and `ledger` ban `f32` and `f64` through clippy `disallowed-types`.

## 9. ADR register

| ADR | Title | Recommended decision | Alternatives considered | Reversal cost |
|---|---|---|---|---|
| 0001 | Record architecture decisions | MADR, one file per decision in `docs/adr/` | Wiki pages; decisions only in specs | Low |
| 0002 | UI framework | Provisional: Leptos 0.8 (client-side, compiled to WASM) in a Tauri 2 shell. One UI bundle serves desktop and browsers, and the UI is an HTTP client in every mode. Runner-up: Dioxus 0.7. Spike W0-06 decides | Dioxus 0.7 desktop/web; Slint (GPL-3.0 option); iced; egui | **High** |
| 0003 | Storage engine | SQLite only (bundled through rusqlite): one file per company plus a system file; WAL, `STRICT`, one owning process, forward-only migrations, backup before migrating | SQLite + PostgreSQL; PostgreSQL only; sqlx instead of rusqlite | **High** |
| 0004 | Process topology | One core library under four shells. Desktop: Tauri shell with the server's router in-process behind a custom protocol, no TCP port. Server: the same router over HTTPS. CLI and MCP: in-process on a company file (exclusive lock) or as HTTP clients of a server | Desktop runs a localhost server on a TCP port; desktop UI calls the core directly while web uses HTTP | Medium |
| 0005 | Licensing and license layering | App AGPL-3.0-only. MIT: `money`, `ledger`, `interchange`, `iif`, `ofx`, `qbo`. MIT crates never depend on AGPL code; cargo-deny runs one policy for the app and a stricter one for MIT crates. DCO plus a no-relicensing pledge | AGPL-3.0-or-later; Apache-2.0 libraries; a CLA | **High** |
| 0006 | Money, decimals and rounding | i64 minor units plus currency; `rust_decimal` for rates, quantities and unit prices, stored as canonical `TEXT`; no `REAL` column anywhere; rounding account | i128 amounts; decimals for amounts; scaled-integer rates | **High** |
| 0007 | Balanced entries and finalize-on-post | `BalancedEntry` type plus a trigger that checks the sum when an entry is finalized and freezes its lines; drafts are documents only | Application-only checks; per-row running-sum constraints | **High** |
| 0008 | Document revisions and versioned posting rules | Revisions; a repost writes reversal + replacement; each entry stores `rules_version`; a golden corpus per rules version | In-place reposting; one global rules version | Medium |
| 0009 | Reconciliation state outside postings | Append-only `clearing_event` table; stable `line_key` carries clearing across reposts | Mutable flags on postings (breaks I-3) | Medium |
| 0010 | Period locks; no closing entries | Two lock dates per company (hard ≤ soft); audited overrides; retained earnings derived at report time | A per-period status table; posting year-end closing entries | Medium |
| 0011 | Hash-chained audit log | One chain per company file; SHA-256 over canonical JSON; actor type and before/after; `bookscraft verify`; tamper-evident, not tamper-proof | Two chains (brief §4.2); BLAKE3; no chain | Medium |
| 0012 | Identity and external references | UUIDv7 IDs; `external_ref(source, realm, entity_type, external_id)` unique; contacts carry role flags; document numbers not unique | Integer IDs; one `kind` per contact | **High** |
| 0013 | Account classification and system roles | Own five-class taxonomy plus subtypes; explicit system roles; QBO type mapping lives as data in the `qbo` crate | QBO AccountType/DetailType as the core taxonomy | Medium |
| 0014 | Generic dimensions | `dimension` and hierarchical `dimension_value` tables, a line-level link table, presets for Class, Location and Project, no caps | JSON column on postings (brief §4.2); fixed class/location columns | Medium |
| 0015 | Cash basis from the payment graph | Computed at report time from `document_link` applications; never stored | A second stored ledger | Low |
| 0016 | Sales tax | MVP: manual agencies, codes, combined rates, liability by agency; imported tax amounts kept as received; `TaxRateProvider` trait for later automation | v1 timing (brief §3); building a rate engine | Medium |
| 0017 | QBO migrator access | File paths first. Pluggable token source. MVP: the owner's own Intuit app (HTTPS redirect to their own server, or a pasted token). v1: a stateless hosted relay that holds the client secret, gated on a human read of Intuit's terms. Residual reconstruction (G-17) | A secret embedded in the binary; relay in MVP; API-only migration | Low |
| 0018 | Bank feeds | One `BankProvider` trait (file, SimpleFIN, Teller, Plaid) over a provider-agnostic staging table; credentials in the OS keychain (desktop) or envelope-encrypted (server); SimpleFIN is the desktop default | One table per provider; credentials in plain config | Medium |
| 0019 | Crate choices | tokio + axum + tower; rusqlite (bundled) + refinery; utoipa; thiserror in libraries, RFC 9457 errors at the API edge; argon2, openidconnect (v1); in-process jobs; typst for PDF; lettre for email; keyring + aes-gcm for secrets; rmcp; clap; jiff for dates; uuid v7; sha2; proptest, insta, fantoccini; Tauri bundler + Flatpak manifest | sqlx, aide, apalis, printpdf or krilla, sqlite-backed job crates | Medium |
| 0020 | Platform layer | One `platform` crate: standard directories, file locks, keychain, open and print through OS APIs or portals (never `xdg-open` or other OS tools), webview environment fixes | Scattered `cfg` blocks; shelling out | Low |
| 0021 | API conventions | REST with JSON. Money serializes as `{"amount": "123.45", "currency": "USD"}`, the amount a decimal string with exactly the currency's minor digits. `Idempotency-Key` header, ETag with `If-Match`, cursor pagination, RFC 9457 errors with namespaced codes | Integer minor units in JSON; offset pagination | **High** once published |
| 0022 | MCP surface | rmcp tools that read or create drafts only, never post, void or approve. Scopes `books:read`, `reports:read`, `drafts:write`. Stdio transport locally, streamable HTTP in server mode | Full read/write tools gated by prompts | Medium |
| 0023 | Authentication and roles | Desktop: OS user plus optional app password. Server: local accounts (Argon2id) in MVP, OIDC in v1. Fixed roles in MVP | OIDC-only; per-record permissions in MVP | Medium |
| 0024 | Background jobs | In-process tokio scheduler with a jobs table in the system file | External queue; a job-queue crate | Low |
| 0025 | PDF, preview and print | Typst as a library; templates are data files; in-app preview renders pages to SVG; printing goes through the webview's OS print dialog | Hand-built layout with krilla or printpdf; HTML-to-PDF | Low |
| 0026 | Packaging and release | Linux: AppImage, deb, rpm (Tauri bundler) and Flatpak (manifest). Windows: MSI or NSIS with signing. macOS: notarized dmg. Tauri updater for AppImage, Windows and macOS; distro packages update through their repositories | cargo-packager; Snap first | Low |
| 0027 | Parallel development model | Contract-first Wave 0; crate or module-file ownership; CCRs; a Weave per wave; hotspot rules (migrations, features, error codes, UI routes, `Cargo.lock`) | Trunk-based development without ownership | Low |
| 0028 | Repository policy | Public repository; protected `main` with required fmt, clippy `-D warnings`, 3-OS tests, cargo-deny and the scenario spine; squash merges, linear history, branches deleted after merge | Private repository with paid protection | Low |
| 0029 | Scenario spine | QA-owned month of agency bookkeeping with golden reports; each step declares the capabilities it needs and runs once a crate declares them, so builders never edit spine files | One end-to-end test edited by every work package | Low |
| 0030 | Where "100% Rust" stops | No JavaScript or Node authored or required. CSS, the WASM host HTML page, Typst templates, the Flatpak manifest and container files are data or config, processed by `xtask` | Inline styles only; Rust-generated templates | Low to medium |

### 9.1 Changes since the register

The register above is what the checkpoint approved. Writing the specs refined these items; the ADRs and specs are authoritative.

| Item | Register or audit said | Accepted decision | Why |
|---|---|---|---|
| ADR-0015 | Cash basis from `document_link` applications | From the `settlement` table, the append-only AR/AP application graph (`document_link` keeps only estimate-to-invoice and similar links) | Applications need their own amounts, dates and voids; cash-basis allocation reads them directly (LEDGER_SPEC §5, §7) |
| ADR-0019 | rusqlite + refinery | An own forward-only migration runner in `store` (embedded SQL, `schema_migrations`) | refinery and rusqlite_migration both couple to a rusqlite version; the runner also keeps backup-before-migrate in one place |
| ADR-0019, OV-12 | End-to-end tests over chromedriver; desktop smoke tests by hand | `fantoccini` with WebKitWebDriver against the web build (the Linux desktop's engine) and `tauri-driver` for the desktop app, both started by `cargo xtask e2e`; installed by the environment setup script | Same engine as the shipped desktop; the tests never start processes (D-5) |
| ADR-0019 | — | Added pins: `toml` 0.9.8, `tauri-cli` 2.12.0, `tauri-driver` 2.1.0 | Needed by `xtask`, packaging and desktop end-to-end tests |
| §7.5 | "Leptos 0.8 built with Trunk inside Tauri 2.12" | No Trunk: `cargo xtask ui build` runs `wasm-bindgen` through `wasm-bindgen-cli-support` (ARCHITECTURE §10) | One Rust tool chain, no downloads at UI build time |
| ADR-0024 | In-process tokio scheduler | One runner thread per process claiming jobs from the system file; each kind dispatched to its owning port's `run_job` (ARCHITECTURE §12) | Services are synchronous; a thread is simpler than a scheduler and identical in every shell |
| ADR-0025 | Invoice, statement and report templates (crate map) | PDFs and previews for sales documents only; report screens print through the webview dialog; no report or statement PDF endpoint in MVP | The brief's MVP asks for invoice PDF and email; printing covers reports |
| ADR-0026 | Packages without an identifier | Application identifier `io.github.s0r81.bookscraft` (Flathub rule for GitHub-hosted apps); a CLI and server tarball beside the desktop packages; draft releases on `v*` tags | The identifier is expensive to change after the first release; server mode needs a binary |
| ADR-0028 | Required: fmt, clippy, 3-OS tests, cargo-deny, spine | Also `lint`, `scope` and `dco` (ten required checks) | Ownership and sign-off are enforced by CI, not by convention |
| ADR-0029 | Steps run once a crate declares their capabilities | 31 steps run in order; the first step with missing capabilities, and every later step, report pending | A later step depends on earlier steps' data |
| ADR-0030 | CSS, host page, Typst, Flatpak, container files | Also the desktop entry and AppStream metainfo, and `.claude/hooks/session-start.sh` as the one allowed shell script (installing Rust) | D-1 exempts the minimal shell needed to install Rust |
| G-19 | Accountant = bookkeeper rights without user admin | Accountant = bookkeeper rights plus period locks and overrides, audit log, imports, exports and backups; no settings, members, users or bank feeds (API.md §6) | Matches what an outside accountant does at close |
| Wave 0 order | Contracts, store and ledger in parallel | W0-01, then W0-02 (with W0-06 beside it), then W0-05, W0-04, W0-03; `domain` depends only on `money` | `store` reuses `ledger`'s error codes and `BalancedEntry`; ordering removes a circular wait |
| Infrastructure wiring | — | Fixed infrastructure constructors in each crate and `app::infra` (ARCHITECTURE §4.5); `render` depends on `store` | Shells can build a production `Infra` without later edits to `app` |
| MCP stdio | stdio locally or against a server | stdio on a local company file only; remote agents use `/mcp` | A stdio-to-server bridge adds a client stack for no MVP need |
| MCP placement | Brief §9 puts the MCP server in Phase 2 | A late-MVP stretch (W5-02) that may slip to v1; the agent rule (I-10) ships in the MVP either way (ADR-0022, ROADMAP §9) | Agents are part of the positioning; the enforcement already exists in the services |
| Custom fields | Brief §3: custom fields in v1 | Definitions and values (schema, service, API, import) in the MVP; the management UI in v1 | Lossless QBO import keeps transaction custom fields (MIGRATION_SPEC §4.3); the same pattern as dimensions (C-5) |
| IIF | Register and MIGRATION_SPEC: parser and writer in the MVP, import path in v1 | Parser, writer and import path all in v1; the `iif` crate stays a stub until then | Brief §3 and §7.3 put IIF in v1, and nothing in the MVP uses it |
| G-16 cut-over | Default full history; option: cut-over import | Full history is the MVP; the QBO cut-over import is v1 (ROADMAP §6.1) | The MVP exit only needs full history; cut-over needs extra report-based opening balances |
| G-6 clearing | Changing a cleared line's account, amount or date needs an explicit, audited un-clear | A cleared but unreconciled line that a repost changes is un-cleared automatically, with reason `document edited` and a clearing event; only reconciled lines need the explicit, audited unreconcile (LEDGER_SPEC §11) | Cleared-but-unreconciled state is a working state; the frozen record is the completed reconciliation |
| Email settings | Per company (API draft) | Installation settings (`/api/v1/settings/email`, `installation.manage`) stored in the system file | One company's admin must not redirect another company's mail on a shared server |
| Customer statements | `contacts.statement` endpoint | Removed from the MVP; open items per contact remain (`contacts.open_items`) | Not in the brief's MVP, and no work package delivered it |

## 10. Questions for the owner (checkpoint)

| ID | Question | Default if unanswered | Answer (2026-10-10) |
|---|---|---|---|
| Q-1 | Which Linux distro and desktop will the UI spike be checked on? NVIDIA + Wayland matters for the webview | Fedora with GNOME on Wayland | Fedora (owner), GNOME on Wayland, NVIDIA RTX 3060 |
| Q-2 | GitHub plan, repo name and visibility. No repo exists yet and this session can't create one | Public `S0r81/bookscraft`, created empty, with the Claude GitHub App installed | Default |
| Q-3 | Claude plan, whether Projects (beta) shows at claude.ai/code, and how many sessions to run at once | 3 concurrent work packages | Default |
| Q-4 | Under "100% Rust", are hand-written CSS, one HTML host page and Typst templates acceptable as data files? | Yes; no JavaScript and no Node anywhere | Default |
| Q-5 | ArtCraft avoids web views. Is an OS webview (not Electron) acceptable for BooksCraft? | Yes; README makes no "no web views" claim | Default |
| Q-6 | AGPL-3.0-only or AGPL-3.0-or-later? | AGPL-3.0-only | Default |
| Q-7 | Scope moves: manual sales tax into MVP; server mode with local accounts in MVP and OIDC in v1; PWA and OCR to v1 | Accept all three | Default |
| Q-8 | Is the MVP pilot company your own agency's QBO file? That decides whether your own Intuit app is enough for MVP | Yes, so no relay before v1 | Default |
| Q-9 | Which name and email should agent-written commits use in `Signed-off-by`? | Ask again before the first Wave 0 commit | Open: the owner fills in CLAUDE.md §8 before W0-01 (playbook §1.1 step 4); the W0-01 precondition and CI job `dco` refuse the placeholder |

## 11. Independent review log (Step 4)

Findings from the independent qa-verifier review that were rejected are logged here with reasons.

| Finding | Source | Disposition | Reason |
|---|---|---|---|
| None yet | Step 4 has not run | n/a | n/a |
