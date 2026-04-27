#!/usr/bin/env bash
# docs-claims.sh [project-root]
# Extracts and cross-checks load-bearing claims in docs against code reality.
# Called by the /audit-docs skill (step 1).
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

DOCS="$ROOT/docs"
CLAUDE_MD="$ROOT/CLAUDE.md"
README="$ROOT/README.md"
WEB_PKG="$ROOT/web/package.json"
ROOT_PKG="$ROOT/package.json"
CADDYFILE="$ROOT/backend/Caddyfile"
DC_DEV="$ROOT/docker-compose.yml"
DC_TEST="$ROOT/docker-compose.test.yml"
HOOKS="$ROOT/backend/pb_hooks"

section() {
    echo "=== $1 ==="
}

# ------------------------------------------------------------------ #
# 1. DOCS INVENTORY
# ------------------------------------------------------------------ #

section "Docs in scope (docs/*.md, excluding archive/)"
find "$DOCS" -maxdepth 1 -name '*.md' | sort
echo ""

section "Hook files present in backend/pb_hooks/"
ls "$HOOKS/" 2>/dev/null || echo "(directory missing)"
echo ""

# ------------------------------------------------------------------ #
# 2. FILE PATH CLAIMS
# ------------------------------------------------------------------ #

section "File path references in docs — existence check"
echo "Checking backend/, web/, docs/, scripts/, .github/ path claims..."

# Extract path-like tokens from docs, check they exist on disk
rg --no-filename --only-matching \
    '[a-zA-Z0-9_][a-zA-Z0-9_/.-]*/[a-zA-Z0-9_][a-zA-Z0-9_/.-]+\.(ts|js|svelte|md|toml|yml|yaml|json|sh)' \
    "$CLAUDE_MD" "$README" "$DOCS" \
    --glob '!docs/archive/**' 2>/dev/null \
    | sort -u \
    | while IFS= read -r path; do
        # Only check repo-relative paths
        case "$path" in
            backend/*|web/*|docs/*|scripts/*|.github/*)
                if [ ! -e "$ROOT/$path" ]; then
                    echo "MISSING: $ROOT/$path"
                fi
                ;;
        esac
    done || echo "(no missing paths found)"
echo ""

# ------------------------------------------------------------------ #
# 3. SHELL COMMAND CLAIMS
# ------------------------------------------------------------------ #

section "Shell commands claimed in docs — cross-check against package.json scripts"

# Collect all 'npm run <script>' references from docs
CLAIMED_CMDS=$(rg --no-filename --only-matching 'npm run [a-z][a-z0-9:_-]+' \
    "$CLAUDE_MD" "$README" "$DOCS" \
    --glob '!docs/archive/**' 2>/dev/null \
    | sed 's/npm run //' | sort -u)

echo "Claimed commands:"
echo "$CLAIMED_CMDS" | while IFS= read -r cmd; do
    [ -z "$cmd" ] && continue
    in_root=$(grep -c "\"$cmd\"" "$ROOT_PKG" 2>/dev/null || true)
    in_web=$(grep -c "\"$cmd\"" "$WEB_PKG" 2>/dev/null || true)
    if [ "${in_root:-0}" -gt 0 ] || [ "${in_web:-0}" -gt 0 ]; then
        echo "  OK:      npm run $cmd"
    else
        echo "  MISSING: npm run $cmd"
    fi
done
echo ""

# ------------------------------------------------------------------ #
# 4. PORT NUMBER CLAIMS
# ------------------------------------------------------------------ #

section "Port numbers in docs"
echo "--- Port references in CLAUDE.md and README.md ---"
rg --no-filename --only-matching 'localhost:[0-9]{4,5}|:[0-9]{4,5}/' \
    "$CLAUDE_MD" "$README" 2>/dev/null | sort -u || echo "(none found)"
echo ""

echo "--- Caddyfile listen and proxy config ---"
cat "$CADDYFILE"
echo ""

echo "--- docker-compose.yml port mappings ---"
grep -E '"[0-9]+:[0-9]+"' "$DC_DEV" 2>/dev/null || echo "(none found)"
echo ""

echo "--- docker-compose.test.yml port mappings ---"
grep -E '"[0-9]+:[0-9]+"' "$DC_TEST" 2>/dev/null || echo "(none found)"
echo ""

# ------------------------------------------------------------------ #
# 5. STACK COMPONENT CLAIMS
# ------------------------------------------------------------------ #

section "Stack components: named in docs vs web/package.json"

echo "--- CSS framework references in docs ---"
echo "Bulma:"
rg --no-filename -i 'bulma' "$CLAUDE_MD" "$README" "$DOCS" \
    --glob '!docs/archive/**' 2>/dev/null || echo "  (not found)"
echo "Tailwind:"
rg --no-filename -i 'tailwind' "$CLAUDE_MD" "$README" "$DOCS" \
    --glob '!docs/archive/**' 2>/dev/null \
    | head -5 || echo "  (not found)"
echo ""

echo "--- web/package.json relevant deps ---"
grep -E '"(tailwind|bulma|svelte|vite|playwright|vitest|shadcn|pocketbase|adapter)' \
    "$WEB_PKG" 2>/dev/null | sed 's/^/  /' || echo "  (none)"
echo ""

# ------------------------------------------------------------------ #
# 6. HOOK FILE NAME CLAIMS
# ------------------------------------------------------------------ #

section "Hook file name claims in docs vs backend/pb_hooks/"

echo "--- Hook file references in docs ---"
rg --no-filename --only-matching '[a-z_]+\.pb\.js' \
    "$CLAUDE_MD" "$README" "$DOCS" \
    --glob '!docs/archive/**' 2>/dev/null | sort -u || echo "(none found)"
echo ""

echo "--- Cross-check claimed hooks vs actual files ---"
rg --no-filename --only-matching '[a-z_]+\.pb\.js' \
    "$CLAUDE_MD" "$README" "$DOCS" \
    --glob '!docs/archive/**' 2>/dev/null \
    | sort -u \
    | while IFS= read -r hookfile; do
        if [ -f "$HOOKS/$hookfile" ]; then
            echo "  OK:      $hookfile"
        else
            echo "  MISSING: $hookfile"
        fi
    done
echo ""

# ------------------------------------------------------------------ #
# 7. ADR SUPERSESSION CHECK
# ------------------------------------------------------------------ #

section "ADR supersession cross-check"

echo "--- ADRs with Superseded-by notes ---"
grep -n 'Superseded\|superseded' "$DOCS/decisions.md" 2>/dev/null \
    || echo "(none found)"
echo ""

echo "--- ADR-002 decision (Bulma — check if superseded) ---"
grep -n -B1 -A5 '^## ADR-002' "$DOCS/decisions.md" 2>/dev/null | head -12 || true
echo ""

echo "--- ADR-004 decision (admin auth — check if superseded) ---"
grep -n -B1 -A3 '^## ADR-004' "$DOCS/decisions.md" 2>/dev/null | head -8 || true
echo ""

echo "--- ADR-010 decision (PB SDK — check if superseded) ---"
grep -n -B1 -A3 '^## ADR-010' "$DOCS/decisions.md" 2>/dev/null | head -8 || true
echo ""

echo "--- ADR-011 decision (dual auth localStorage — check if superseded) ---"
grep -n -B1 -A3 '^## ADR-011' "$DOCS/decisions.md" 2>/dev/null | head -8 || true
echo ""

# ------------------------------------------------------------------ #
# 8. ARCHITECTURAL ASSERTIONS
# ------------------------------------------------------------------ #

section "Architectural assertions: Caddy proxy routing claims"
echo "--- Routing claims in docs ---"
rg --no-filename 'api/\*|_/\*|reverse.prox|Caddy listens|port 8090|port 8091|port 3000' \
    "$CLAUDE_MD" "$README" "$DOCS" \
    --glob '!docs/archive/**' 2>/dev/null | head -15 || echo "(none found)"
echo ""
echo "--- Actual Caddyfile ---"
cat "$CADDYFILE"
echo ""

section "PocketBase version claims"
echo "--- PB version in docs ---"
rg --no-filename --only-matching 'v0\.[0-9]+\.[0-9x]+' \
    "$CLAUDE_MD" "$README" "$DOCS" \
    --glob '!docs/archive/**' 2>/dev/null | sort -u || echo "(none found)"
echo ""
echo "--- PB version in Dockerfiles ---"
grep -n 'POCKETBASE_VERSION\|pocketbase/pocketbase\|v0\.[0-9]' \
    "$ROOT/backend/Dockerfile" "$ROOT/backend/Dockerfile.dev" 2>/dev/null \
    || echo "(no version pin found in Dockerfiles)"
echo ""

section "ADR change history (last 20 commits touching docs/decisions.md)"
git -C "$ROOT" log --oneline --follow -- docs/decisions.md 2>/dev/null \
    | head -20 || echo "(git log failed)"
echo ""

echo "=== docs-claims.sh complete ==="
