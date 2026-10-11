<!-- Title: "<WP id>: <short title>", for example "W2-01: Sales service and routes". Weaves: "Weave <n>: ...". -->

## Work package

- **WP:** <!-- e.g. W2-01 (docs/prompts/W2-01-sales.md) -->
- **Agent role:** <!-- e.g. ledger-engineer -->
- **Branch:** <!-- wp/W2-01-sales -->

## Owned paths touched

<!-- Paste the output of `cargo xtask scope <WP>`. It must say "OK: N files, all inside owned paths". -->

```text
```

## Public API changes

<!-- Expected: none outside your owned crates. List any change to a pub item in your own crates that other crates use. -->

- None

## CCRs raised

<!-- Links to docs/coordination/CCR/CCR-<WP>-*.md, or "None". -->

- None

## Acceptance criteria

<!-- Copy every acceptance criterion from your prompt, tick it, and paste the command plus its relevant output. Never tick a criterion without output. -->

- [ ] AC-1 …
  ```text
  $ <command>
  <output>
  ```

## Verify

<!-- Paste the summary lines of each command from the prompt's Verify section (fmt, clippy, tests, lint, spine). -->

```text
```

## Spine

<!-- `cargo xtask spine` summary: passed / failed / pending counts, and which steps this PR activated. -->

## Follow-ups

<!-- Work deferred, with the WP or wave it belongs to. -->

- None

## Sign-off

<!-- DCO 1.1 (CONTRIBUTING.md). This line becomes part of the squash commit message. CI job `dco` checks it. -->

Signed-off-by: <!-- Full Name <email> -->
