#!/usr/bin/env bash
# PreToolUse hook for Bash. Blocks shell commands that would write to
# frozen paths during the rivcomocktrial domain refactor (ADR-013).
#
# Frozen paths:
#   backend/pb_hooks/**
#   backend/pb_migrations/**
#   frontend/src/Api.elm   (until deleted per ADR-012)
#   frontend/src/Pb.elm
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

# Frozen path pattern. The leading anchors handle paths with or without
# the worktree prefix.
FROZEN='(backend/pb_hooks/|backend/pb_migrations/|frontend/src/Api\.elm|frontend/src/Pb\.elm)'

# Common shell write idioms we want to catch before they touch a frozen
# path. We intentionally err on the side of blocking — if a developer
# needs to override, they can set PERSISTENCE_UNFREEZE=1.
WRITE='(>|>>|tee|sed -i|sd |perl -i|gawk -i|mv |cp |rm |truncate |touch |install |patch )'

if echo "$cmd" | grep -qE "$WRITE.*$FROZEN" \
   || echo "$cmd" | grep -qE "$FROZEN.*$WRITE"; then
  cat >&2 <<EOF
FROZEN PATH: this Bash command would write to a frozen path.

  Command: $cmd

The persistence layer is read-only during the domain refactor
(ADR-013). Frozen paths:
  - backend/pb_hooks/**
  - backend/pb_migrations/**
  - frontend/src/Api.elm
  - frontend/src/Pb.elm

If a domain-side workaround is impossible and you need to thaw the
freeze for one invocation, set PERSISTENCE_UNFREEZE=1 and document
the change as its own ADR.
EOF
  exit 2
fi

exit 0
