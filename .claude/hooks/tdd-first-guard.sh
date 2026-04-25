#!/usr/bin/env bash
# PreToolUse hook for Write/Edit/MultiEdit. Blocks the creation of a
# new domain module in frontend/src/ unless its sibling test file
# already exists in frontend/tests/ and contains at least one test.
#
# Domain modules live at frontend/src/<EntityName>.elm (top-level —
# the convention we keep, per docs/elm-conventions.md §1, Option A).
# The file Pb.elm and Api.elm are excluded; they have their own
# freeze rules. Subdirectories (Pages/, Layouts/, Shared/) are
# excluded — they're not domain modules.
#
# Override: TDD_BYPASS=1 (legitimate scaffolding only).
#
# Exit codes:
#   0 — allow
#   2 — block

set -euo pipefail

if [[ "${TDD_BYPASS:-0}" == "1" ]]; then
  exit 0
fi

input=$(cat)
tool=$(jq -r '.tool_name // empty' <<<"$input")
path=$(jq -r '.tool_input.file_path // .tool_input.path // empty' <<<"$input")

# Only police writes/edits to frontend/src/<TopLevel>.elm files.
# The path may be absolute or relative — strip everything before
# frontend/src/ to normalize.
case "$path" in
  *frontend/src/*.elm) ;;
  *) exit 0 ;;
esac

# Extract the relative path under frontend/src/.
rel="${path##*frontend/src/}"

# Skip subdirectory files — only top-level domain modules apply.
case "$rel" in
  */*) exit 0 ;;
esac

# Skip non-domain files: the wire format and port mechanics are
# handled by the freeze rules; the framework files are out of scope.
case "$rel" in
  Api.elm|Pb.elm|Effect.elm|Shared.elm|Auth.elm|UI.elm|RemoteData.elm|interop.js)
    exit 0
    ;;
esac

# Compute the matching test file path. The hook runs from the
# project root (or wherever Claude Code invokes it); we resolve the
# test path relative to the source file's directory.
src_dir="${path%/*}"                       # .../frontend/src
project_dir="${src_dir%/src}"              # .../frontend
test_path="${project_dir}/tests/${rel%.elm}Test.elm"

if [ ! -f "$test_path" ]; then
  cat >&2 <<EOF
TDD-FIRST: refusing to create $rel because its test file does not exist.

  Expected: $test_path

Per docs/refactor-process.md, new domain modules require their test
file to exist FIRST with at least one failing test. Create the test
file, write a failing test, then create the implementation.

Override (legitimate scaffolding only): TDD_BYPASS=1
EOF
  exit 2
fi

# Verify the test file actually contains tests. Cheap heuristic: it
# must contain "test " or "describe " or "fuzz ". We do not run
# elm-test here — that's CI's job. The hook is fast, not exhaustive.
if ! grep -qE '\b(test|describe|fuzz)\b' "$test_path"; then
  cat >&2 <<EOF
TDD-FIRST: $test_path exists but contains no tests.

Add at least one failing test before writing the implementation.

Override (legitimate scaffolding only): TDD_BYPASS=1
EOF
  exit 2
fi

exit 0
