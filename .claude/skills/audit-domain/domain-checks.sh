#!/usr/bin/env bash
# domain-checks.sh [project-root]
# Grep-based anti-pattern checks for the TS domain layer.
# Called by the /audit-domain skill (step 1).
# Auto-detects project root from package.json if not provided.
# Uses rg (ripgrep) — required.

set -euo pipefail

if [ -n "${1:-}" ]; then
    ROOT="$1"
else
    PKG=$(find . -name package.json -not -path "*/node_modules/*" \
        -not -path "*/web/node_modules/*" \
        -not -path "*/frontend/*" | head -1)
    if [ -z "$PKG" ]; then
        echo "ERROR: could not find package.json" >&2
        exit 1
    fi
    ROOT="$(dirname "$PKG")"
    if [ "$(basename "$ROOT")" = "web" ]; then
        ROOT="$(dirname "$ROOT")"
    fi
fi

if ! command -v rg >/dev/null 2>&1; then
    echo "ERROR: ripgrep (rg) not installed" >&2
    exit 1
fi

DOMAIN="$ROOT/web/src/lib/domain"
LIB="$ROOT/web/src/lib"
ROUTES="$ROOT/web/src/routes"

run() {
    local label="$1"; shift
    echo "=== $label ==="
    "$@" || true
    echo ""
}

# ------------------------------------------------------------------ #
# RUBRIC 1 — Boolean state machine flags in domain types
# Grep for ': boolean' in type/interface definitions in domain modules.
# ------------------------------------------------------------------ #

run "Boolean fields in domain types (flag state-machine booleans)" \
    rg -n ':\s*boolean\b' "$DOMAIN" \
       --glob '!**/*.test.ts' \
       --glob '!**/node_modules/**'

# ------------------------------------------------------------------ #
# RUBRIC 2 — Non-exhaustive switch: default without never-check
# Look for 'default:' lines in domain/ and route server files.
# Context lines help Opus judge whether never-narrowing is present.
# ------------------------------------------------------------------ #

run "switch default branches in domain/ (check for never-narrowing)" \
    rg -n -A3 '^\s*default:' "$DOMAIN" \
       --glob '!**/*.test.ts'

run "switch default branches in route server files (check for never-narrowing)" \
    rg -n -A3 '^\s*default:' "$ROUTES" \
       --glob '!**/node_modules/**' \
       --glob '*.server.ts' \
    | grep -v 'async\s*(' || true
# NOTE: 'default: async ...' is SvelteKit form action syntax, not a switch default.

# ------------------------------------------------------------------ #
# RUBRIC 3 — Validation cascades: multiple sequential if(!x.field)
# Flag functions with 3+ guard-style field checks.
# ------------------------------------------------------------------ #

run "Sequential field-guard checks in domain/ (possible validation cascade)" \
    rg -n 'if\s*\(!' "$DOMAIN" \
       --glob '!**/*.test.ts'

# ------------------------------------------------------------------ #
# RUBRIC 4 — Domain logic in routes
# Flag route server files with significant non-trivial blocks.
# Report line counts and function-call patterns.
# ------------------------------------------------------------------ #

run "Business-logic keywords in route server files (state transitions, eligibility)" \
    rg -n 'status\s*===|status\s*!==|\.filter\(|\.map\(|\.reduce\(' "$ROUTES" \
       --glob '*.server.ts' \
       --glob '!**/node_modules/**'

# ------------------------------------------------------------------ #
# RUBRIC 5 — Mutation in load()
# Flag create/update/delete calls inside load() functions.
# ------------------------------------------------------------------ #

run "PB create/update/delete inside route files (verify NOT inside load())" \
    rg -n '\.create\s*\(|\.update\s*\(|\.delete\s*\(' "$ROUTES" \
       --glob '*.server.ts' \
       --glob '!**/node_modules/**'

# ------------------------------------------------------------------ #
# RUBRIC 6 — +server.ts for form POSTs
# ------------------------------------------------------------------ #

run "+server.ts files (any are potentially form-POST candidates)" \
    find "$ROUTES" -name '+server.ts' 2>/dev/null || echo "(none found)"
echo ""

# ------------------------------------------------------------------ #
# RUBRIC 7 — Result-shape inconsistency
# Flag 'reason:' or 'message:' in Result-shaped returns (vs 'error:').
# ------------------------------------------------------------------ #

run "Non-standard Result fields in domain/ ('reason' or 'message' vs 'error')" \
    rg -n '\{ ok:\s*(true|false)[^}]*\b(reason|message)\b' "$DOMAIN" \
       --glob '!**/*.test.ts'

# Also catch the split-line variant
run "Standalone 'reason:' fields in domain return types" \
    rg -n '^\s*reason\s*:' "$DOMAIN" \
       --glob '!**/*.test.ts'

# ------------------------------------------------------------------ #
# RUBRIC 8 — 'enum' keyword
# The codebase uses 'as const' + derived type union instead.
# ------------------------------------------------------------------ #

run "'enum' keyword in web/src/lib/ (use 'as const' + derived type)" \
    rg -n '^\s*enum\s+\w+' "$LIB" \
       --glob '!**/node_modules/**' \
       --glob '!**/*.test.ts'

# ------------------------------------------------------------------ #
# RUBRIC 9 — 'any' and unjustified 'as' casts in domain/
# ------------------------------------------------------------------ #

run "': any' in domain/ (Critical — use unknown + narrowing)" \
    rg -n ':\s*any\b' "$DOMAIN" \
       --glob '!**/*.test.ts'

run "'as any' in domain/ (Critical)" \
    rg -n '\bas\s+any\b' "$DOMAIN" \
       --glob '!**/*.test.ts'

run "'as <Type>' casts in domain/ (review: justified at boundary?)" \
    rg -n '\bas\s+[A-Z][A-Za-z]+' "$DOMAIN" \
       --glob '!**/*.test.ts'

# ------------------------------------------------------------------ #
# RUBRIC 10 — Return type boolean for state queries
# Functions whose name does NOT start with 'is', 'has', or 'can'
# but whose return annotation is ': boolean'.
# ------------------------------------------------------------------ #

run "Functions with ':boolean' return type in domain/ (check if name implies state)" \
    rg -n 'function\s+\w+[^(]*\([^)]*\)\s*:\s*boolean' "$DOMAIN" \
       --glob '!**/*.test.ts'

# ------------------------------------------------------------------ #
# RUBRIC 11 — Optional fields as state markers
# 'field?: string' or 'field?: number' in type/interface blocks.
# ------------------------------------------------------------------ #

run "Optional fields in domain types (check if optional presence signals state)" \
    rg -n '^\s+\w+\?\s*:' "$DOMAIN" \
       --glob '!**/*.test.ts'

# ------------------------------------------------------------------ #
# RUBRIC 12 — $effect writing derivable state (in .svelte files)
# Flag $effect blocks that assign to $state variables.
# NOTE: mutation INSIDE $state is idiomatic — flag only $effect that
# re-assigns the $state variable itself based on reactive values.
# ------------------------------------------------------------------ #

run "\$effect blocks in route .svelte files (check for state reassignment)" \
    rg -n --type-add 'svelte:*.svelte' --type svelte \
       '\$effect\s*\(' "$ROUTES" \
       --glob '!**/node_modules/**' || true

# ------------------------------------------------------------------ #
# RUBRIC 13 — Top-level mutable 'let' in server route files
# A bare 'let' at module scope (line starts with 'let ') is per-process
# state — leaks across requests.
# ------------------------------------------------------------------ #

run "Module-scope 'let' in route server files (Critical — leaks across requests)" \
    rg -n '^let\s+' "$ROUTES" \
       --glob '*.server.ts' \
       --glob '!**/node_modules/**'
# NOTE: Only zero-indented 'let' is truly module scope. Indented 'let' inside
# function bodies is normal and not flagged here.

# ------------------------------------------------------------------ #
# SUMMARY: file inventory
# ------------------------------------------------------------------ #

echo "=== Domain module inventory ==="
find "$DOMAIN" -name '*.ts' -not -name '*.test.ts' | sort
echo ""

echo "=== Route server file inventory ==="
find "$ROUTES" \( -name '+page.server.ts' -o -name '+layout.server.ts' \
    -o -name '+server.ts' \) | sort
echo ""

echo "=== domain-checks.sh complete ==="
