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

### Production

Admin credentials come from the existing bootstrap superuser item in 1Password:

- `op://Private/rivcomocktrial/username`
- `op://Private/rivcomocktrial/password`

No coach account is seeded on production. The coach spec self-skips when
`SMOKE_COACH_EMAIL` is absent.

### Staging

Admin credentials reuse the existing staging superuser item:

- `op://Private/rivcomocktrial-staging/username`
- `op://Private/rivcomocktrial-staging/password`

Coach credentials are stored in a separate item:

- Item: `op://Private/rivcomocktrial-staging-smoke`
- Fields: `username`, `password`

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

Both commands read credentials from 1Password via `op read` and pass them as
environment variables. The `op` CLI must be authenticated before running.

## How to seed staging smoke users

Run once (or re-run safely — the script is idempotent):

```sh
scripts/seed-staging-smoke-users.sh
```

The script:

1. Reads the staging superuser credentials from
   `op://Private/rivcomocktrial-staging`.
2. Authenticates against the staging PB API to get an admin token.
3. Creates `smoke-coach@rivcomocktrial.org` as an approved coach.
4. Skips creation if the account already exists (HTTP 400).

Prerequisites: `op` CLI authed, `curl` and `jq` on PATH.

After seeding, verify both accounts can log in at
`https://rivcomocktrial-staging.fly.dev/login` before running the smoke suite.

## Why coach smokes skip production

Seeding fake users on production would pollute the users collection and
risk exposing test data to real users. The coach smoke spec calls
`test.skip` when `SMOKE_COACH_EMAIL` is unset, so it shows as skipped
(not failed) in the prod run output.
