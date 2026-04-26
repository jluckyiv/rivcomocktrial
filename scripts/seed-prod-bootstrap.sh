#!/bin/sh
# Push BOOTSTRAP_SUPERUSER_* secrets to a fly app from 1Password so
# the bootstrap_superuser.pb.js hook can create a baseline superuser
# on first boot. Idempotent and safe to re-run — the hook only creates
# the superuser if one with the matching email doesn't already exist.
#
# Usage:
#   scripts/seed-prod-bootstrap.sh                    # default: rivcomocktrial
#   scripts/seed-prod-bootstrap.sh rivcomocktrial-staging
#
# Requires: fly CLI authed for the target app, 1Password CLI authed.

set -e

APP="${1:-rivcomocktrial}"
ITEM="op://Private/rivcomocktrial"

if ! command -v fly >/dev/null 2>&1; then
    echo "fly CLI not found on PATH" >&2
    exit 1
fi

if ! command -v op >/dev/null 2>&1; then
    echo "1Password CLI (op) not found on PATH" >&2
    exit 1
fi

EMAIL=$(op read "${ITEM}/username")
PASSWORD=$(op read "${ITEM}/password")

if [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
    echo "Could not read username/password from 1Password (${ITEM})" >&2
    exit 1
fi

echo "Pushing BOOTSTRAP_SUPERUSER_* to fly app: ${APP}"
fly secrets set \
    BOOTSTRAP_SUPERUSER_EMAIL="$EMAIL" \
    BOOTSTRAP_SUPERUSER_PASSWORD="$PASSWORD" \
    --app "$APP"

echo "Done. The bootstrap_superuser hook will create the superuser on next deploy/restart if it doesn't already exist."
