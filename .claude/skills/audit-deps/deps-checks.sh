#!/usr/bin/env bash
# deps-checks.sh [project-root]
# Security and pin compliance checks for npm deps, GHA actions, and Dockerfiles.
# Called by the /audit-deps skill (step 1).
# Auto-detects project root from package.json if not provided.
# Uses rg (ripgrep) and jq — required.

set -uo pipefail

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

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq not installed" >&2
    exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
    echo "ERROR: npm not installed" >&2
    exit 1
fi

WORKFLOWS="$ROOT/.github/workflows"

section() {
    echo "=== $1 ==="
}

# ------------------------------------------------------------------ #
# npm audit — root
# npm audit exits 1 when vulnerabilities found; capture separately.
# ------------------------------------------------------------------ #

section "npm audit (root)"
(
    cd "$ROOT"
    AUDIT_JSON=$(npm audit --json 2>/dev/null) || true
    if [ -n "$AUDIT_JSON" ]; then
        echo "$AUDIT_JSON" | jq '{
            metadata: .metadata,
            vulnerabilities: (
                .vulnerabilities
                | to_entries
                | map({ name: .key, severity: .value.severity, fixAvailable: .value.fixAvailable })
            )
        }' 2>/dev/null || echo "$AUDIT_JSON" | head -40
    else
        npm audit 2>&1 | head -40 || true
    fi
)
echo ""

# ------------------------------------------------------------------ #
# npm audit — web/
# ------------------------------------------------------------------ #

section "npm audit (web/)"
(
    cd "$ROOT/web"
    AUDIT_JSON=$(npm audit --json 2>/dev/null) || true
    if [ -n "$AUDIT_JSON" ]; then
        echo "$AUDIT_JSON" | jq '{
            metadata: .metadata,
            vulnerabilities: (
                .vulnerabilities
                | to_entries
                | map({ name: .key, severity: .value.severity, fixAvailable: .value.fixAvailable })
            )
        }' 2>/dev/null || echo "$AUDIT_JSON" | head -40
    else
        npm audit 2>&1 | head -40 || true
    fi
)
echo ""

# ------------------------------------------------------------------ #
# npm outdated — root
# npm outdated exits 1 when packages are outdated.
# ------------------------------------------------------------------ #

section "npm outdated (root)"
(
    cd "$ROOT"
    OUTDATED=$(npm outdated --json 2>/dev/null) || true
    if [ -n "$OUTDATED" ] && [ "$OUTDATED" != "{}" ]; then
        echo "$OUTDATED" | jq 'to_entries | map({
            package: .key,
            current: .value.current,
            wanted: .value.wanted,
            latest: .value.latest,
            type: .value.type
        })' 2>/dev/null || echo "$OUTDATED"
    else
        echo "(no outdated packages)"
    fi
)
echo ""

# ------------------------------------------------------------------ #
# npm outdated — web/
# ------------------------------------------------------------------ #

section "npm outdated (web/)"
(
    cd "$ROOT/web"
    OUTDATED=$(npm outdated --json 2>/dev/null) || true
    if [ -n "$OUTDATED" ] && [ "$OUTDATED" != "{}" ]; then
        echo "$OUTDATED" | jq 'to_entries | map({
            package: .key,
            current: .value.current,
            wanted: .value.wanted,
            latest: .value.latest,
            type: .value.type
        })' 2>/dev/null || echo "$OUTDATED"
    else
        echo "(no outdated packages)"
    fi
)
echo ""

# ------------------------------------------------------------------ #
# GHA action pin scan
# ------------------------------------------------------------------ #

section "GHA action 'uses:' lines — all workflows"
rg -n 'uses:\s+\S+' "$WORKFLOWS" \
   --glob '*.yml' \
   --glob '*.yaml' 2>/dev/null || echo "(no workflows found)"
echo ""

section "GHA Critical: no version or @master/@main"
rg -n 'uses:\s+[^@\s]+\s*$' "$WORKFLOWS" --glob '*.yml' --glob '*.yaml' 2>/dev/null \
    && true || echo "  (none)"
rg -n 'uses:\s+\S+@(master|main)\b' "$WORKFLOWS" --glob '*.yml' --glob '*.yaml' 2>/dev/null \
    && true || echo "  (none)"
echo ""

section "GHA Warning: floating major @v[digit]"
rg -n 'uses:\s+\S+@v[0-9]+$' "$WORKFLOWS" --glob '*.yml' --glob '*.yaml' 2>/dev/null \
    && true || echo "  (none)"
echo ""

section "GHA OK: specific minor @v[digit].[digit]"
rg -n 'uses:\s+\S+@v[0-9]+\.[0-9]+' "$WORKFLOWS" --glob '*.yml' --glob '*.yaml' 2>/dev/null \
    && true || echo "  (none)"
echo ""

section "GHA Best: 40-char SHA pins"
rg -n 'uses:\s+\S+@[0-9a-f]{40}\b' "$WORKFLOWS" --glob '*.yml' --glob '*.yaml' 2>/dev/null \
    && true || echo "  (none)"
echo ""

# ------------------------------------------------------------------ #
# Dockerfile base image scan
# ------------------------------------------------------------------ #

# Collect all Dockerfiles, excluding node_modules and .claude worktrees
DOCKERFILES=$(find "$ROOT" -name 'Dockerfile*' \
    -not -path "*/node_modules/*" \
    -not -path "*/.claude/*" 2>/dev/null | sort)

section "Dockerfile inventory"
echo "$DOCKERFILES"
echo ""

if [ -n "$DOCKERFILES" ]; then
    section "Dockerfile FROM lines — all"
    echo "$DOCKERFILES" | xargs rg -n '^FROM\s+' 2>/dev/null || echo "(rg failed)"
    echo ""

    section "Dockerfile Critical: no tag or :latest"
    echo "$DOCKERFILES" | xargs rg -n '^FROM\s+[^\s:]+\s*(AS\s+\w+)?\s*$' 2>/dev/null \
        && true || echo "  (none)"
    echo "$DOCKERFILES" | xargs rg -n '^FROM\s+\S+:latest(\s|$)' 2>/dev/null \
        && true || echo "  (none)"
    echo ""

    section "Dockerfile Warning: floating major (e.g. node:20, alpine:3)"
    # Single integer version with no dot: image:20 or image:20-slim
    # [^\s:]+ stops before the colon; grep -v '\.[0-9]' excludes specific minors.
    echo "$DOCKERFILES" | xargs rg -n '^FROM\s+[^\s:]+:[0-9]+(-[a-z][a-z0-9]*)?' 2>/dev/null \
        | grep -v '\.[0-9]' | grep -v '@sha256:' \
        && true || echo "  (none)"
    echo ""

    section "Dockerfile OK: specific minor (e.g. node:20.11.0, alpine:3.19) — no SHA"
    # N.N or N.N.N version without @sha256
    echo "$DOCKERFILES" | xargs rg -n '^FROM\s+[^\s]+:[0-9]+\.[0-9]+' 2>/dev/null \
        | grep -v '@sha256:' \
        && true || echo "  (none)"
    echo ""

    section "Dockerfile Best: SHA digest pinned"
    echo "$DOCKERFILES" | xargs rg -n '^FROM\s+\S+@sha256:' 2>/dev/null \
        && true || echo "  (none)"
    echo ""

    section "Binary downloads (curl/wget) in Dockerfiles"
    echo "$DOCKERFILES" | xargs rg -n 'curl\b|wget\b' 2>/dev/null \
        && true || echo "  (none)"
    echo ""

    section "SHA256 verification in Dockerfiles"
    echo "$DOCKERFILES" | xargs rg -n 'sha256sum' 2>/dev/null \
        && true || echo "  (none)"
    echo ""

    section "Per-Dockerfile: binary download + verification check"
    while IFS= read -r df; do
        if rg -q 'curl\b|wget\b' "$df" 2>/dev/null; then
            echo "--- $df ---"
            if rg -q 'sha256sum' "$df" 2>/dev/null; then
                echo "  Has wget/curl: YES | Has sha256sum: YES (verification present)"
            else
                echo "  Has wget/curl: YES | Has sha256sum: NO (MISSING VERIFICATION - Critical)"
            fi
        fi
    done <<< "$DOCKERFILES"
    echo ""
else
    echo "  (no Dockerfiles found)"
    echo ""
fi

# ------------------------------------------------------------------ #
# Binary downloads in GHA workflow steps
# ------------------------------------------------------------------ #

section "Binary downloads (curl/wget) in GHA workflows"
rg -n 'curl\b|wget\b' "$WORKFLOWS" \
   --glob '*.yml' --glob '*.yaml' 2>/dev/null \
    && true || echo "  (none found)"
echo ""

section "SHA256 verification in GHA workflows"
rg -n 'sha256sum' "$WORKFLOWS" \
   --glob '*.yml' --glob '*.yaml' 2>/dev/null \
    && true || echo "  (none found)"
echo ""

# ------------------------------------------------------------------ #
# SUMMARY
# ------------------------------------------------------------------ #

echo "=== deps-checks.sh complete ==="
