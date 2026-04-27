#!/bin/sh
# Seed dedicated smoke-test accounts on the staging PocketBase instance.
# Idempotent — skips creation if the account already exists (HTTP 400 duplicate).
#
# Strategy: calls the staging PB admin API directly over HTTPS. No SSH tunnel
# needed because fly.io exposes the app publicly and the admin API is protected
# by an authenticated superuser token obtained first.
#
# Accounts created:
#   smoke-admin@rivcomocktrial.org  — superuser (can log into /admin)
#   smoke-coach@rivcomocktrial.org  — approved coach (can log into /team)
#
# Credentials are stored in 1Password:
#   op://Private/rivcomocktrial-staging-smoke
#     admin_email, admin_password, coach_email, coach_password
#
# The bootstrap superuser (op://Private/rivcomocktrial) is used to authenticate
# the admin API calls. That item must already exist in 1Password.
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
BOOTSTRAP_ITEM="op://Private/rivcomocktrial"
SMOKE_ITEM="op://Private/rivcomocktrial-staging-smoke"

for cmd in op curl jq; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "$cmd not found on PATH" >&2
        exit 1
    fi
done

echo "Reading credentials from 1Password..."

BOOT_EMAIL=$(op read "${BOOTSTRAP_ITEM}/username")
BOOT_PASSWORD=$(op read "${BOOTSTRAP_ITEM}/password")
SMOKE_ADMIN_EMAIL=$(op read "${SMOKE_ITEM}/admin_email")
SMOKE_ADMIN_PASSWORD=$(op read "${SMOKE_ITEM}/admin_password")
SMOKE_COACH_EMAIL=$(op read "${SMOKE_ITEM}/coach_email")
SMOKE_COACH_PASSWORD=$(op read "${SMOKE_ITEM}/coach_password")

if [ -z "$BOOT_EMAIL" ] || [ -z "$BOOT_PASSWORD" ]; then
    echo "Could not read bootstrap credentials from ${BOOTSTRAP_ITEM}" >&2
    exit 1
fi

if [ -z "$SMOKE_ADMIN_EMAIL" ] || [ -z "$SMOKE_ADMIN_PASSWORD" ] || \
   [ -z "$SMOKE_COACH_EMAIL" ] || [ -z "$SMOKE_COACH_PASSWORD" ]; then
    echo "Could not read smoke credentials from ${SMOKE_ITEM}" >&2
    echo "Create the item with fields: admin_email, admin_password, coach_email, coach_password" >&2
    exit 1
fi

echo "Authenticating as bootstrap superuser on staging..."

TOKEN=$(curl -sf -X POST "${STAGING_URL}/api/admins/auth-with-password" \
    -H "Content-Type: application/json" \
    -d "{\"identity\":\"${BOOT_EMAIL}\",\"password\":\"${BOOT_PASSWORD}\"}" \
    | jq -r '.token')

# Fall back to superusers collection (PB v0.23+)
if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    TOKEN=$(curl -sf -X POST "${STAGING_URL}/api/collections/_superusers/auth-with-password" \
        -H "Content-Type: application/json" \
        -d "{\"identity\":\"${BOOT_EMAIL}\",\"password\":\"${BOOT_PASSWORD}\"}" \
        | jq -r '.token')
fi

if [ -z "$TOKEN" ] || [ "$TOKEN" = "null" ]; then
    echo "Failed to authenticate as bootstrap superuser on ${STAGING_URL}" >&2
    exit 1
fi

echo "Seeding smoke-admin superuser..."

ADMIN_RESP=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "${STAGING_URL}/api/collections/_superusers/records" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${SMOKE_ADMIN_EMAIL}\",\"password\":\"${SMOKE_ADMIN_PASSWORD}\",\"passwordConfirm\":\"${SMOKE_ADMIN_PASSWORD}\"}")

if [ "$ADMIN_RESP" = "200" ] || [ "$ADMIN_RESP" = "201" ]; then
    echo "  Created ${SMOKE_ADMIN_EMAIL}"
elif [ "$ADMIN_RESP" = "400" ]; then
    echo "  ${SMOKE_ADMIN_EMAIL} already exists — skipping"
else
    echo "  Unexpected HTTP ${ADMIN_RESP} creating ${SMOKE_ADMIN_EMAIL}" >&2
    exit 1
fi

echo "Seeding smoke-coach user (status=approved)..."

COACH_RESP=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST "${STAGING_URL}/api/collections/users/records" \
    -H "Authorization: Bearer ${TOKEN}" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"${SMOKE_COACH_EMAIL}\",\"password\":\"${SMOKE_COACH_PASSWORD}\",\"passwordConfirm\":\"${SMOKE_COACH_PASSWORD}\",\"status\":\"approved\",\"role\":\"coach\",\"name\":\"Smoke Coach\"}")

if [ "$COACH_RESP" = "200" ] || [ "$COACH_RESP" = "201" ]; then
    echo "  Created ${SMOKE_COACH_EMAIL}"
elif [ "$COACH_RESP" = "400" ]; then
    echo "  ${SMOKE_COACH_EMAIL} already exists — skipping"
else
    echo "  Unexpected HTTP ${COACH_RESP} creating ${SMOKE_COACH_EMAIL}" >&2
    exit 1
fi

echo ""
echo "Done. Verify both accounts can log in at ${STAGING_URL}/login before running smoke tests."
echo "Next: cd web && npm run test:smoke:staging"
