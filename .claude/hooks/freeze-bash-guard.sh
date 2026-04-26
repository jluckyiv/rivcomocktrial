#!/usr/bin/env bash
# PreToolUse hook for Bash. Blocks shell commands that would write to
# frozen backend paths.
#
# Frozen paths:
#   backend/pb_hooks/**
#   backend/pb_migrations/**
#
# Override: PERSISTENCE_UNFREEZE=1 (in-session, per-invocation).
#
# Exit codes:
#   0 — allow
#   2 — block

set -euo pipefail

if [[ "${PERSISTENCE_UNFREEZE:-0}" == "1" ]]; then
  exit 0
fi

input=$(cat)
cmd=$(jq -r '.tool_input.command // empty' <<<"$input")

# Frozen path pattern.
FROZEN='(backend/pb_hooks/|backend/pb_migrations/)'

# Common shell write idioms we want to catch before they touch a frozen
# path. We intentionally err on the side of blocking — if a developer
# needs to override, they can set PERSISTENCE_UNFREEZE=1.
WRITE='(>|>>|tee|sed -i|sd |perl -i|gawk -i|mv |cp |rm |truncate |touch |install |patch )'

if echo "$cmd" | grep -qE "$WRITE.*$FROZEN" \
   || echo "$cmd" | grep -qE "$FROZEN.*$WRITE"; then
  cat >&2 <<EOF
FROZEN PATH: this Bash command would write to a frozen path.

  Command: $cmd

The backend persistence layer is read-only during the SvelteKit rebuild.
Frozen paths:
  - backend/pb_hooks/**
  - backend/pb_migrations/**

If you need to thaw for one invocation, set PERSISTENCE_UNFREEZE=1.
EOF
  exit 2
fi

exit 0
