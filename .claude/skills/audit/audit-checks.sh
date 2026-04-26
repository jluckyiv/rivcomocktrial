#!/usr/bin/env bash
# audit-checks.sh [project-root]
# Targeted grep checks for SvelteKit + PocketBase anti-patterns.
# Called by the /audit skill (step 3).
# Auto-detects project root from package.json if not provided.
# Uses rg if available, falls back to grep.

set -euo pipefail

if [ -n "${1:-}" ]; then
    ROOT="$1"
else
    PKG=$(find . -name package.json -not -path "*/node_modules/*" \
        -not -path "*/web/node_modules/*" | head -1)
    if [ -z "$PKG" ]; then
        echo "ERROR: could not find package.json" >&2
        exit 1
    fi
    ROOT="$(dirname "$PKG")"
    # If the package.json is in web/, the repo root is one level up.
    if [ "$(basename "$ROOT")" = "web" ]; then
        ROOT="$(dirname "$ROOT")"
    fi
fi

WEB="$ROOT/web/src"
HOOKS="$ROOT/backend/pb_hooks"

if ! command -v rg >/dev/null 2>&1; then
    echo "ERROR: ripgrep (rg) not installed" >&2
    exit 1
fi

run() {
    local label="$1"; shift
    echo "=== $label ==="
    "$@" || true
    echo ""
}

# ---------- SvelteKit / TS ----------

run "Svelte 4 reactive 'let' in .svelte files (should be \$state)" \
    rg -n --type-add 'svelte:*.svelte' --type svelte \
       '^\s*let\s+\w+\s*=\s*[^;]+;?\s*$' "$WEB" \
       --glob '!**/node_modules/**'

run "Svelte 4 reactive '\$:' blocks (should be \$derived)" \
    rg -n --type-add 'svelte:*.svelte' --type svelte \
       '^\s*\$:' "$WEB" \
       --glob '!**/node_modules/**'

run "': any' type annotations (use unknown + narrow)" \
    rg -n ':\s*any\b' "$WEB" \
       --glob '!**/node_modules/**' \
       --glob '!**/*.test.ts'

run "'as any' casts (use unknown + narrow)" \
    rg -n '\bas\s+any\b' "$WEB" \
       --glob '!**/node_modules/**' \
       --glob '!**/*.test.ts'

run "'as <Type>' casts (review: justified at a real boundary?)" \
    rg -n '\bas\s+[A-Z]\w+' "$WEB" \
       --glob '!**/node_modules/**' \
       --glob '!**/*.test.ts'

run "localStorage with auth-shaped keys (auth belongs in cookies)" \
    rg -n 'localStorage\.(get|set|remove)Item.*(auth|token|user|session)' "$WEB" \
       --glob '!**/node_modules/**'

run "Direct 'new PocketBase(' outside hooks.server.ts (use event.locals.pb)" \
    rg -n 'new\s+PocketBase\s*\(' "$WEB" \
       --glob '!**/node_modules/**' \
       --glob '!**/hooks.server.ts'

run "Client-side fetch() in .svelte files (prefer load() in +page.server.ts)" \
    rg -n --type-add 'svelte:*.svelte' --type svelte \
       'fetch\s*\(' "$WEB" \
       --glob '!**/node_modules/**'

# ---------- PocketBase pb_hooks ----------

if [ -d "$HOOKS" ]; then
    run "Filter functions in pb_hooks (verify {:param} syntax, no concat)" \
        rg -n 'findRecordsByFilter|findFirstRecordByFilter' "$HOOKS"

    run "PK lookup via filter (use findRecordById)" \
        rg -n 'findRecordsByFilter.*"id\s' "$HOOKS"

    run "\$app.save calls in pb_hooks (wrap post-commit in try/catch)" \
        rg -n '\$app\.save\b' "$HOOKS"

    run "Top-level 'const' in pb_hook files (PB v0.36 JSVM resets — use require())" \
        rg -n '^const\s+\w+' "$HOOKS" --glob '!**/_constants.js'

    run "switch without default in pb_hooks (every switch needs a default)" \
        rg -n 'switch\s*\(' "$HOOKS"
fi

# ---------- General ----------

run "console.log in source (debugging leftovers?)" \
    rg -n 'console\.log\s*\(' "$WEB" "$HOOKS" \
       --glob '!**/node_modules/**' \
       --glob '!**/*.test.ts' \
       --glob '!**/*.spec.ts' 2>/dev/null

run "Silent catch blocks (catch {} or catch (e) {})" \
    rg -n 'catch\s*(\([^)]*\))?\s*\{\s*\}' "$WEB" "$HOOKS" \
       --glob '!**/node_modules/**' 2>/dev/null
