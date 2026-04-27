#!/usr/bin/env bash
# schema-completeness.sh [repo-root]
# Gathers live PocketBase rule strings and spec assertions for the /audit-schema skill.
# Outputs structured data for the Opus agent brief.
#
# Prerequisites:
#   - Test PB running on port 28090 (npm run pb:test:up from repo root)
#   - .env.test sourced (or PB_URL / PB_ADMIN_EMAIL / PB_ADMIN_PASSWORD set)
#   - rg (ripgrep) installed
#   - jq installed

set -euo pipefail

ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
TYPES_FILE="$ROOT/web/src/lib/pocketbase-types.ts"
SCHEMA_DIR="$ROOT/web/src/lib/schema"
ENV_FILE="$ROOT/.env.test"

# ---------- prerequisites ----------

if ! command -v rg >/dev/null 2>&1; then
    echo "ERROR: ripgrep (rg) not installed" >&2; exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq not installed" >&2; exit 1
fi
if [ ! -f "$TYPES_FILE" ]; then
    echo "ERROR: $TYPES_FILE not found" >&2; exit 1
fi
if [ ! -d "$SCHEMA_DIR" ]; then
    echo "ERROR: $SCHEMA_DIR not found" >&2; exit 1
fi

# Source .env.test if vars not already set
if [ -z "${PB_URL:-}" ] && [ -f "$ENV_FILE" ]; then
    # shellcheck disable=SC1090
    set -a; source "$ENV_FILE"; set +a
fi

PB_URL="${PB_URL:-http://localhost:28090}"
PB_ADMIN_EMAIL="${PB_ADMIN_EMAIL:-}"
PB_ADMIN_PASSWORD="${PB_ADMIN_PASSWORD:-}"

if [ -z "$PB_ADMIN_EMAIL" ] || [ -z "$PB_ADMIN_PASSWORD" ]; then
    echo "ERROR: PB_ADMIN_EMAIL and PB_ADMIN_PASSWORD must be set (source .env.test)" >&2
    exit 1
fi

# ---------- health check ----------

echo "=== Test PB health ==="
HEALTH=$(curl -sf "$PB_URL/api/health" 2>&1 || true)
if [ -z "$HEALTH" ]; then
    echo "ERROR: Test PB not responding at $PB_URL. Run: npm run pb:test:up" >&2
    exit 1
fi
echo "OK: $PB_URL is up"
echo ""

# ---------- authenticate ----------

echo "=== Superuser auth ==="
AUTH_RESP=$(curl -sf -X POST "$PB_URL/api/collections/_superusers/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"$PB_ADMIN_EMAIL\",\"password\":\"$PB_ADMIN_PASSWORD\"}" 2>&1)

TOKEN=$(echo "$AUTH_RESP" | jq -r '.token // empty')
if [ -z "$TOKEN" ]; then
    echo "ERROR: Auth failed. Response: $AUTH_RESP" >&2
    exit 1
fi
echo "OK: authenticated as superuser"
echo ""

# ---------- enumerate collections from pocketbase-types.ts ----------

echo "=== Collections enum (from pocketbase-types.ts) ==="
# Extract values from the Collections = { ... } as const block only.
# Each line looks like:   KeyName: "collection_name",
# We capture only the quoted value on lines between "const Collections = {" and "} as const".
mapfile -t ALL_COLLECTIONS < <(
    awk '/^export const Collections = \{/,/^\} as const/' "$TYPES_FILE" \
        | rg --only-matching '"[a-z][^"]+"' \
        | tr -d '"' \
        | sort
)
mapfile -t SYSTEM_COLLECTIONS < <(
    awk '/^export const Collections = \{/,/^\} as const/' "$TYPES_FILE" \
        | rg --only-matching '"_[^"]+"' \
        | tr -d '"' \
        | sort
)

echo "User collections (${#ALL_COLLECTIONS[@]}): ${ALL_COLLECTIONS[*]}"
echo "System collections (skipped): ${SYSTEM_COLLECTIONS[*]}"
echo ""

# ---------- fetch live rules for each collection ----------

echo "=== Live rule strings from test PB ==="
declare -A LIVE_RULES  # collection -> JSON blob

for col in "${ALL_COLLECTIONS[@]}"; do
    RESP=$(curl -sf "$PB_URL/api/collections/$col" \
        -H "Authorization: $TOKEN" 2>&1 || true)

    if [ -z "$RESP" ]; then
        echo "SKIP $col: not found (404 or empty)"
        LIVE_RULES["$col"]="NOT_FOUND"
        continue
    fi

    # Check for error
    CODE=$(echo "$RESP" | jq -r '.code // empty' 2>/dev/null || true)
    if [ "$CODE" = "404" ]; then
        echo "SKIP $col: 404"
        LIVE_RULES["$col"]="NOT_FOUND"
        continue
    fi

    LIST=$(echo "$RESP" | jq -r '.listRule // "null"')
    VIEW=$(echo "$RESP" | jq -r '.viewRule // "null"')
    CREATE=$(echo "$RESP" | jq -r '.createRule // "null"')
    UPDATE=$(echo "$RESP" | jq -r '.updateRule // "null"')
    DELETE=$(echo "$RESP" | jq -r '.deleteRule // "null"')

    echo "$col:"
    echo "  listRule:   $LIST"
    echo "  viewRule:   $VIEW"
    echo "  createRule: $CREATE"
    echo "  updateRule: $UPDATE"
    echo "  deleteRule: $DELETE"

    LIVE_RULES["$col"]="list=$LIST|view=$VIEW|create=$CREATE|update=$UPDATE|delete=$DELETE"
done
echo ""

# ---------- spec file inventory ----------

echo "=== Spec file inventory ==="
SPEC_FILES=()
while IFS= read -r f; do
    SPEC_FILES+=("$f")
    echo "  $f"
done < <(find "$SCHEMA_DIR" -name '*.spec.ts' | sort)
echo ""

# ---------- assertions found in spec files ----------

echo "=== Assertions in spec files ==="
echo "(toBe / toBeNull calls per collection)"
echo ""

for spec in "${SPEC_FILES[@]}"; do
    echo "--- $(basename "$spec") ---"
    # Show every getCollection() call and the surrounding it() / toBe() / toBeNull() context
    rg -n "getCollection\(|\.listRule|\.viewRule|\.createRule|\.updateRule|\.deleteRule|toBe\(|toBeNull\(\)|it\.skip" \
        "$spec" || echo "  (no assertions found)"
    echo ""
done

# ---------- coverage summary by collection ----------

echo "=== Coverage summary ==="
echo "Collections with no spec assertions:"
for col in "${ALL_COLLECTIONS[@]}"; do
    # Check if collection name appears in any spec file
    FOUND=$(rg -l "getCollection\('$col'\)" "$SCHEMA_DIR" 2>/dev/null || true)
    if [ -z "$FOUND" ]; then
        echo "  MISSING: $col"
    fi
done
echo ""

echo "=== skipped tests (it.skip) ==="
rg -n "it\.skip" "$SCHEMA_DIR" || echo "  None found"
echo ""
