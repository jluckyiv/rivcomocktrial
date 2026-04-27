#!/bin/sh
# Seed dedicated smoke-test accounts on the staging PocketBase instance.
# Idempotent — skips creation if the account already exists (verified by a
# follow-up GET, since PocketBase returns HTTP 400 for any validation
# failure, not just duplicate-email).
#
# Strategy: calls the staging PB admin API directly over HTTPS. No SSH tunnel
# needed because fly.io exposes the app publicly and the admin API is protected
# by an authenticated superuser token obtained first.
#
# Account created:
#   smoke-coach@rivcomocktrial.org  — approved coach (can log into /team)
#
# The staging superuser (op://Private/rivcomocktrial-staging) authenticates
# the admin API calls and also serves as the admin smoke-test credential
# in test:smoke:staging. No dedicated smoke-admin account is needed.
#
# Coach credentials are stored in:
#   op://Private/rivcomocktrial-staging-smoke
#     coach_email, coach_password
#
# Usage:
#   scripts/seed-staging-smoke-users.sh
#
# Requires:
#   - op CLI authed (run `op signin` if needed)
#   - curl available on PATH
#   - jq available on PATH (for JSON parsing)

set -e

STAGING_URL="https://rivcomocktrial-staging.fly.dev"
STAGING_ITEM="op://Private/rivcomocktrial-staging"
SMOKE_ITEM="op://Private/rivcomocktrial-staging-smoke"

for cmd in op curl jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "$cmd not found on PATH" >&2
        exit 1
    fi
done

echo "Reading credentials from 1Password..."

BOOT_EMAIL=$(op read "${STAGING_ITEM}/username")
BOOT_PASSWORD=$(op read "${STAGING_ITEM}/password")
SMOKE_COACH_EMAIL=$(op read "${SMOKE_ITEM}/username")
SMOKE_COACH_PASSWORD=$(op read "${SMOKE_ITEM}/password")

if [ -z "$BOOT_EMAIL" ] || [ -z "$BOOT_PASSWORD" ]; then
    echo "Could not read staging superuser credentials from ${STAGING_ITEM}" >&2
    exit 1
fi

if [ -z "$SMOKE_COACH_EMAIL" ] || [ -z "$SMOKE_COACH_PASSWORD" ]; then
    echo "Could not read coach credentials from ${SMOKE_ITEM}" >&2
    echo "Item must have fields: username, password" >&2
    exit 1
fi

echo "Authenticating as staging superuser..."

TOKEN=$(curl -sf -X POST "${STAGING_URL}/api/collections/_superusers/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"${BOOT_EMAIL}\",\"password\":\"${BOOT_PASSWORD}\"}" \
    | jq -r '.token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "Failed to authenticate as staging superuser on ${STAGING_URL}" >&2
    exit 1
fi

echo "Seeding smoke-coach user (status=approved)..."

COACH_BODY=$(mktemp)
trap 'rm -f "$COACH_BODY"' EXIT

COACH_RESP=$(curl -s -o "$COACH_BODY" -w "%{http_code}" \
    -X POST "${STAGING_URL}/api/collections/users/records" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${SMOKE_COACH_EMAIL}\",\"password\":\"${SMOKE_COACH_PASSWORD}\",\"passwordConfirm\":\"${SMOKE_COACH_PASSWORD}\",\"status\":\"approved\",\"role\":\"coach\",\"name\":\"Smoke Coach\"}")

if [ "$COACH_RESP" = "200" ] || [ "$COACH_RESP" = "201" ]; then
    echo "  Created ${SMOKE_COACH_EMAIL}"
elif [ "$COACH_RESP" = "400" ]; then
    # 400 alone is ambiguous: PB returns it for any validation failure,
    # including hook-rejected creates. Confirm a real record exists before
    # treating this as "already exists."
    EXISTING=$(curl -sf -G "${STAGING_URL}/api/collections/users/records" \
        -H "Authorization: Bearer ${TOKEN}" \
        --data-urlencode "filter=email='${SMOKE_COACH_EMAIL}'" \
        | jq -r '.totalItems // 0')
    if [ "$EXISTING" -ge 1 ]; then
        echo "  ${SMOKE_COACH_EMAIL} already exists — skipping"
    else
        echo "  Failed to create ${SMOKE_COACH_EMAIL}: $(jq -c . "$COACH_BODY" 2>/dev/null || cat "$COACH_BODY")" >&2
        exit 1
    fi
else
    echo "  Unexpected HTTP ${COACH_RESP} creating ${SMOKE_COACH_EMAIL}: $(cat "$COACH_BODY")" >&2
    exit 1
fi

echo ""
echo "Done. Verify the coach account can log in at ${STAGING_URL}/login before running smoke tests."
echo "Next: cd web && npm run test:smoke:staging"
