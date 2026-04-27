#!/bin/sh
# Push BOOTSTRAP_SUPERUSER_* secrets to a fly app from local env vars so
# the bootstrap_superuser.pb.js hook can create a baseline superuser
# on first boot. Idempotent and safe to re-run — the hook only creates
# the superuser if one with the matching email doesn't already exist.
# Note: the hook does NOT update an existing superuser's password.
#
# Required env vars (loaded from .env.local via direnv):
#   For rivcomocktrial:          PROD_ADMIN_EMAIL, PROD_ADMIN_PASSWORD
#   For rivcomocktrial-staging:  STAGING_ADMIN_EMAIL, STAGING_ADMIN_PASSWORD
#
# Usage:
#   scripts/seed-prod-bootstrap.sh                    # default: rivcomocktrial
#   scripts/seed-prod-bootstrap.sh rivcomocktrial-staging
#
# Requires: fly CLI authed for the target app.

set -e

APP="${1:-rivcomocktrial}"

if ! command -v fly >/dev/null 2>&1; then
    echo "fly CLI not found on PATH" >&2
    exit 1
fi

case "$APP" in
    rivcomocktrial)
        EMAIL="$PROD_ADMIN_EMAIL"
        PASSWORD="$PROD_ADMIN_PASSWORD"
        VARS="PROD_ADMIN_EMAIL/PROD_ADMIN_PASSWORD"
        ;;
    rivcomocktrial-staging)
        EMAIL="$STAGING_ADMIN_EMAIL"
        PASSWORD="$STAGING_ADMIN_PASSWORD"
        VARS="STAGING_ADMIN_EMAIL/STAGING_ADMIN_PASSWORD"
        ;;
    *)
        echo "Unknown app: $APP" >&2
        echo "Usage: scripts/seed-prod-bootstrap.sh [rivcomocktrial|rivcomocktrial-staging]" >&2
        exit 1
        ;;
esac

if [ -z "$EMAIL" ] || [ -z "$PASSWORD" ]; then
    echo "Missing $VARS in environment." >&2
    echo "Populate .env.local from .env.local.example (direnv loads it automatically)." >&2
    exit 1
fi

echo "Pushing BOOTSTRAP_SUPERUSER_* to fly app: ${APP}"
fly secrets set \
    BOOTSTRAP_SUPERUSER_EMAIL="$EMAIL" \
    BOOTSTRAP_SUPERUSER_PASSWORD="$PASSWORD" \
    --app "$APP"

echo "Done. The bootstrap_superuser hook will create the superuser on next deploy/restart if it doesn't already exist."
