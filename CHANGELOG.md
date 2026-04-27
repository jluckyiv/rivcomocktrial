# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versions follow [Semantic Versioning](https://semver.org/).

## v0.10.18 — docs: add supersession notes to Elm-era ADRs

Adds `**Superseded by ADR-014.**` to ADR-002, ADR-004, ADR-005,
ADR-006, ADR-008, ADR-010, and ADR-011 — the seven Elm-era decisions
flagged as Critical by the `/audit-docs` smoke test.

### Changed

- `docs/decisions.md` — supersession note added immediately before the
  `**Date:**` line of each Elm-era ADR, matching the style of ADR-012
  and ADR-013

---

## v0.10.17 — feat: add /audit-docs skill

Adds the `/audit-docs` Claude Code skill — a documentation drift audit
that verifies every load-bearing claim in `CLAUDE.md`, `README.md`,
`docs/decisions.md` (ADRs), and other `docs/*.md` files matches code
reality.

### Added

- `.claude/skills/audit-docs/SKILL.md` — skill definition with steps,
  rubric, severity rules, and out-of-scope guard
- `.claude/skills/audit-docs/docs-claims.sh` — bash helper that
  extracts file path references, shell command references, port
  numbers, stack component names, hook file names, and ADR supersession
  state; cross-checks each against the filesystem and config files

### Smoke test result

Script ran clean. Opus agent found:

- **Critical:** ADR-002 (Bulma) contradicts current Tailwind v4 stack
  with no supersession note. Also flagged ADR-004, ADR-005, ADR-006,
  ADR-008, ADR-010, ADR-011 as Elm-era decisions with no supersession.
- **Praise:** ADR-013/014 supersession in place; port numbers correct
  across all files; all script references valid; all hook file
  references valid.

---

## v0.10.16 — feat: add /audit-schema skill

Adds the `/audit-schema` Claude Code skill — a PocketBase schema
lockdown audit that verifies every collection in `pocketbase-types.ts`
has a spec, and every spec assertion matches the live rule string on
the test PB.

### Added

- `.claude/skills/audit-schema/SKILL.md` — skill definition with
  steps, rubric, severity rules, and out-of-scope guard
- `.claude/skills/audit-schema/schema-completeness.sh` — bash helper
  that enumerates collections, fetches live rules from the test PB,
  greps spec assertions, and reports coverage gaps

### Smoke test result

All 24 user collections covered. 120/120 rule slots asserted and
matching live. 0 mismatches. 0 unasserted slots. 0 skipped tests.
Deliberate wrong assertion confirmed Critical finding; reverted clean.

---

## v0.10.15 — docs: add implementation brief for new audit skills (#276)

Adds `docs/audit-skills-brief.md` — a self-contained build plan for 5
new sibling audit skills (`/audit-schema`, `/audit-docs`,
`/audit-domain`, `/audit-a11y`, `/audit-deps`) so a fresh Claude
session can implement them one-per-worktree without re-deriving the
design.

The brief locks in the project's "Happy Path Svelte Development"
stance: keep FP values (immutability, exhaustive matching,
parse-at-boundary, Result-shaped returns, no-booleans-for-state) where
they fit Svelte/TS idiom; drop them where they fight the grain. The
`$state` boundary is called out explicitly — domain modules in `lib/`
stay pure and immutable; component-level reactive state in `.svelte`
files is mutation-by-design and must not be flagged as an
anti-pattern.

### Added

- `docs/audit-skills-brief.md` — implementation brief for the 5 new
  audit skills, in build order: schema → docs → domain → a11y → deps,
  plus a follow-up section for updating the existing `/audit` skill
  with Svelte 5 deltas.

## v0.10.14 — docs: README Operations runbook and ADR-015 realtime clarification (#213)

Closes #213.

### Changed

- `README.md` — add `## Operations` section with day-2 runbook: tail
  logs, SSH console, rollback (with forward-only migration caveat),
  manual volume snapshot, wake staging machine, add a second superuser,
  and a placeholder for the uptime monitor URL (#212).
- `docs/decisions.md` — fix ADR-015 Rationale: replace the misleading
  "PB SDK works as-is for realtime" claim with an accurate statement
  that single-origin makes realtime viable, and that the browser-side
  auth mechanism (SSR-thread vs token endpoint) is a separate
  implementation decision deferred to when realtime SSE is wired up.

## v0.10.13 — docs: archive completed audit and prune vestigial planning docs (#272)

Audit work shipped across v0.9.12–v0.10.1; the audit doc itself is
closeout history now. Moves `docs/audit-2026-04-26.md` and
`docs/mvp-domain-gaps.md` into `docs/archive/`, and deletes the
orphaned `docs/slices/01-admin-setup-schools.md` (an identical copy
already lives at `docs/archive/slices/`; ADR-014 archived
`docs/slices/` but this file got left behind).

### Changed

- `docs/archive/audit-2026-04-26.md` (moved from `docs/`)
- `docs/archive/mvp-domain-gaps.md` (moved from `docs/`)
- `CHANGELOG.md` — v0.10.0 entry's path reference updated to point at
  the archived location

### Removed

- `docs/slices/01-admin-setup-schools.md` and the now-empty
  `docs/slices/` directory

## v0.10.12 — fix: 301 redirect www.rivcomocktrial.org to apex (#271)

Closes #211. Adds a `@www` host matcher in Caddyfile that redirects
`www.rivcomocktrial.org` → `https://rivcomocktrial.org` before any
other routing fires. Resolves the pending www decision (option B).

### Fixed

- `backend/Caddyfile` — `@www` host matcher + 301 redirect to apex

## v0.10.11 — fix: add PROTOCOL_HEADER and HOST_HEADER to fly configs (#270)

Closes #209. SvelteKit adapter-node requires these env vars to trust
`x-forwarded-proto` and `x-forwarded-host` from the fly proxy. Without
them, CSRF checks on form action POSTs silently return 403.

### Fixed

- `fly.toml` — add `PROTOCOL_HEADER` and `HOST_HEADER`
- `fly.staging.toml` — add `PROTOCOL_HEADER` and `HOST_HEADER`

## v0.10.10 — fix: Caddyfile cold-start 502 and missing security headers (#269)

Closes #206, #214.

### Fixed

- `backend/Caddyfile` — add `lb_try_duration 5s` / `lb_try_interval
  250ms` to the SvelteKit reverse proxy so Caddy retries during Node
  startup instead of returning 502 on cold machine wake.
- `backend/Caddyfile` — add site-level `header` block with HSTS
  (`max-age=31536000; includeSubDomains`), `X-Content-Type-Options`,
  `X-Frame-Options`, and `Referrer-Policy`. These were specified in
  #173 but never added in PR #180.

## v0.10.9 — fix: seed-staging-smoke-users.sh sets wrong fields for the coach record (#256)

Closes #256. The staging smoke-seed script POSTed a coach record
with `name: "Smoke Coach"` and no `team_name` / `school`. Before
#266 that combination would crash the registration post-commit hook
trying to auto-create a team without those fields and silently
roll back the coach record. #266 (v0.10.7) made the hook bypass
team creation entirely when superuser-authenticated creates omit
team intent, so the script now seeds successfully as-is.

### Fixed

- `scripts/seed-staging-smoke-users.sh` — drop the unused
  `name: "Smoke Coach"` field from the coach POST body. The smoke
  spec (`deploy-smoke-coach.e2e.ts`) never asserts on `name`, and
  removing it makes the script's intent (bare admin seed, no team)
  match the post-#266 hook contract self-documenting. Header
  comment updated to explain why the smoke coach has no team and
  how `/team` and the smoke spec handle that.

## v0.10.8 — fix: contact_route.pb.js fallback query missing try/catch (#202)

Closes #202. The fallback `findRecordsByFilter` call (used when no
superuser is flagged `is_primary_contact`) had no error handling.
A database error would propagate uncaught to the public `/api/contact`
endpoint and return a 500 with a stack trace.

Consolidates both queries into a single outer try/catch. Uses `??` to
resolve the primary-or-fallback record in one expression, eliminating
the mutable `let record` variable. A DB failure now returns 503
(service unavailable); an empty superusers table returns 404.

### Changed

- `backend/pb_hooks/contact_route.pb.js` — wrap entire handler body
  in try/catch; replace mutable `let record` + two-block structure
  with a single `const record` using `??` for the fallback lookup.

## v0.10.7 — fix: registration.pb.js blocks admin API creates of coach users (#255)

## v0.10.5 — fix: widen year input on Tournaments admin page (#258)

Closes #258. The year input in the "Add tournament" row was too narrow
— browser number-spinner arrows clipped the fourth digit of the
four-digit year. Adding `w-28` (7 rem) gives the input enough room to
display the full value alongside the spinner controls.

### Fixed

- `web/src/routes/admin/tournaments/+page.svelte` — add `w-28` to the
  `year` input so the full four-digit year is never clipped.

## v0.10.4 — refactor: stop calling op at runtime; load creds into env vars once (#262)

Closes #261. Subprocess sandboxes (Claude Code's Bash tool, CI runners,
non-interactive shells) can't reach the 1Password desktop daemon, so
every embedded `$(op read …)` was a flaky runtime dependency that
surfaced as `RequestDelegatedSession: cannot setup session`. Replaces
runtime `op` calls with a static `.env.local` file — populated once,
auto-loaded by direnv on every `cd` into the repo.

### Added

- `.envrc` — `dotenv_if_exists .env.local` for direnv.
- `.env.local.example` — typed credential schema (`PB_DEV_*`,
  `STAGING_*`, `PROD_*`) with comments pointing to the 1P items.
- `scripts/load-1p-creds.sh` — the only place `op` is invoked.
  Run once (or after rotating creds) and pipe to `.env.local`.

### Changed

- `package.json`, `web/package.json` — smoke + seed scripts read env
  vars instead of shelling out to `op`. Translate prefixed names
  (`STAGING_*` / `PROD_*`) into the `SMOKE_*` names Playwright config
  expects.
- `scripts/seed-prod-bootstrap.sh` — picks `PROD_*` or `STAGING_*`
  based on the app argument. Incidentally fixes a pre-existing bug
  where `rivcomocktrial-staging` silently received production
  credentials.
- `scripts/seed-staging-smoke-users.sh` — validates required env vars
  at the top and fails loud if any are missing.
- `README.md`, `docs/smoke-tests.md` — document the `.env.local` flow
  and direnv setup.

### Removed

- `npm run pb:credentials` — cache-file pattern superseded by
  `.env.local`.

## v0.10.3 — feat: add deploy:staging and deploy:prod npm scripts (#259)

Wraps `gh workflow run deploy.yml -f target=<env>` as npm scripts so
deploys can be triggered from the terminal without navigating the
GitHub Actions UI. Documents both commands in the README.

### Added

- `npm run deploy:prod` — triggers the production `workflow_dispatch`
- `npm run deploy:staging` — triggers a manual staging dispatch

## v0.10.2 — fix: seed-staging-smoke-users.sh disambiguates HTTP 400 (#260)

Closes #254 (audit follow-up). Previously the seed script silently
swallowed any HTTP 400 from the user-create POST as "coach already
exists — skipping" and exited 0. Real validation failures (e.g. the
registration hook rejecting the create) were hidden — the script
reported success even though the staging users collection stayed
empty.

### Changed

- `scripts/seed-staging-smoke-users.sh` — on HTTP 400, do a follow-up
  GET filtered by email to confirm the record actually exists. Only
  then skip. Otherwise print the real PB error body and exit 1.
  Updated the header comment to reflect the new check.

## v0.10.1 — feat: pre-deploy pb_data snapshot in CI (#233)

Closes the last open audit task. Every staging and production deploy
now snapshots the `pb_data` volume before `flyctl deploy` runs, so a
bad deploy can be rolled back without losing more than a few seconds
of writes.

### Added

- `.github/workflows/deploy.yml` — "Snapshot pb_data before deploy"
  step in the staging and production jobs. Resolves the volume ID,
  creates a snapshot, diffs the snapshot list to find the new ID, and
  writes app + volume + snapshot + commit SHA to the GitHub Actions
  step summary. Step failure aborts the job before `flyctl deploy`.

### Changed

- `docs/backups.md` — replaced the "once Task 10 is implemented"
  placeholder with a description of the actual deploy step and how to
  use the step summary for rollback.

## v0.10.0 — milestone: audit complete (docs/archive/audit-2026-04-26.md)

All 14 tasks from the April 2026 codebase audit are shipped.

## v0.9.19 — chore: remove unused vitest client project (task 14) (#237)

### Removed

- `web/vite.config.ts` — removed browser-mode `client` vitest project and
  `@vitest/browser-playwright` import; only the `server` project remains.
- `@vitest/browser-playwright` and `vitest-browser-svelte` from
  `web/package.json` devDependencies.

### Changed

- `web/eslint.config.js` — added `docs/**` to ignores so example files
  are not linted.

### Added

- `web/docs/vitest-examples/` — example files moved here (history
  preserved via `git mv`); includes README explaining they are not
  collected by any test or CI job.

## v0.9.18 — chore: ESLint guard blocking test-helper imports in production
code (#236)

### Added

- `web/eslint.config.js` — `no-restricted-imports` rule that blocks
  production `.ts`, `.js`, and `.svelte` files from importing anything
  under `**/test-helpers/**` or `$lib/test-helpers/**`, and from
  importing any `**/*.spec` file. Spec files and files inside
  `test-helpers/` themselves are excluded from the rule, so the 10
  existing hook and schema spec imports remain clean.

## v0.9.17 — test: expand deploy smoke tests with admin + coach login (#219)

### Added

- `web/e2e/deploy-smoke-admin.e2e.ts` — 3 admin login smoke tests (login
  redirects to `/admin`, logout redirects to `/login`, protected route
  guard). Runs on both staging and production. Self-skips when
  `SMOKE_ADMIN_EMAIL` or `SMOKE_ADMIN_PASSWORD` is absent.
- `web/e2e/deploy-smoke-coach.e2e.ts` — 2 coach login smoke tests (login
  redirects to `/team`, logout redirects to `/login`). Staging only;
  self-skips on production (no coach credentials in env).
- `scripts/seed-staging-smoke-users.sh` — idempotent one-shot script that
  seeds `smoke-admin@rivcomocktrial.org` and `smoke-coach@rivcomocktrial.org`
  on the staging PB instance via the admin API. Reads credentials from
  `op://Private/rivcomocktrial-staging-smoke`.
- `docs/smoke-tests.md` — documents which suite runs in which env,
  credential sources, how to run locally, and how to re-seed staging
  smoke users.

### Changed

- `web/playwright.deploy.config.ts` — broadened `testMatch` from
  `**/deploy-smoke.e2e.ts` to `**/deploy-smoke*.e2e.ts` so all three
  smoke files are included automatically.
- `web/package.json` — `test:smoke:staging` and `test:smoke:prod` now
  inject credentials via `op read` from 1Password. Staging injects all
  four smoke credentials; production injects admin credentials only
  (coach spec self-skips).

## v0.9.16 — chore: remove dead district/school seed scripts (#218)

### Removed

- `backend/pb_seed/seed_districts.js`, `seed_schools.js`,
  `districts.json`, `schools.json` — superseded by migrations
  `1800000004_seed_districts.js` and `1800000005_seed_schools.js`.
- `pb:seed-districts` and `pb:seed-schools` npm scripts.

## v0.9.15 — feat: schema rule tests for all PocketBase collections

### Added

- `web/src/lib/schema/users.spec.ts` — 5 rule assertions for the users
  collection (public create, admin-only list/view/update/delete).
- `web/src/lib/schema/schools-districts.spec.ts` — 10 rule assertions
  covering schools (public read, admin write) and districts (public
  read, admin write).
- `web/src/lib/schema/tournaments.spec.ts` — 30 rule assertions
  covering tournaments, rounds, trials, students, case_characters
  (all public read, admin write) and courtrooms (admin-only).
- `web/src/lib/schema/ballots.spec.ts` — 30 rule assertions covering
  ballot_submissions, ballot_scores, presider_ballots (public create,
  admin-only read/update/delete), ballot_corrections and judges
  (admin-only), and scorer_tokens (token-query-param-gated read, admin
  write). Total schema test count: 121 (up from 46).

## v0.9.14 — feat: hook integration tests for auth, eligibility, withdrawal, ballot (#217)

### Added

- `web/src/lib/hooks/auth.spec.ts` — 3 cases for `auth_guard.pb.js`:
  approved user passes, pending user blocked (403), rejected user blocked
  (403). Users created without `role: 'coach'` so the registration hook
  does not fire, keeping this spec fully isolated.
- `web/src/lib/hooks/eligibility.spec.ts` — 3 cases for
  `eligibility.pb.js`: approve "add" request creates an active
  `eligibility_list_entries` row; approve "remove" request flips the
  matching entry to "removed"; update to non-approved status leaves entries
  unchanged.
- `web/src/lib/hooks/withdrawal.spec.ts` — 2 cases for
  `withdrawal.pb.js`: approve withdrawal request sets `team.status` to
  "withdrawn"; non-approved update leaves team status unchanged.
- `web/src/lib/hooks/ballot.spec.ts` — 5 cases for
  `ballot_guard.pb.js`: valid scorer token creates submission and marks
  token used; scorer token submitted to presider endpoint returns 400;
  scorer token submitted twice returns 400; valid presider token creates
  ballot and marks token used; presider token submitted to scorer endpoint
  returns 400.

## v0.9.13 — docs: pb data backup policy via Fly volume snapshots (#230)

### Added

- `docs/backups.md` — backup policy document: what Fly volume snapshots
  cover, what is not covered (hooks/migrations are in git; secrets in
  fly secrets), and a step-by-step recovery procedure using
  `fly volumes create --snapshot-id`.
- `CLAUDE.md` — new `## Operations` section pointing to
  `docs/backups.md`.

### Changed

- Fly volume snapshot retention set to 14 days on both
  `rivcomocktrial` (prod) and `rivcomocktrial-staging`.
- Anchor snapshot `vs_RpqkkjoM1Ybc5x9oaoY` taken on prod volume at
  time of this release.
- Recovery procedure rehearsed end-to-end on staging; `data.db`
  confirmed present (416 KB) in forked volume.

## v0.9.12 — fix: vitest preflight gate for unreachable PocketBase (#220)

### Added

- `web/src/lib/test-helpers/preflight.ts` — `beforeAll` setup that pings
  `${PB_URL}/api/health` with a 2 s timeout and throws a clear error naming
  PocketBase and the fix command (`npm run pb:test:up`) when the container is
  not running.
- `web/vite.config.ts` — `setupFiles` wired into the **server** project only;
  the client project does not run the preflight.

## Unreleased

### Added

- Issue #219 — proposal for tiered deploy smoke tests (comprehensive
  staging suite, minimal prod-safe suite that uses the bootstrap admin
  to view pre-seeded districts/schools, no fake data on prod).
- `"engines": { "node": ">=20" }` added to root `package.json` and
  `web/package.json` to declare the Node floor in use.

### Changed

- All local Playwright e2e tests run against the isolated test
  PocketBase (port 28090), not the dev container. Root
  `playwright.config.ts` builds and previews SvelteKit on port 4173
  with `PB_INTERNAL_URL` pointed at the test PB so SSR talks to the
  test container. `npm run e2e` now auto-starts the test PB, sources
  `.env.test`, and runs all e2e specs in one pass.
- Consolidated e2e tests into `tests/e2e/` at the repo root. Moved
  `web/e2e/registration-flow.e2e.ts` → `tests/e2e/registration-flow.spec.ts`
  and reworked it to seed its own tournament, track records for
  dependency-ordered cleanup, fail loudly on missing env (instead of
  silently self-skipping), and use `PB_ADMIN_*` env vars for
  consistency with the hook + schema layer.
- `tests/e2e/registrations.spec.ts`: same dependency-ordered cleanup
  pattern as the hook tests; seeds its own tournament + school per run.
- `tests/e2e/helpers/pb.ts`: requires `PB_URL`, `PB_ADMIN_EMAIL`,
  `PB_ADMIN_PASSWORD` from env at module load — no hardcoded fallbacks
  to the dev container.
- `web/playwright.deploy.config.ts`: `SMOKE_BASE_URL` is now required;
  the staging default was removed so the bare playwright invocation
  fails loudly. Use the explicit npm scripts.
- `web/package.json`: `test:smoke` split into `test:smoke:staging`
  (staging URL) and `test:smoke:prod` (production URL). `test:e2e`
  removed — local e2e lives at the repo root now.
- `CLAUDE.md` + `README.md`: testing tables updated for the new layout
  and target containers.

### Fixed

- `web/src/lib/hooks/registration.spec.ts` collision-without-intent
  describe fetched the team list twice — once to get the ID, once to
  read `.name`. Now fetches once with a widened type cast (#222
  partial, see issue).
- `web/src/lib/schema/coach-access.spec.ts:8-11`: replaced stale
  pre-conditions block referencing `pb:seed-admins` and
  `pb:credentials`. Both helpers now point at `.env.test` (#223
  partial, see issue).
- `web/src/routes/team/+page.server.ts`: filter was `coach = "..."`
  (singular, equality) but the schema is `coaches` (multi-relation,
  per migration `1800000009_multi_coach_teams.js`). The page returned
  500 when an approved coach hit `/team`. Caught by the registration
  flow e2e once it stopped self-skipping on missing env.

### Removed

- `web/playwright.config.ts` and `web/e2e/registration-flow.e2e.ts`:
  duplicate config + relocated test.
- `pb:seed-test-admin` script: no longer needed; the dev container
  doesn't host test admin credentials, and the test container
  auto-seeds its own.

## v0.9.11 — test: migrate hook tests to Vitest server layer (#216)

### Added

- `web/src/lib/hooks/registration.spec.ts`: Vitest server-project hook
  integration tests for all four `registration.pb.js` callbacks — new-team
  path, join-existing path, collision-without-intent (400 + `existingTeamId`),
  sole-coach delete blocked (400), two-coach delete allowed, status-sync
  approve (team → active), status-sync reject (team → rejected).
- `web/src/lib/test-helpers/pb-admin.ts`: `pbCreate`, `pbPatch`, `pbDelete`,
  `pbList` helpers that throw `PbError` (`.status`, `.data`) on non-2xx.
- `test:hooks` npm script in `web/package.json` and root `package.json`.
- `docker-compose.test.yml`: isolated test PocketBase container on host
  port 28090 with a dedicated named volume (`pb_test_data`). Auto-seeds
  the test superuser via the compose `command:` (no production hook
  borrowed). Hook + schema tests now run against this container,
  eliminating the prior shared-DB pollution.
- `.env.test`: single source of truth for `PB_URL`, `PB_ADMIN_EMAIL`,
  `PB_ADMIN_PASSWORD`. Sourced by docker compose AND npm scripts.
- Root `package.json`: `pb:test:up`, `pb:test:down`, `pb:test:reset`
  scripts. `test:hooks` and `test:schema` now auto-start the test PB.

### Changed

- `tests/e2e/helpers/pb.ts`: all helpers now throw on non-2xx so Playwright
  test failures surface at the bad API call, not two assertions later.
- `CLAUDE.md`: documents the three-layer testing model (schema, hook
  integration, UI e2e), the two-container split (dev 8090 / test 28090),
  and the dependency-ordered cleanup contract for hook tests.
- `web/src/lib/hooks/registration.spec.ts`: cleanup walks tracked records
  by collection class in dependency order
  (`join_requests → teams → users → tournaments`) instead of LIFO. Throws
  on any failure. Fixes silent one-orphan-per-run leak from the two-coach
  delete test.
- `web/src/lib/test-helpers/pb-admin.ts`: requires `PB_URL`,
  `PB_ADMIN_EMAIL`, `PB_ADMIN_PASSWORD` from env at module load, throws
  if missing. No hardcoded fallbacks.

### Removed

- `tests/e2e/multi-coach.spec.ts`: fully superseded by `registration.spec.ts`
  in the hook integration layer.
- `web/src/lib/test-helpers/test-admin.ts`: hardcoded credentials replaced
  by `.env.test` as the single source of truth.

## v0.9.10 — feat: multi-coach teams, join requests, sole-coach guard, schema tests (#198)

### Added

- Migration 1800000009: converts `teams.coach` (single relation) to
  `teams.coaches` (multi-relation, unlimited), drops `co_coaches` collection,
  adds unique index on `(name, school, tournament)`, updates access rules
  across 7 dependent collections to use the `~` (contains) operator. Closes #169 (backend).
- Migration 1800000010: `join_requests` collection with pending/approved/rejected
  status and coach-or-self list/view rules.
- `registration.pb.js`: collision detection returns `existingTeamId` in error
  data; post-create branches on `join_team_id` to create join request vs. new
  team; join-request save failure rolls back the newly-created user; sole-coach
  deletion guard blocks deleting a coach who is the only coach on a pending or
  active team.
- `_constants.js`: `JOIN_REQUEST_STATUS` constant.
- `web/src/lib/schema/coach-access.spec.ts`: Vitest server-project schema
  assertions for all 9 coach-gated collections (exact rule strings) plus
  `co_coaches`-is-gone check (46 assertions total).
- `web/src/lib/test-helpers/pb-admin.ts`: admin API helper for schema tests.
- `test:schema` npm script in `web/package.json` and root `package.json`.

### Fixed

- `registration.pb.js` post-create hook: `e.requestInfo` does not exist on
  `RecordEvent` (only on `RecordRequestEvent`), so reading `join_team_id` from
  it always returned undefined — the join-existing branch was dead code. Fixed
  by stashing join intent on the record in the pre-commit hook via
  `e.record.set("_join_team_id", id)` and reading it back in the post-commit
  hook via `user.get("_join_team_id")`. Also adds user rollback to the new-team
  path to mirror the existing rollback on the join-request path.
- `eligibility_change_requests` and `withdrawal_requests`: migration 1800000009
  now correctly leaves `updateRule` and `deleteRule` as null (admin-only) rather
  than overwriting them to coach-gated.
- `pocketbase-types.ts`: `TeamsRecord.coaches` corrected to `RecordIdString[]`
  (pocketbase-typegen 1.5.0 generates singular for multi-relation fields).
- Admin teams view: `+page.server.ts` and `+page.svelte` updated to expand and
  render `coaches` (multi) rather than `coach` (single).


## v0.9.9 — ci: migration smoke test before deploy (#192)

### Added

- `deploy.yml`: `migrate-check` job downloads the same PocketBase version as
  the Dockerfile, applies all migrations to a fresh empty data dir, and
  verifies `/api/health` returns 200. `staging` and `production` jobs now
  `needs: migrate-check`, so a migration failure blocks the deploy. Closes
  #177.

## v0.9.8 — fix: hook panics, ballot const scope, e2e suite for SvelteKit (#191)

### Fixed

- `smtp_config.pb.js` re-enabled: use `onBootstrap` with `e.next()` first;
  drop `$app.save(settings)` which caused nil pointer dereference in
  PocketBase v0.36 (`core/db.go:314`). Closes #146.
- `ballot_guard.pb.js`: extract `validateScorerToken` and `markTokenUsed`
  to `_ballot_helpers.js`; `require()` inside each callback so helpers are
  in scope under PB v0.36 fresh-VM-per-callback model. Closes #147.

### Changed

- Removed backend freeze guard (`.claude/hooks/freeze-bash-guard.sh`):
  safeguard was for the Elm→SvelteKit transition; no longer needed.
  Migration `Edit`/`MultiEdit` deny rules remain (migrations are append-only).
- `playwright.config.ts`: target SvelteKit dev server (port 5173) via
  `webServer`; drop stale Elm/`pb_public` approach.
- `tests/e2e/helpers/auth.ts`: fix URL (`/login`), input selectors
  (`name` attrs), button text (`Sign in`), and wait (`waitForURL`).
- `tests/e2e/dashboard.spec.ts`: rewrite for SvelteKit nav-card dashboard.
- `tests/e2e/registrations.spec.ts`: fix school creation (district relation
  ID), remove DaisyUI selectors and loading-spinner waits, drop 2nd-team
  badge tests (not yet ported).
- Deleted `tests/e2e/pairings.spec.ts`: `/admin/pairings` not yet built
  in SvelteKit.

### Added

- `tests/e2e/auth.spec.ts`: login redirect, logout redirect, protected
  route blocked after logout. Closes #159.

## v0.9.7 — feat: logout flow and responsive nav bar (#188)

### Added

- `web/src/lib/components/NavBar.svelte` — shared nav bar component
  with desktop inline links and mobile hamburger menu (Tailwind `md:`
  breakpoints; no Sheet dependency needed).
- `web/src/routes/logout/+page.server.ts` — POST action clears
  PocketBase `authStore` and redirects to `/login`. The existing
  `hooks.server.ts` cookie export writes the cleared cookie on every
  response, so no extra cookie logic is required.
- Both `/admin` and `/team` layouts now use `NavBar`; logout is
  available to all authenticated users.

### Changed

- `web/src/routes/admin/+layout.server.ts` — returns `userEmail` so
  the nav bar can show the logged-in user.
- First Prettier run across all `web/` source files; pre-existing
  ESLint issues fixed (`svelte/no-navigation-without-resolve` disabled
  — project does not use SvelteKit base path; `pocketbase-types.ts`
  excluded from lint as a generated file; `_`-prefixed unused vars
  allowed).

## v0.9.6 — fix(skills/pr-review): hard sentinel between orchestration and brief

### Changed

- `.claude/skills/pr-review/SKILL.md` rewritten with a strong
  separator between the orchestration block (calling agent's only
  job: spawn a subagent) and the subagent brief (everything the
  reviewer reads). The previous structure put orchestration first
  but left the brief flowing after it, which let the calling agent
  treat the playbook as its own instructions and review in the
  foreground — observed on PR 181 and the cumulative #173 review.
  The new structure adds a "READ THIS FIRST. DO NOT EXECUTE THE
  PLAYBOOK YOURSELF" callout, an explicit "you do not run
  `gh pr view`" instruction, and an HTML-comment sentinel
  (`SUBAGENT BRIEF — everything below this marker is for the
  subagent`) that's hard to miss visually.

## v0.9.5 — Auto-bootstrap baseline superuser on fresh deploy (#184)

### Added

- `backend/pb_hooks/bootstrap_superuser.pb.js` — `onBootstrap`
  hook that creates one baseline superuser if
  `BOOTSTRAP_SUPERUSER_EMAIL` and `BOOTSTRAP_SUPERUSER_PASSWORD`
  are set. Idempotent: skips if a superuser with that email already
  exists. No-op when the env vars are unset (local dev unchanged).
- `scripts/seed-prod-bootstrap.sh` — local helper that reads
  `op://Private/rivcomocktrial/{username,password}` from 1Password
  and pushes them to fly as secrets via `fly secrets set`. One
  argument: target app name (defaults to `rivcomocktrial`).

### Changed

- README "Creating a superuser on a deployed env" replaced with a
  "Bootstrapping a superuser on a fresh deploy" section that walks
  through the helper-driven flow and keeps the SSH path as a
  fallback.
- `.claude/settings.json`: dropped four stale freeze deny rules
  (`Edit/Write/MultiEdit/NotebookEdit(backend/pb_hooks/**)` and
  `Write/NotebookEdit(backend/pb_migrations/**)`) per ADR-014, which
  retired the persistence freeze. Kept
  `Edit/MultiEdit(backend/pb_migrations/**)` so AI can't rewrite
  shipped migrations — append-only convention preserved.

### Removed

- `lefthook.yml` — both pre-commit checks were enforcing retired
  rules (`persistence-freeze` per ADR-013, `domain-pair` against
  `frontend/src/*.elm` files that no longer exist). Run
  `lefthook uninstall` locally to drop the git pre-commit script.
- `persistence-freeze` job in `.github/workflows/ci.yml` — was the
  CI backstop for the now-removed lefthook check. ADR-013 retired
  by ADR-014.
- `docs/pocketbase-jsvm.md` "Lefthook persistence-freeze" section —
  replaced by nothing; the freeze is gone.

### Closes

- #184 — Bootstrap a baseline superuser at deploy time.

## v0.9.4 — Production deploy wired up (PR 3/3 for #173)

### Added

- `.github/workflows/deploy.yml` gains a `production` job triggered
  by `workflow_dispatch` with a `target` input (`staging` |
  `production`). Production runs under the `production` GitHub
  Environment so the repo owner can require manual approval before
  any deploy. Staging continues to auto-deploy on push to `main`.
- `fly.toml` `[env]` block: `SMTP_HOST`, `SMTP_PORT`,
  `SMTP_USERNAME`, `SMTP_TLS`, `SMTP_SENDER_ADDRESS`,
  `SMTP_SENDER_NAME`, and `ORIGIN = "https://rivcomocktrial.org"`.
  Without `ORIGIN`, adapter-node would 403 every form-action POST.
  `SMTP_PASSWORD` is set per-app via `fly secrets set`, not
  committed.
- `web/e2e/deploy-smoke.e2e.ts` — read-only Playwright smoke tests
  for any deployed env: `/`, `/_/`, `/login`,
  `/register/teacher-coach`, SSE realtime through Caddy (real
  `EventSource` + `PB_CONNECT` event), and `Set-Cookie` HttpOnly +
  Secure flags. Driven by `SMOKE_BASE_URL` env (defaults to
  staging).
- `web/playwright.deploy.config.ts` — separate Playwright config
  used by the smoke tests; no `webServer`, just the env-driven
  `baseURL`. Local `playwright.config.ts` ignores the smoke spec so
  `npm run test:e2e` keeps working unchanged.
- `npm run test:smoke` — wraps the smoke run. Use
  `SMOKE_BASE_URL=https://rivcomocktrial.fly.dev npm run test:smoke`
  to target production.

### Changed

- Replaced the unstyled school-list scaffold at `/` with a real
  landing page (closes #183). Authenticated users are redirected
  by role: superusers to `/admin`, coaches to `/team`. Anonymous
  visitors see two cards: "Register your team" and "Sign in." This
  is intentionally minimal — the project is an admin tool, not a
  marketing site, so the landing page just routes people to the
  right place. Refinement deferred.

### Changed

- `README.md` "Staging Environment" section replaced with a
  "Deployment" section that documents the unified architecture
  (single-origin Caddy in one container), both environments
  side-by-side, the staging-on-push / production-on-dispatch
  pipeline, `fly secrets` for `SMTP_PASSWORD`, and a step-by-step
  DNS + TLS bootstrap walkthrough (`fly ips`, registrar records,
  `fly certs add`, verification). Links to ADR-015.

## v0.9.3 — Single-origin Caddy reverse proxy on staging (PR 2/3 for #173)

### Added

- `backend/Caddyfile` — reverse proxy listening on `:8090` (the
  external/Fly-edge port stays `8090` so PocketBase docs examples
  copy-paste cleanly against both local dev and the production
  image). Routes `/api/*` and `/_/*` to PocketBase at
  `localhost:8091` (with `flush_interval -1` to preserve SSE for
  realtime), everything else to the SvelteKit Node bundle at
  `localhost:3000`. `auto_https off` because Fly terminates TLS at
  the edge.
- `backend/entrypoint.sh` — shell supervisor that starts PocketBase
  on `127.0.0.1:8091`, the SvelteKit Node bundle on
  `localhost:3000`, and Caddy on `:8090`, with `trap` + `wait -n`
  so any process dying brings the machine down (Fly restarts).
  PocketBase moved off `:8090` internally because Caddy on
  `0.0.0.0:8090` and PB on `127.0.0.1:8090` collide on Linux
  without `SO_REUSEPORT` — the wildcard bind covers the loopback
  interface.
- `docs/decisions.md` — ADR-015 captures the realtime/cookie
  rationale for single-origin deploy.

### Changed

- `backend/Dockerfile` rewritten as three stages: `web-builder`
  (Node, builds SvelteKit and prunes dev deps), `pb-fetcher`
  (alpine, downloads the PocketBase binary in isolation), and the
  final alpine runtime with PB + nodejs + caddy + tini. Drops the
  Elm `frontend-builder` stage entirely. `EXPOSE 8090`.
- `fly.staging.toml`: `internal_port` stays `8090` (Caddy now fronts
  the container on that port). Added `ORIGIN =
  "https://rivcomocktrial-staging.fly.dev"` to the env block;
  adapter-node rejects POSTs whose `Origin` header doesn't match.
- `.github/workflows/deploy.yml` path filter: dropped `frontend/**`,
  added `web/**`. Production deploy stays unwired in this PR; PR 3
  adds it.

## v0.9.2 — feat(web): adapter-node + deploy-aware PB URL (PR 1/3 for #173)

### Changed

- `web/svelte.config.js`: switched adapter from `@sveltejs/adapter-auto`
  to `@sveltejs/adapter-node`. Production builds now write a Node
  bundle to `web/build/` that Caddy can sit in front of.
- `web/src/hooks.server.ts`: PocketBase URL now reads from
  `PB_INTERNAL_URL` (defaults to `http://localhost:8090`); auth cookie
  `secure` flag follows `!dev` so production gets `Secure` cookies
  behind Fly's HTTPS edge.
- `web/src/lib/pocketbase.ts` (currently unused singleton): rewritten
  to be origin-aware. Browser uses `/` in production (same-origin
  through Caddy) and `http://localhost:8090` in dev (split origins);
  server uses `PB_INTERNAL_URL` env or the localhost fallback.

No infra changes — Dockerfile and fly configs are still on the Elm
path. PRs 2 and 3 for #173 will land the Caddy reverse proxy and the
production deploy.

## v0.9.1 — Project review skills: /pr-review and /audit

### Added

- `/pr-review` project skill at `.claude/skills/pr-review/SKILL.md`.
  Interactive, foreground PR review against the SvelteKit + PocketBase
  stack and the mock-trial domain rules. Returns a verdict
  (merge / fix first / hold) plus `file:line` callouts.
- `/audit` project skill at `.claude/skills/audit/SKILL.md`.
  PR-scoped or codebase-wide quality pass — runs `npm run check` and
  `npm run lint`, executes targeted grep checks via
  `.claude/skills/audit/audit-checks.sh`, then briefs a fresh Opus
  subagent for a structured findings report
  (Critical / Warnings / Suggestions / Praise).
- `audit-checks.sh` covers SvelteKit/TS anti-patterns (`let`
  reactive state, `$:` derived, `any`, unjustified `as` casts,
  `localStorage` auth, direct `new PocketBase(`, client-side
  `fetch`) and `pb_hooks` anti-patterns (filter concatenation, PK
  lookups via filter, unwrapped `$app.save`, top-level `const` for
  PB v0.36 JSVM, switch-without-default).

### Removed

- Three Elm-era global slash commands deleted from
  `~/.claude/commands/`: `elm-review.md`, `elm-audit.md`,
  `js-audit.md`. Their underlying skill files in `~/Vault/_skills/`
  and scripts in `~/Vault/_scripts/` were archived to `_archive/`
  subdirectories (recoverable, not in this repo).

## v0.9.0 — Phase C: end-to-end coach registration workflow

### Added

#### Public flow

- `/register/teacher-coach` form: name, email, school
  (search-filterable select grouped by district), team name
  (auto-fills from selected school), password. Gated server-side:
  shows "Registration is closed" card if no tournament has
  `status="registration"`.
- `/register/pending` confirmation page after submit. Both pages
  display the primary contact email pulled from the database.
- `/login` page authenticates against `_superusers` then `users`,
  redirects by collection (`/admin` for superusers, `/team` for
  coaches).

#### Admin UI

- `/admin` dashboard with cards linking to each section.
- `/admin/tournaments` — create, change status (with colored status
  indicator), delete. Default new tournament: 4 prelim + 3 elim
  rounds, status=`draft`.
- `/admin/districts` — inline-edit table of Riverside County
  districts.
- `/admin/schools` — inline-edit table with name/nickname/district
  filter.
- `/admin/registrations` — pending/approved/rejected tabs.
  Approve/reject actions sync the linked team's status via the
  post-update hook.
- `/admin/superusers` — add admins, designate primary contact via
  radio (mutual exclusion). Cannot delete self.
- `/admin/teams` — list of teams in the selected tournament with a
  readiness banner (warns on odd active-team counts; tournaments need
  an even number of teams to run).
- `/admin/+layout.server.ts` guards every child route — non-superusers
  redirect to `/login?next=...`.

#### Coach UI

- `/team` landing page shows the coach's team name, school,
  tournament, status, and any nickname or team number.
- `/team/+layout.server.ts` guard redirects unauthenticated visitors
  to login and superusers to `/admin`.

#### Backend

- `backend/pb_hooks/_constants.js` — shared constants for tournament,
  user, and team status values. Hooks `require()` it inside callbacks
  (PocketBase v0.36 JSVM runs each callback in a fresh VM, so
  top-level `const`s in hook files are not visible at trigger time).
- `backend/pb_hooks/contact_route.pb.js` — public `GET /api/contact`
  endpoint returning the primary RCOE contact (a flagged superuser,
  or oldest as fallback). Server-side via `$app` so superuser data
  isn't exposed publicly.
- `backend/pb_hooks/registration.pb.js` — converted to use
  `_constants` via `require()` at trigger time, fixing a
  `ReferenceError` that previously surfaced as a generic 400 from the
  form.

#### Migrations

- `1800000001_create_districts.js` through
  `1800000005_seed_schools.js` — districts collection,
  schools→district relation, nickname, cascading deletes, and seed
  data for 19 districts and 75 schools.
- `1800000006_superusers_primary_contact.js` —
  `is_primary_contact` boolean on `_superusers`.
- `1800000007_disable_login_alerts.js` — disable PB v0.36's "new
  login" alert email on the `users` collection (replaces an
  auto-generated migration that used the legacy collection ID).
- `1800000008_seed_superusers.js` — seed RCOE admins from a static
  list, flag `mknust@rcoe.us` as primary contact. Idempotent.

#### Tests

- `web/src/lib/domain/registration.ts` + 14 vitest cases covering the
  registration state machine: `isTournamentOpenForRegistration`,
  `activeTeamCount`, `canRunTournament` (odd-count detection),
  `nextTeamStatusForUserStatus`.
- `web/e2e/registration-flow.e2e.ts` — Playwright happy-path:
  register → admin approve → coach login → see team. Self-skips when
  `TEST_ADMIN_EMAIL`/`TEST_ADMIN_PASSWORD` env vars or an open
  tournament are missing.

### Changed

- `web/src/hooks.server.ts` refreshes auth against the correct
  collection (`_superusers` or `users`) based on the cookie's record
  type.
- `web/src/app.d.ts` — `pb` is now `TypedPocketBase`.
- `backend/pb_hooks/smtp_config.pb.js` renamed to `.disabled` —
  direct property assignment (`s.smtp.enabled = ...`) panics
  PocketBase v0.36 at startup. Tracked in
  [#146](https://github.com/jluckyiv/rivcomocktrial/issues/146).

### Removed

- Auto-generated `1777193384_updated_users.js` migration (replaced by
  the hand-written `1800000007_disable_login_alerts.js`).

## v0.8.1 — Seed data: Riverside County high schools (#145)

### Added

- `backend/pb_seed/schools.json` — 75 Riverside County high schools
  across 19 districts (Diocese of San Bernardino plus 18 public
  districts); importable via PocketBase admin UI for bulk-import
  smoke test in Slice 01

## v0.8.0 — Phase B: domain algorithm modules (#144)

### Added

- `web/src/lib/domain/standings.ts` — win/loss record and rank ordering
- `web/src/lib/domain/matchHistory.ts` — trial history with per-team side
  counts; reference-equality generic over team type
- `web/src/lib/domain/eligibleStudents.ts` — student eligibility filtering
  by role and side
- `web/src/lib/domain/powerMatch.ts` — Swiss-system pairing algorithm with
  HighHigh/HighLow cross-bracket strategies
- `web/src/lib/domain/powerMatchFixtures.ts` — shared test fixtures for
  power-match specs
- `web/src/lib/domain/elimBracket.ts` — 8-team elimination bracket seeding
  (1v8, 2v7, 3v6, 4v5)
- `web/src/lib/domain/elimSideRules.ts` — Prosecution/Defense assignment
  for elimination rounds; exports `Trial<T>` and `MeetingHistory`
- `web/src/lib/domain/roundProgress.ts` — trial status rollup
  (CheckInOpen → AllTrialsStarted → AllTrialsComplete → FullyVerified)
- `web/src/lib/domain/trialClosure.ts` — `completeTrial` / `verifyTrial`
  coordinating ballot status and trial status transitions
- `web/src/lib/domain/ballotAssembly.ts` — assembles PocketBase API records
  into domain ballot types (SubmittedBallot, VerifiedBallot, PresiderBallot)
- `web/src/lib/domain/awards.ts` — rank-points scoring and award categories
  (BestAttorney, BestWitness, BestClerk, BestBailiff)
- 193 Vitest unit tests across 11 domain modules; 0 type errors

### Fixed

- Corrected swapped return-type annotation in `pairWithinBrackets`
  (`powerMatch.ts`) caught by `svelte-check`

## v0.7.0 — Phase A: SvelteKit scaffold + PocketBase wire (#143)

### Added

- `web/`: SvelteKit + Svelte 5 + TypeScript + Tailwind v4 + shadcn-svelte
  (Vega preset) + Vitest + Playwright
- `web/src/hooks.server.ts`: per-request PocketBase client; httpOnly cookie
  auth (loads from cookie, refreshes if valid, writes back on every response)
- `web/src/lib/pocketbase-types.ts`: TypeScript types generated from local DB
  via `pocketbase-typegen`
- `web/src/lib/pocketbase.ts`: singleton PocketBase client for client-side use
- `web/src/app.d.ts`: `App.Locals` declaration (`pb`, `user`)
- Proof-of-life route: schools list rendered server-side from PocketBase

## v0.6.0 — SvelteKit rebuild begins; Elm frontend abandoned (#142)

### Changed

- Abandoned Elm frontend rebuild (ADR-014); switching to SvelteKit +
  TypeScript + Svelte 5 + Tailwind v4 + shadcn-svelte
- Stripped Elm-refactor-era content from `CLAUDE.md`, hooks, settings,
  and `lefthook.yml`; added TODO markers for post-scaffold fill-in
- Archived Elm-era docs (`elm-conventions.md`, `refactor-process.md`,
  `ui-conventions.md`, `domain-audit.md`, `roadmap.md`,
  `domain-roadmap.md`, `slices/`) to `docs/archive/`
- Added ADR-014 (Elm abandoned → SvelteKit); superseded ADR-012 and
  ADR-013
- Deleted `.claude/skills/refactor-slice/` (Elm-specific)

## v0.5.10 — Admin Trials page + ballot schema (#111, #129, #130, #137)

### Added

- `Pages/Admin/Trials.elm`: trial management per round — inline judge/scorer
  assignment (setup mode), submission count monitoring, Open/Lock/Unlock
  round status controls
- "Manage Trials" button per round row on Rounds page
- `judges` collection: name + email
- `rounds`: `status` (upcoming/open/locked), `ranking_min`, `ranking_max`
- `trials`: `judge`, `scorer_1`–`scorer_5` relation fields
- `presider_ballots`: `motion_ruling`, `verdict` fields
- `Api.elm`: `Judge`, `RoundStatus`, `MotionRuling`, `TrialVerdict` types
  with decoders and encoders

### Fixed

- `Api.elm`: 13 `fieldWithDefault` calls on required schema fields converted
  to `Decode.field` (fail loudly on missing data)
- `registration.pb.js`: pre-commit guard rejects registration when no open
  tournament exists, preventing orphaned accounts
- `ballot_guard.pb.js`: extracted `validateScorerToken` and `markTokenUsed`
  helpers, removing ~80 lines of duplicated scorer/presider logic
- `interop.js`: corrupted `coachUser` localStorage now logs a warning and
  cleans up instead of silently failing

### Tests

- `ApiDecoderTest`: 29 new decoder tests covering all new Api types
- `TrialsHelperTest`: 14 new tests for `fieldValue` and `applyFieldValue`

## v0.5.9 — Pairings FormState + BulkState refactor (#126)

### Changed

- `Pages/Admin/Pairings.elm`: replaced 6 interacting primitive state fields
  (`formSaving`, `editingId`, `formErrors`, `showBulkPreview`, `bulkSaving`,
  `bulkText`/`bulkParsed`/`bulkErrors`) with `FormState` and `BulkState` sum
  types, mirroring the pattern in `Pages/Admin/Schools.elm`

### Fixed

- Bulk-save and delete failures no longer leak into `formErrors`; bulk errors
  route to `BulkFailed`, delete errors are discarded silently

### Tests

- 11 Playwright e2e tests added for the Admin Pairings page (dropdown form,
  bulk text, edit/delete, validation)
- Shared `adminLogin` helper extracted to `tests/e2e/helpers/auth.ts`
- PB credentials cached to `.pocketbase/` to avoid repeated 1Password lookups

## v0.5.8 — Elm Correctness (#118)

### Fixed

- `Api.elm`: required enum fields (`scorer_role`, `status`, `winner_side`,
  `submitted_at`, `corrected_at`) changed from `fieldWithDefault` to
  `Decode.field` — missing values now fail hard instead of silently defaulting
- `Pages/Team/Rosters.elm` + `Pages/Team/Manage.elm`: removed local
  `RemoteData` type definitions; now import shared `RemoteData` module
- `Pages/Admin/Login.elm`: replaced `loading : Bool` + `error : Maybe String`
  with `loginState : LoginState` sum type (`Idle | Loading | Failed String`)

## v0.5.7 — JS Audit Fixes (#117)

### Fixed

- All pb_hooks: replaced string-concatenated filters with `{:param}`
  parameterized syntax
- `eligibility.pb.js` + `withdrawal.pb.js`: use `findRecordById` for PK
  lookups instead of `findRecordsByFilter`
- `withdrawal.pb.js`, `registration.pb.js`, `eligibility.pb.js`: wrapped
  `$app.save` / `$app.delete` in try/catch with error logging
- `interop.js`: added `default` cases to both port switches; removed
  `localStorage.setItem` from login handlers; `SaveCoachToken` now calls
  `pb.authStore.save`; fixed fake `{ id: "admin" }` model → `null`

## v0.5.6 — JS Linting Setup (#116)

### Added

- ESLint 10 (flat config) + Prettier with `eslint-config-prettier` for
  `frontend/src/interop.js` and `backend/pb_hooks/`
- `npm run lint:js` — lint JS files only
- `npm run lint` — lint JS + elm-review

## v0.5.5 — M4 Phase 1 Audit Fixes (#112)

### Fixed

- `BallotAssembly.assembleVerifiedBallot`: return type changed from
  `VerifiedBallot` to `Result (List Error) VerifiedBallot`; errors
  from corrected presentations are now propagated, not silently dropped
- `Api.ballotScoreDecoder`: `presentation`, `side`, `points` now use
  `Decode.field` (hard failure) instead of `fieldWithDefault`
- `Api.ballotCorrectionDecoder`: `corrected_points` now uses
  `Decode.field`
- `Api.ScorerRole` constructors renamed `ScorerRole`/`PresiderRole` →
  `Scorer`/`Presider` to eliminate ambiguity with the type name
- `BallotCorrection.originalScore` renamed to `originalScoreId`
- `assembleStudent`: simplified last-space split using
  `String.split`/`List.reverse`
- `assembleVerifiedBallot`: `correctionMap` uses `Dict String Int`
  instead of `List (String, Int)`
- `rosterSideToSide` removed from `BallotAssembly` exposed list;
  internal-implementation test removed (675 tests)

## v0.5.4 — Codebase Cleanup (#113)

### Fixed

- `Pages/Admin/EligibilityRequests.elm`,
  `Pages/Admin/Registrations.elm`: removed local `RemoteData`
  re-declarations; now import canonical `RemoteData` module
- `Pages/Admin/Login.elm`: rewrote view from Bulma to DaisyUI
  (card layout, `UI.elm` helpers throughout)
- `Pages/Team/Login.elm`: finished DaisyUI migration; removed
  remaining Bulma `columns`/`field`/`notification` classes

### Added

- `UI.passwordField`: `textField` variant with `type="password"`

## v0.5.3 — M4 Phase 1: Ballot Entry Backend

### Added (PR #110)

- 5 PocketBase migrations for ballot collections:
  `scorer_tokens` (token-based auth for scorer access),
  `ballot_submissions`, `ballot_scores`,
  `presider_ballots`, `ballot_corrections`
- `ballot_guard.pb.js` hook: validates scorer tokens on
  ballot_submissions / presider_ballots create (active,
  correct trial, correct role), marks token used after
  commit
- `Api.elm`: `ScorerToken`, `BallotSubmission`,
  `BallotScore`, `PresiderBallotRecord`,
  `BallotCorrection` types with decoders and encoders
- `BallotAssembly.elm`: converts flat API records ↔
  domain types (`SubmittedBallot`, `VerifiedBallot`,
  `PresiderBallot`); handles student name parsing for
  round-tripping opaque domain types
- 27 new `BallotAssemblyTest` tests (677 total)
- `CLAUDE.md` updated with test commands, frontend
  architecture section, and backend architecture section

## v0.5.2 — Phase-Aware Admin Dashboard

### Added (PR #107)
- `/admin` dashboard page (`Pages/Admin.elm`) that reads the active
  tournament's `status` field and renders a phase-appropriate view:
  - **Registration**: stat cards for pending approvals, active teams,
    and pending withdrawals; link to `/admin/registrations`
  - **Active**: stat cards for pending eligibility requests and active
    teams; links to `/admin/eligibility-requests` and `/admin/rounds`
  - **Draft / no active tournament**: prompt to go to
    `/admin/tournaments`
  - **Completed**: "tournament concluded" message
- `UI.statCard` helper renders a DaisyUI `stat` component with an
  optional text-color variant (`"warning"`, `"success"`, etc.)
- "Dashboard" added as first nav item in desktop and mobile admin nav
- Post-login redirect changed from `/admin/tournaments` to `/admin`
- Playwright e2e tests: login redirect, stat card visibility, and
  pending-approval count increment
- Closes #69

## v0.5.1 — Second-Team Badge + Registration Hook Fix

### Added (PR #105)
- Admin `/admin/registrations` shows a "2nd Team" warning badge and a
  note naming the existing team and coach when a pending coach is from
  a school that already has an active team; helps RCOE spot duplicate
  school registrations at a glance (Closes #73)
- `UI.note` helper renders small muted explanatory text below a cell
- Playwright e2e suite (`tests/e2e/`) with self-contained
  beforeAll/afterAll fixtures against the real PocketBase; covers the
  second-team badge, the no-badge case, and the approve-coach flow

### Fixed (PR #106)
- Coach-approval hook now scopes the team-status sync to
  `status = 'pending'` teams only; previously re-saving an approved
  coach record would accidentally re-activate or re-reject resolved
  (active, withdrawn) teams

## v0.5.0 — Attorney Tasks + Type Cleanup + Withdrawal Requests

### Added (PR #103)
- Team withdrawal requests: coaches submit a withdrawal request with
  an optional reason via "Request Withdrawal" on `/team/manage`;
  RCOE admins confirm or dismiss pending requests on
  `/admin/registrations`; PocketBase hook sets team status to
  "withdrawn" on approval
- `WithdrawalRequest` type, decoder, `encodeWithdrawalRequest`, and
  `encodeTeamStatus` in `Api.elm`
- PocketBase migration `1776301400` adds `withdrawal_requests`
  collection (team, reason, status); `withdrawal.pb.js` hook applies
  status change on approval
- Withdrawn teams show a read-only banner and suppress all action
  buttons on `/team/manage`; "Reactivate" button on
  `/admin/registrations` restores a team to active
- Closes #72

### Changed (PR #102)
- `FormState`: `FormSaving FormData` split into `FormSavingDraft
  FormData` and `FormSubmitting FormData` — saving kind is now in
  the type, not a hidden `submitting : Bool` field inside `FormData`
- `viewFormContent` now takes `FormState` directly; callers pass
  `model.form` instead of unpacking it first (Closes #96)
- `FormRow.entryType` changed from `String` to `Api.EntryType`;
  `FormRow.role` changed from `String` to `Maybe Api.RosterRole` —
  new `updateRowEntryType`/`updateRowRole` helpers in `RosterForm`
  parse select input; save handlers use domain types directly,
  removing `parseEntryType`/`parseRole` at encode time (Closes #97)

### Added (PR #101)
- Attorney task assignment UI on `/team/rosters`: coaches can
  now assign opening statement, direct examination, cross
  examination, and closing argument to each trial attorney
  per round via an inline form
- `encodeTaskType` and `encodeAttorneyTask` in `Api.elm` for
  PocketBase create/update of `attorney_tasks` records
- Task form validates task type required, character required
  for direct/cross, no duplicate (type, character) pairs per
  attorney; character dropdown scopes own-side witnesses for
  direct, opposing-side witnesses for cross
- Roster form and task form are mutually exclusive — opening
  one blocks the other
- Closes #100

## v0.4.5 — Tooling: elm-review + CI

### Added (PR #99)
- `elm-review` 2.13.5 with `NoUnused.*` and `NoDebug.*`
  rules; `review/` config committed; 3 legacy errors
  suppressed (elm-land placeholder, pre-persistence
  domain scaffolding)
- CI workflow (`.github/workflows/ci.yml`): parallel
  `elm-test` and `elm-review` jobs on push/PR when
  `frontend/**` changes; `elm-land generate` runs first
  to materialise generated source directories
- `fe:review` and `fe:test` scripts in `package.json`

### Fixed (PR #99)
- Delete `RegistrationTest.elm`; trim `FixturesTest.elm`
  — both referenced `Registration` module deleted in
  PR #78; all 650 remaining tests pass
- `elm-review --fix-all-without-prompt` removed unused
  imports and renamed unused parameters to `_` across
  src/ and tests/
- Closes #95, Closes #98

## v0.4.4 — Roster Form Refactor + Security Fix

### Added (PR #94)
- `RosterForm.elm`: shared module for form types,
  validation, row-update helpers, and view — eliminates
  ~300 lines of duplicated logic across roster pages

### Fixed (PR #94)
- Coach roster page (`/team/rosters`) leaked all trials
  and attorney_tasks to any logged-in coach; queries now
  filter to the team's own records
- Closes no issue (security hardening + refactor)

### Added (PR #93)
- Contextual "Case Characters" link per tournament row
  on `/admin/tournaments` (#88)
- Closes #88

## v0.4.3 — Post-Login Redirect

### Added (PR #92)
- Post-login redirect: unauthenticated users return to
  their originally requested page after logging in (#87)
- Auth gate captures intended route as `?redirect=`
  query param on login URL
- Works for both admin and coach login flows
- Closes #87

## v0.4.2 — Admin Roster Override (Phase 3)

### Added (PR #91)
- Admin roster drill-down: click matrix cell to view
  roster entries in detail card (#85)
- Admin override form: edit any roster regardless of
  submission/lock status via adminCreate/Update/Delete
- Selected cell ring highlight in compliance matrix
- Closes #85 — all three phases complete

## v0.4.1 — Roster Editing Form (Phase 2)

### Added (PR #90)
- Roster editing form on `/team/rosters`: add/remove
  entry rows with student, role, character selects (#85)
- Witness character dropdown (case characters for side)
- Duplicate student prevention within roster (#85)
- Save Draft and Submit Roster flows (#85)
- Read-only view after submission (#85)

### Fixed (PR #90)
- "Rosters" nav link missing from desktop team menu
- Migration 1776301300: open read access on rounds,
  trials, students for coach data loading (#85)

## v0.4.0 — Rosters UI (Phase 1)

### Added (PR #89)
- `/admin/case-characters`: full CRUD for tournament
  case witnesses (prosecution/defense) (#85)
- `/team/rosters`: read-only roster view with round
  accordion, side badges, submission status (#85)
- `/admin/rosters`: compliance dashboard — matrix of
  teams × rounds showing P/D submission status (#85)
- "Rosters" nav link in team layout (#85)
- Auth gate for `/team/rosters` route (#85)

### Fixed (PR #89)
- PocketBase `required: true` on number fields rejects
  `0` as blank — migration removes `required` from
  `sort_order` on case_characters, roster_entries,
  attorney_tasks (#85)

### Added (PR #86)
- 6 PocketBase migrations: pronouns on students,
  roster_deadline_hours on tournaments, and new
  collections case_characters, roster_submissions,
  roster_entries, attorney_tasks (#85)
- Full roster type system in Api.elm: Pronoun,
  RosterSide, EntryType, RosterRole, TaskType,
  CaseCharacter, RosterSubmission, RosterEntry,
  AttorneyTask — with decoders and encoders (#85)
- Pronouns field on Admin/Students create/edit form
  (#85)

## v0.3.0 — DaisyUI + Auth + Team Management

### Added
- Team management page `/team/manage`: eligibility list
  (add/remove before lock, change requests after lock),
  co-teacher coaches, attorney coaches (#71, PR #80)
- Admin eligibility change request approval page
  `/admin/eligibility-requests` (#71, PR #80)
- PocketBase hook: auto-applies approved change requests
  to `eligibility_list_entries` (#71, PR #80)
- Custom types for all string primitives in `Api.elm`:
  `ChangeType`, `RequestStatus`, `EligibilityStatus` (#81,
  PR #83); `TournamentStatus`, `TeamStatus`,
  `CoachUserStatus`, `RoundType` (#82, PR #84)
- Atomic registration workflow: email/password signup,
  pending state, admin approval gate (#70, PR #75)
- PB JS SDK as sole HTTP client; `Pb.elm` port-based
  wrapper; `pbAdmin` + `pb` dual instances (ADR-010,
  #64, PR #65)
- Coach auth: `CoachAuth` sum type, login page
  `/team/login`, auth guard hook, dual admin/coach
  gating (#64, PR #65)
- EligibleStudents domain module (Draft/Submitted/Locked,
  configurable 8–25 per Rule 2.2A); Team layout;
  coach page `/team/eligible-students` (#54, PR #59)
- Registration workflow with hardcoded data: role
  selection, teacher coach form, pending confirmation,
  admin approval page (#57, PR #58)
- Fixtures module with 2026 data (26 teams, 26 schools,
  12 districts) (#54, PR #55)
- MatchHistory module extracted from PowerMatch; Pairings
  page wired to real PowerMatch (PR #56)
- TrialClosure module: `reopenTrial`,
  `replaceVerifiedBallot`, ballot-aware transitions
  (#40, PR #53)
- ElimBracket module: 1v8/2v7/3v6/4v5 seeding per rule
  5.5H; `Team.sameTeam` canonical identity (PR #52)
- MVP domain gaps: `ActiveTrial`, `RoundProgress`,
  `VolunteerSlot`, `BallotTracking`, `Publication`,
  `TrialResult`, `ElimSideRules` (#49, PRs #50–51)
- Volunteer and Conflict domain types (#39, PR #48)
- Client-side domain validation on all admin form pages
  (`validateForm` + `List String` errors) (#36, #46,
  PRs #42–47)
- `UserRole`, `TrialRole`, expanded `Judge` type with
  Name+Email (#37, PR #41)
- `AwardCategory`, `Side` on Roster, `UnofficialTimer`
  role (PR #32)
- Roster composition validation, Awards rank-points
  scoring, Standings with configurable tiebreakers
  (PR #32)
- Catppuccin Latte/Mocha theme (disabled, kept for later)
  (PR #31)
- Domain audit complete: all 4 tiers opaque with
  `Result (List Error) a` smart constructors (PRs #28–30)

### Changed
- Migrated frontend from Bulma to DaisyUI 5 + Tailwind
  CSS 4; `UI.elm` is now the sole view helper (#67–68,
  PR #66, v0.3.0)
- `docs/ui-conventions.md` is the authoritative UI
  reference
- `Registration.elm` domain module and dead Fixtures code
  removed after registration redesign (#74, PR #78)

### Fixed
- `teams.listRule` was null — coaches could not load
  their own team; added migration 1776300500 (#71)
- PocketBase returns `""` for unset datetime fields;
  `isLocked` now treats `""` as unlocked (#71)

## v0.2.0 — Domain Model Complete

### Added
- `Awards` module with `AwardCategory` and configurable
  criteria (#27)
- `Standings` with `TeamRecord` and configurable
  tiebreakers (#26)
- `ElimResult` with scorecard majority verdict (#25)
- `PrelimResult` with Court Total verdict (#24)
- `Rank` and `Nomination` modules with
  `NominationCategory` (#23)
- `PresiderBallot` for tiebreaker side selection (#22)
- `VerifiedBallot` with state promotion from
  `SubmittedBallot` (#21)
- `SubmittedBallot` with `ScoredPresentation` and
  scoring logic (#20)
- `Roster` module with `RoleAssignment` and
  `AttorneyDuty` (#19)
- `Witness` opaque type (#18)
- `Pairing` and `Trial` domain modules with `Assignment`
  (#15)
- `Courtroom` domain module (#14)
- `Round` domain module with phase derivation (#13)
- PowerMatch module: cross-bracket strategy,
  backtracking, 2026 fixture validation tests (#11)
- Bulk text import for Schools, Courtrooms, Students,
  Teams
- Impossible-states pattern on all admin pages

### Changed
- Migrated 12 manual validators to elm-validate

## v0.1.0 — Foundation

### Added
- PocketBase backend with Docker; migrations for core
  collections (tournaments, rounds, teams, schools,
  courtrooms, students, trials)
- Admin CRUD pages for all collections
- Round pairing and scheduling (Milestone 2)
- Staging environment on fly.io (GitHub Actions deploy)
- Project README, roadmap, and architecture decisions
  (ADR-001 through ADR-006)
- Domain modules: District, School, Student, Coach,
  Email, Team, Side, Role, Tournament
