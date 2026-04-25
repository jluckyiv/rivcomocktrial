# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versions follow [Semantic Versioning](https://semver.org/).

## Unreleased

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
