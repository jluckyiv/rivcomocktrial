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
# The staging superuser authenticates the admin API calls and also serves as
# the admin smoke-test credential in test:smoke:staging. No dedicated
# smoke-admin account is needed.
#
# Required env vars (loaded from .env.local via direnv):
#   STAGING_BASE_URL          — e.g. https://rivcomocktrial-staging.fly.dev
#   STAGING_ADMIN_EMAIL       — staging superuser email
#   STAGING_ADMIN_PASSWORD    — staging superuser password
#   STAGING_COACH_EMAIL       — smoke coach email
#   STAGING_COACH_PASSWORD    — smoke coach password
#
# Usage:
#   scripts/seed-staging-smoke-users.sh
#
# Requires: curl, jq on PATH.

set -e

for cmd in curl jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "$cmd not found on PATH" >&2
        exit 1
    fi
done

missing=
for var in STAGING_BASE_URL STAGING_ADMIN_EMAIL STAGING_ADMIN_PASSWORD STAGING_COACH_EMAIL STAGING_COACH_PASSWORD; do
    eval "val=\${$var}"
    if [ -z "$val" ]; then
        missing="$missing $var"
    fi
done
if [ -n "$missing" ]; then
    echo "Missing required env vars:$missing" >&2
    echo "Populate .env.local from .env.local.example (direnv loads it automatically)." >&2
    exit 1
fi

echo "Authenticating as staging superuser..."

TOKEN=$(curl -sf -X POST "${STAGING_BASE_URL}/api/collections/_superusers/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"${STAGING_ADMIN_EMAIL}\",\"password\":\"${STAGING_ADMIN_PASSWORD}\"}" \
    | jq -r '.token')

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "Failed to authenticate as staging superuser on ${STAGING_BASE_URL}" >&2
    exit 1
fi

echo "Seeding smoke-coach user (status=approved)..."

COACH_BODY=$(mktemp)
trap 'rm -f "$COACH_BODY"' EXIT

COACH_RESP=$(curl -s -o "$COACH_BODY" -w "%{http_code}" \
    -X POST "${STAGING_BASE_URL}/api/collections/users/records" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${STAGING_COACH_EMAIL}\",\"password\":\"${STAGING_COACH_PASSWORD}\",\"passwordConfirm\":\"${STAGING_COACH_PASSWORD}\",\"status\":\"approved\",\"role\":\"coach\",\"name\":\"Smoke Coach\"}")

if [ "$COACH_RESP" = "200" ] || [ "$COACH_RESP" = "201" ]; then
    echo "  Created ${STAGING_COACH_EMAIL}"
elif [ "$COACH_RESP" = "400" ]; then
    # 400 alone is ambiguous: PB returns it for any validation failure,
    # including hook-rejected creates. Confirm a real record exists before
    # treating this as "already exists."
    EXISTING=$(curl -sf -G "${STAGING_BASE_URL}/api/collections/users/records" \
        -H "Authorization: Bearer ${TOKEN}" \
        --data-urlencode "filter=email='${STAGING_COACH_EMAIL}'" \
        | jq -r '.totalItems // 0')
    if [ "$EXISTING" -ge 1 ]; then
        echo "  ${STAGING_COACH_EMAIL} already exists — skipping"
    else
        echo "  Failed to create ${STAGING_COACH_EMAIL}: $(jq -c . "$COACH_BODY" 2>/dev/null || cat "$COACH_BODY")" >&2
        exit 1
    fi
else
    echo "  Unexpected HTTP ${COACH_RESP} creating ${STAGING_COACH_EMAIL}: $(cat "$COACH_BODY")" >&2
    exit 1
fi

echo ""
echo "Done. Verify the coach account can log in at ${STAGING_BASE_URL}/login before running smoke tests."
echo "Next: cd web && npm run test:smoke:staging"
