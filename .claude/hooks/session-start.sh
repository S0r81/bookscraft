#!/bin/sh
# SPDX-License-Identifier: AGPL-3.0-only
# BooksCraft SessionStart bootstrap. This is the only shell script in the repository (ADR-0030):
# it makes sure rustup and the toolchain pinned in rust-toolchain.toml exist, then hands off to
# `cargo xtask`. It is idempotent and never fails the session: every path exits 0, and what it
# prints is added to Claude's context.
set -u
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

if ! command -v rustup >/dev/null 2>&1 && [ -x "$HOME/.cargo/bin/rustup" ]; then
  PATH="$HOME/.cargo/bin:$PATH"
  export PATH
fi

if ! command -v rustup >/dev/null 2>&1; then
  if [ "${CLAUDE_CODE_REMOTE:-}" = "true" ]; then
    # Cloud session without rustup: install it from the hosts on the default network allowlist.
    { curl --proto '=https' --tlsv1.2 -sSf https://static.rust-lang.org/rustup/rustup-init.sh \
        || curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs; } \
      | sh -s -- -y --profile minimal --default-toolchain none >/dev/null 2>&1
    PATH="$HOME/.cargo/bin:$PATH"
    export PATH
    if ! command -v rustup >/dev/null 2>&1; then
      echo "BooksCraft: installing rustup failed. Check that the cloud environment allows static.rust-lang.org (playbook section 2)."
      exit 0
    fi
  else
    echo "BooksCraft: rustup is not installed. Install it from https://rustup.rs, then restart the session."
    exit 0
  fi
fi

# Make cargo visible to the Bash commands Claude runs later in this session.
if [ -n "${CLAUDE_ENV_FILE:-}" ] && ! grep -qs '.cargo/bin' "$CLAUDE_ENV_FILE"; then
  echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> "$CLAUDE_ENV_FILE"
fi

if [ ! -f rust-toolchain.toml ]; then
  echo "BooksCraft: no rust-toolchain.toml yet; work package W0-01 creates it."
  exit 0
fi

# With no arguments, rustup installs the toolchain, components and targets named in rust-toolchain.toml.
if ! rustup toolchain install >/dev/null 2>&1; then
  echo "BooksCraft: 'rustup toolchain install' failed for rust-toolchain.toml. Run 'cargo xtask doctor' to see why."
  exit 0
fi

if [ -f xtask/Cargo.toml ]; then
  cargo xtask doctor --fix --quiet || echo "BooksCraft: 'cargo xtask doctor' reported problems (above)."
  # Warm the build cache in the background; its output is discarded so the hook returns now.
  nohup cargo xtask warm --quiet >/dev/null 2>&1 &
fi
exit 0
