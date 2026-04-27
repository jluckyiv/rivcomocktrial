# Smoke Tests

Post-deploy read-only checks against live environments.
Run manually after a deploy — not wired into PR CI.

## Suites

| Suite | File | Staging | Production |
|---|---|---|---|
| Read-only | `web/e2e/deploy-smoke.e2e.ts` | yes | yes |
| Admin login | `web/e2e/deploy-smoke-admin.e2e.ts` | yes | yes |
| Coach login | `web/e2e/deploy-smoke-coach.e2e.ts` | yes | skipped (no coach on prod) |

All three files match `**/deploy-smoke*.e2e.ts` in `web/playwright.deploy.config.ts`.

## Credentials

Smoke scripts read credentials from environment variables loaded by direnv
from `.env.local`. See the [README](../README.md#credentials-envlocal) for
one-time setup.

### Production

Admin credentials:

- `PROD_ADMIN_EMAIL`
- `PROD_ADMIN_PASSWORD`

No coach account is seeded on production. The coach spec self-skips when
`SMOKE_COACH_EMAIL` is absent.

### Staging

Admin credentials (reuses the staging superuser):

- `STAGING_ADMIN_EMAIL`
- `STAGING_ADMIN_PASSWORD`

Coach credentials (separate, dedicated smoke account):

- `STAGING_COACH_EMAIL`
- `STAGING_COACH_PASSWORD`

The coach account must be seeded before running staging smokes — see below.
Do not add this account to migrations; it must never reach production.

## How to run

From the repo root:

```sh
# Staging — read-only + admin + coach
npm run -w web test:smoke:staging

# Production — read-only + admin (coach skipped automatically)
npm run -w web test:smoke:prod
```

The npm scripts translate the `STAGING_*` / `PROD_*` env vars into the
unprefixed `SMOKE_*` names that Playwright config consumes.

## How to seed staging smoke users

Run once (or re-run safely — the script is idempotent):

```sh
scripts/seed-staging-smoke-users.sh
```

The script:

1. Validates `STAGING_BASE_URL`, `STAGING_ADMIN_*`, `STAGING_COACH_*` are
   set in the environment.
2. Authenticates against the staging PB API to get an admin token.
3. Creates `STAGING_COACH_EMAIL` as an approved coach.
4. Skips creation if the account already exists (HTTP 400 disambiguated by
   a follow-up GET).

Prerequisites: `.env.local` populated; `curl` and `jq` on PATH.

After seeding, verify both accounts can log in at
`https://rivcomocktrial-staging.fly.dev/login` before running the smoke suite.

## Why coach smokes skip production

Seeding fake users on production would pollute the users collection and
risk exposing test data to real users. The coach smoke spec calls
`test.skip` when `SMOKE_COACH_EMAIL` is unset, so it shows as skipped
(not failed) in the prod run output.
