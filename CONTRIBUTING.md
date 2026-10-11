# Contributing to BooksCraft

Thank you for helping build an open alternative to QuickBooks Online. BooksCraft is pre-alpha: the architecture is written, and the code is being built in planned waves. This guide covers licensing, sign-off, the rules every change follows, and how to set up a development machine.

## How work is organized

BooksCraft is built in **work packages**: small, planned pieces of work with fixed owned paths, acceptance criteria and verification commands. Most are carried out by Claude Code sessions under the owner's direction, and human contributors use the same structure.

| Document | What it tells you |
|---|---|
| [CLAUDE.md](CLAUDE.md) | The standing rules for every change, human or agent: invariants, ownership, tests, definition of done |
| [docs/prompts/00-INDEX.md](docs/prompts/00-INDEX.md) | Every work package, its wave and its prompt |
| [docs/coordination/BOARD.md](docs/coordination/BOARD.md) | What is planned, in progress, in review and merged |
| [docs/coordination/OWNERSHIP.md](docs/coordination/OWNERSHIP.md) | Which paths each work package may change |
| [docs/process/PARALLEL_DEV_PLAYBOOK.md](docs/process/PARALLEL_DEV_PLAYBOOK.md) | How waves, reviews and merges run |
| [docs/architecture/](docs/architecture/) and [docs/adr/](docs/adr/) | The design and the decisions behind it |

To contribute code, pick a work package that is `ready` on the board, or open an issue proposing one. If your change needs something outside the paths you are changing (a shared type, a schema change, a new dependency), write a contract change request (CCR) from [the template](docs/coordination/CCR/TEMPLATE.md) instead of making that change.

## Licensing

| Code | License |
|---|---|
| The application (every crate not listed below) | [AGPL-3.0-only](LICENSE) |
| `crates/money`, `crates/ledger`, `crates/interchange`, `crates/iif`, `crates/ofx`, `crates/qbo` | [MIT](LICENSES/MIT.txt) |

A contribution is licensed under the license of the files it changes. Every Rust file starts with an SPDX line (`// SPDX-License-Identifier: AGPL-3.0-only` or `// SPDX-License-Identifier: MIT`), and CI checks it. The MIT crates may depend only on other MIT crates and on permissively licensed external crates, so they stay reusable by anyone.

### No-relicensing pledge

BooksCraft uses the Developer Certificate of Origin, not a contributor license agreement. No contributor assigns copyright to anyone. The maintainers pledge that:

- the application stays under AGPL-3.0-only and the library crates listed above stay under MIT;
- the project will never ask contributors to sign a CLA or to grant rights that would allow relicensing, dual licensing or a closed edition;
- no feature of the accounting core will be withheld from the open-source code to sell it separately.

## Sign-off (DCO)

Every contribution must be signed off under the Developer Certificate of Origin 1.1:

```text
Developer Certificate of Origin
Version 1.1

Copyright (C) 2004, 2006 The Linux Foundation and its contributors.

Everyone is permitted to copy and distribute verbatim copies of this
license document, but changing it is not allowed.

Developer's Certificate of Origin 1.1

By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right under that license to submit that
    work with modifications, whether created in whole or in part
    by me, under the same open source license (unless I am
    permitted to submit under a different license), as indicated
    in the file; or

(c) The contribution was provided directly to me by some other
    person who certified (a), (b) or (c) and I have not modified
    it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution (including all
    personal information I submit with it, including my sign-off) is
    maintained indefinitely and may be redistributed consistent with
    this project or the open source license(s) involved.
```

**How to sign off here.** Pull requests are squash-merged, and the pull request description becomes the commit message. So the sign-off goes at the end of the pull request description:

```text
Signed-off-by: Your Name <you@example.com>
```

The CI job `dco` checks that the line is present and well formed. Use a real name and an address you can be reached at; it is published in the git history.

**AI-assisted contributions.** You may use AI tools, including Claude Code. The person who signs off is responsible for the contribution: you must have reviewed it, be able to explain it, and have the right to submit it. Commits written by an agent carry a `Co-Authored-By` trailer for transparency; the sign-off is always a human's.

## Rules every change follows

The full list is in [CLAUDE.md](CLAUDE.md). The ones contributors most often miss:

- **Money is exact.** Amounts are `i64` minor units with a currency. No floating point anywhere near money.
- **The ledger is append-only.** Posted entries are never updated or deleted; an edit is a reversal plus a new entry, and a void is a reversal.
- **Stay in your paths.** Change only the paths your work package owns; anything else is a CCR.
- **No new dependencies** without an accepted CCR, and never `cargo update`. Builds use `--locked`.
- **Rust only.** No JavaScript, TypeScript, Node, Python or shell scripts in the repository. [ADR-0030](docs/adr/0030-rust-boundary.md) lists the data files that are allowed and the single bootstrap script that installs Rust.
- **OS-specific code lives in `crates/platform`.** No shelling out to OS tools at runtime.
- **Tests come with the change:** unit tests, property tests for invariants, golden files for posting rules and reports.
- **Never rewrite history.** No force-pushes, rebases of shared branches or amended pushed commits. Update a branch by merging `main` into it.

### Clean room

BooksCraft interoperates with QuickBooks, but it is built only from Intuit's public API documentation and published file formats (IIF, OFX, QFX, QBO, CSV).

- Do not copy Intuit's interface text, screenshots, icons, layouts or sample data, and do not use their trademarks in the product. "QuickBooks" may appear only in factual statements about interoperability, such as "Import from QuickBooks Online".
- Never read or reverse-engineer QuickBooks Desktop company files (QBW).
- Test fixtures are written by hand from the public reference, with invented names and amounts. Never commit real customer or company data.

## Development setup

### Linux (Fedora, the primary development platform)

```sh
sudo dnf group install "c-development"
sudo dnf install webkit2gtk4.1-devel openssl-devel curl wget file \
  libappindicator-gtk3-devel librsvg2-devel libxdo-devel
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Then, from a clone of the repository:

```sh
cargo xtask doctor --fix   # installs the pinned toolchain, components and targets
cargo xtask ci             # runs what CI runs
```

On Debian or Ubuntu, the system packages are `build-essential curl wget file libwebkit2gtk-4.1-dev libssl-dev libxdo-dev libayatana-appindicator3-dev librsvg2-dev`.

### Windows and macOS

CI builds and tests BooksCraft on both from the first build. Install the [Tauri prerequisites](https://v2.tauri.app/start/prerequisites/) for your system (Microsoft C++ Build Tools and WebView2 on Windows, Xcode Command Line Tools on macOS), then rustup, then run the same `cargo xtask` commands. Release builds for Windows and macOS come with a later milestone ([ROADMAP](docs/roadmap/ROADMAP.md), M-WM).

### Using Claude Code

The repository ships its Claude Code configuration in [`.claude/`](.claude/): role definitions for each kind of work, the `/start-wp`, `/handoff`, `/ccr`, `/weave` and `/status` commands, and hooks that check the toolchain, format edited Rust files and keep a session inside its work package. The hooks assume a POSIX shell; on Windows, Claude Code runs them through Git Bash.

## Pull requests

1. Branch from `main`: `wp/<WP>-<slug>` for a planned work package.
2. Keep commits small and use Conventional Commits (`feat(sales): ...`, `fix(store): ...`).
3. Open the pull request with the title `<WP>: <title>` and fill in [the template](.github/pull_request_template.md), including command output for every acceptance criterion and your sign-off line.
4. Required checks: `fmt`, `clippy`, `lint`, `test` on Linux, Windows and macOS, `deny`, `spine`, `scope` and `dco`.
5. Pull requests are reviewed and squash-merged at the end of their wave.

## Reporting security problems

Please do not open a public issue for a vulnerability. Use GitHub's private vulnerability reporting on this repository (Security tab, "Report a vulnerability").

## Conduct

Be kind, assume good faith, and keep discussion about the work. Maintainers may edit or remove comments, and block participants, to keep the project welcoming.
