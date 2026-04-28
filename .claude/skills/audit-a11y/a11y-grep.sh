#!/usr/bin/env bash
# a11y-grep.sh [project-root]
# Static accessibility anti-pattern checks for .svelte files.
# Called by the /audit-a11y skill (step 1).
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

ROUTES="$ROOT/web/src/routes"
COMPONENTS="$ROOT/web/src/lib/components"

run() {
    local label="$1"; shift
    echo "=== $label ==="
    "$@" 2>/dev/null || true
    echo ""
}

# ------------------------------------------------------------------ #
# RUBRIC 1 — <div onclick= or <span onclick= (use <button>)
# ------------------------------------------------------------------ #

run "Non-interactive elements with click handlers (div/span onclick)" \
    rg -n --type-add 'svelte:*.svelte' --type svelte \
       '<(div|span)[^>]*(on:click|onclick)' \
       "$ROUTES" "$COMPONENTS" \
       --glob '!**/node_modules/**'

# ------------------------------------------------------------------ #
# RUBRIC 2 — <a href="javascript:
# ------------------------------------------------------------------ #

run "<a href=\"javascript:\" (use <button> for non-navigation actions)" \
    rg -n --type-add 'svelte:*.svelte' --type svelte \
       'href="javascript:' \
       "$ROUTES" "$COMPONENTS" \
       --glob '!**/node_modules/**'

# ------------------------------------------------------------------ #
# RUBRIC 3 — <a> without href (not keyboard-focusable by default)
# Matches <a> and <a ...> that don't include href.
# ------------------------------------------------------------------ #

run "<a> elements without href attribute" \
    rg -n --type-add 'svelte:*.svelte' --type svelte \
       '<a(\s[^>]*)?>(?![^<]*href)' \
       "$ROUTES" "$COMPONENTS" \
       --glob '!**/node_modules/**'

# ------------------------------------------------------------------ #
# RUBRIC 4 — <img> without alt attribute
# ------------------------------------------------------------------ #

run "<img> elements without alt attribute" \
    rg -n --type-add 'svelte:*.svelte' --type svelte \
       '<img\b(?![^>]*\balt=)[^>]*>' \
       "$ROUTES" "$COMPONENTS" \
       --glob '!**/node_modules/**'

# ------------------------------------------------------------------ #
# RUBRIC 5 — <img alt=""> — may be intentional (decorative) or missed
# ------------------------------------------------------------------ #

run "<img alt=\"\"> (verify intentionally decorative; flag if not)" \
    rg -n --type-add 'svelte:*.svelte' --type svelte \
       'alt=""' \
       "$ROUTES" "$COMPONENTS" \
       --glob '!**/node_modules/**'

# ------------------------------------------------------------------ #
# RUBRIC 6 — <input> elements (collect for label association review)
# Axe verifies associations at runtime; this gives Opus the list.
# ------------------------------------------------------------------ #

run "<input> elements (Opus verifies label association via for/id/aria-label)" \
    rg -n --type-add 'svelte:*.svelte' --type svelte \
       '<input\b' \
       "$ROUTES" "$COMPONENTS" \
       --glob '!**/node_modules/**'

# ------------------------------------------------------------------ #
# RUBRIC 7 — Form <input> without name attribute
# ------------------------------------------------------------------ #

run "<input> elements without name attribute" \
    rg -n --type-add 'svelte:*.svelte' --type svelte \
       '<input\b(?![^>]*\bname=)[^/]*/?' \
       "$ROUTES" "$COMPONENTS" \
       --glob '!**/node_modules/**'

# ------------------------------------------------------------------ #
# RUBRIC 8 — role="button" on non-button element
# Check for tabindex and keyboard handler presence in context.
# ------------------------------------------------------------------ #

run "role=\"button\" on non-button elements (check tabindex + keyboard handler)" \
    rg -n --type-add 'svelte:*.svelte' --type svelte \
       -A5 'role="button"' \
       "$ROUTES" "$COMPONENTS" \
       --glob '!**/node_modules/**'

# ------------------------------------------------------------------ #
# RUBRIC — outline-none without a focus replacement
# Tailwind's outline-none suppresses the focus ring; safe only with
# a visible alternative (ring-*, focus:ring-*, etc.).
# ------------------------------------------------------------------ #

run "outline-none without apparent focus replacement (check Tailwind classes)" \
    rg -n --type-add 'svelte:*.svelte' --type svelte \
       'outline-none' \
       "$ROUTES" "$COMPONENTS" \
       --glob '!**/node_modules/**'

# ------------------------------------------------------------------ #
# SUMMARY: route .svelte file inventory
# ------------------------------------------------------------------ #

echo "=== Route .svelte file inventory (for heading hierarchy review) ==="
find "$ROUTES" -name '*.svelte' | sort
echo ""

echo "=== Component .svelte file inventory ==="
find "$COMPONENTS" -name '*.svelte' 2>/dev/null | sort || true
echo ""

echo "=== a11y-grep.sh complete ==="
