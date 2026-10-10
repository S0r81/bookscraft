# BooksCraft

Open-source, local-first accounting for small businesses: double-entry books you own, the daily workflows bookkeepers already know, and a verified way to bring your history over from QuickBooks Online.

> **Status: pre-alpha. There is no usable application yet.** This repository holds the architecture, specifications and build plan; the code is being built in planned waves (see the [roadmap](docs/roadmap/ROADMAP.md) and the [board](docs/coordination/BOARD.md)). Do not keep real books in BooksCraft until a release says it is ready.

## Why BooksCraft

- **Your books, your machine.** Each company is a single file on your computer, or on a server you run. Copy it, back it up, move it. Nothing is sent anywhere unless you set it up.
- **No tiers, no caps.** Every feature is in the open-source code. Users, accounts, tags and custom fields are unlimited.
- **Accountant-grade controls.** Posted entries are never edited in place: corrections are reversals, every change lands in a tamper-evident audit log, and closed periods can be locked hard.
- **Familiar from day one.** Invoices, bills, bank review, reconciliation and the standard reports work the way small-business bookkeepers expect, with keyboard-first data entry. The labels and help text are BooksCraft's own.
- **A way in, and a way out.** The migrator imports a QuickBooks Online company and checks the result against QuickBooks's own trial balance and agings, month by month, to the cent. Everything can be exported again as a documented bundle with CSV copies.
- **Agent-ready, human-approved.** A permission-scoped MCP server and a CLI let you use the AI model of your choice. Agents can only create drafts; a person approves before anything is posted, and the approval is audited.
- **Community-built.** AGPL-3.0 for the application, MIT for the reusable libraries, a public roadmap, and frequent public releases.

## What the first release (MVP) covers

| Area | Included |
|---|---|
| Ledger | Double-entry with reversals, chart of accounts with templates (freelancer, agency, service business), journal entries, opening balances, period locks, audit log |
| Sales | Customers, products and services, estimates, invoices (PDF and email), sales receipts, payments received, credit memos, refunds, deposits |
| Purchases | Vendors, bills, bill payments, vendor credits, expenses and checks |
| Banking | Statement import (OFX, QFX, QBO Web Connect, CSV), a review queue with match, add and exclude, bank rules, reconciliation; SimpleFIN live feeds late in the MVP |
| Sales tax | Manual agencies, rates and combined codes, with a liability report by agency |
| Reports | Trial balance, profit and loss, balance sheet, general ledger, journal, AR and AP aging, sales tax liability, on accrual or cash basis |
| Migration | QuickBooks Online (API) and CSV imports with parity validation and rollback; full export |
| Access | Desktop app for one person; server mode with multiple users and fixed roles |

The MVP is done when a real agency migrates from QuickBooks Online and closes a month with a trial balance that matches QuickBooks to the cent.

BooksCraft will not process payroll, move money or file taxes; it imports and integrates with services that do.

## Platforms

- **Desktop:** Linux first (AppImage, deb, rpm, Flatpak). Windows and macOS are built and tested in CI from the first build, and get signed installers in their own release milestone.
- **Server:** `bookscraft serve`, one binary, serves the same app to browsers for teams and accountants.

## How it is built

- 100% Rust: one core library with four shells (desktop, server, CLI, MCP server).
- One SQLite file per company, with the ledger rules enforced both in the type system and in the database.
- A Rust (Leptos) interface compiled to WebAssembly, shown in a Tauri desktop window or a browser. This choice is confirmed by a timeboxed spike before any interface work ([ADR-0002](docs/adr/0002-ui-framework.md)).

Start with [ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md), then the [ledger specification](docs/architecture/LEDGER_SPEC.md) and the [decision records](docs/adr/).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md): licensing, sign-off (DCO), the clean-room rules and development setup.

## License

The application is licensed under the [GNU Affero General Public License v3.0 only](LICENSE). The `money`, `ledger`, `interchange`, `iif`, `ofx` and `qbo` crates are licensed under the [MIT License](LICENSES/MIT.txt).

QuickBooks is a trademark of Intuit Inc. BooksCraft is an independent project, not affiliated with or endorsed by Intuit. It interoperates with QuickBooks Online through Intuit's public API and published file formats.
