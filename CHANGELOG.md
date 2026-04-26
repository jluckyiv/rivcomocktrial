# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versions follow [Semantic Versioning](https://semver.org/).

## Unreleased

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
