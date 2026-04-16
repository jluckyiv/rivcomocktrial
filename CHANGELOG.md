# Changelog

All notable changes to this project are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
Versions follow [Semantic Versioning](https://semver.org/).

## Unreleased

- Issue #61: Rosters UI (coach round roster management)

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
