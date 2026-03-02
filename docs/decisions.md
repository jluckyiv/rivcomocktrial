# Architecture Decisions

Decisions made during development, with context and
rationale. Newest first.

---

## ADR-007: Auth UX — role self-identification and OAuth labels

**Date:** 2026-03-01

**Context:** The app has multiple user roles (teacher
coach, attorney coach, scorer/judge, admin) with
different auth mechanisms. Need to decide how users
identify themselves at registration and what the OAuth
buttons should say.

**Decision:**

1. **Role selection first.** The login/register screen
   opens with "How are you participating?" and presents
   role cards:
   - "Teacher Coach" → OAuth2 → applicant flow (admin
     approval required)
   - "Attorney Coach" → OAuth2 → simpler registration
   - "Scorer / Judge" → magic link (email) or QR code
     scan on tournament day
   - Admin and SuperUser are never self-registered —
     created by existing admins

2. **OAuth button labels use education-specific names:**
   - "Sign in with Microsoft 365 Education"
   - "Sign in with Google Workspace for Education"

   This signals that teachers should use their
   school-issued account, not a personal one. The school
   domain in the OAuth response aids admin verification.

3. **Scorer/judge auth is lightweight.** Scorers
   authenticate via magic link (emailed) or by scanning
   a single tournament-wide QR code on the day of
   competition. No password, no OAuth. This
   accommodates last-minute volunteers and reduces
   friction on tournament day.

**Rationale:**
- Role selection up front maps directly to `UserRole`
  domain type and determines the auth flow
- Education-branded OAuth buttons set correct
  expectations — teachers know to pick their school
  account, reducing mismatched-identity issues
- RCOE distinguishes teacher coaches from attorney
  coaches at registration (different privileges, only
  teachers receive scores and admin their team) — the
  UI should reflect this distinction early
- Magic link / QR for scorers matches the reality:
  volunteers sign up days before or show up the morning
  of, and must be scoring within minutes

**Consequences:**
- Login screen has a pre-auth step (role selection)
  before showing auth options — slightly more clicks
  but clearer flow
- OAuth provider configuration needs two providers
  (Google + Microsoft) in PocketBase
- Magic link requires PocketBase email sending config
- Single tournament-wide QR code means any scanner gets
  the auth flow — courtroom assignment happens after
  auth, not encoded in the QR
- Admin/SuperUser creation is an admin-only action,
  keeping the public-facing auth screen simple

---

## ADR-006: Flat module-per-concept for domain types

**Date:** 2026-03-01

**Context:** Building a pure domain layer (no persistence
concerns). Need to decide how to organize domain types
in the Elm frontend. Options considered: a single
`Domain.elm` module, a `Domain.*` namespace, or flat
top-level modules named after domain concepts.

**Decision:** One flat module per domain concept, named
after the noun: `School.elm`, `Student.elm`, `Coach.elm`,
`Team.elm`. No `Domain` namespace.

**Rationale:**
- Follows elm-spa-example convention (Feldman): each
  module is the domain concept, not a layer
- Consistent with ML-family best practices (Haskell,
  OCaml, F#) — `Domain` is an OOP/DDD-ism that adds
  a redundant namespace
- "The Life of a File" (Czaplicki): split around domain
  concepts, not architectural layers
- `School.elm` is self-evidently a domain concept —
  wrapping it in `Domain.School` adds noise
- Types and their functions live together in the same
  module (test combinators, not type definitions)

**Consequences:**
- Domain types tested via combinators/derived values,
  not construction — Elm's type system already prevents
  invalid construction
- May need to rename if a module name collides with
  an Elm Land page module (unlikely for domain nouns)
- Related types grouped by proximity: e.g., `District`
  lives in `School.elm` since it's tightly coupled

---

## ADR-005: Staging environment on fly.io

**Date:** 2026-02-28

**Context:** The admin team (2–5 people) needs to try
the app and give UI feedback without running locally.
We need a deployed instance before the app is
production-ready.

**Decision:** Create a separate `rivcomocktrial-staging`
app on fly.io with its own config (`fly.staging.toml`)
and deploy token. GitHub Actions deploys to staging on
push to main, scoped to app-relevant paths only
(`frontend/**`, `backend/**`, fly configs,
`.dockerignore`). Reserve `fly.toml` and the
`rivcomocktrial` app name for future production use.

**Rationale:**
- Separate staging app avoids risk to future production
  data
- Path-scoped deploys avoid unnecessary builds for
  documentation-only changes
- Same Dockerfile for both environments — no config
  drift
- `node:20-slim` (not alpine) required for the frontend
  build stage because the elm npm binary needs glibc

**Consequences:**
- Two fly.io apps to manage (staging now, production
  later)
- Each environment needs its own `FLY_API_TOKEN` — may
  need to rename the GitHub secret when production is
  added
- Staging data is disposable and not backed up
- Dockerfile uses a mixed base image strategy:
  `node:20-slim` for build (glibc for elm) and
  `alpine:3.19` for runtime (small image for
  PocketBase)

---

## ADR-004: Admin auth via PocketBase superuser (Milestone 1)

**Date:** 2026-02-28

**Context:** The system needs multiple auth roles (admin,
teacher coach, attorney coach, scorer, public). We need to
decide how to authenticate admins first, since they're the
primary users for Milestone 1.

**Decision:** Use PocketBase's built-in superuser auth for
admin login. The Elm frontend sends email/password to
`/api/collections/_superusers/auth-with-password` and
stores the returned token in `Shared.Model`. Admin pages
are guarded by `Auth.elm` which redirects to `/admin/login`
when no token is present.

**Rationale:**
- Simplest possible auth for Milestone 1 — no custom auth
  collections needed
- PocketBase superuser has full API access, which is what
  admins need
- Token is stored in memory only (lost on page refresh) —
  acceptable for now, can add localStorage persistence
  later
- Coach OAuth (Google/MS) and other roles are deferred to
  later milestones

**Consequences:**
- Admin must re-login on every page refresh (no token
  persistence yet)
- Only one auth type exists right now — role separation
  comes later
- The `/api/collections/_superusers/auth-with-password`
  endpoint is PocketBase-specific; if we ever migrate
  away from PocketBase, auth would need rework

---

## ADR-003: PocketBase collections schema (Milestone 1)

**Date:** 2026-02-28

**Context:** Need to model the core domain entities. Key
domain fact: School ≠ Team. A school can field 1–2 teams
per tournament. Students belong to schools (not teams) and
get assigned to teams per tournament via round rosters
(Milestone 3).

**Decision:** Five base collections for Milestone 1:

- `tournaments` — standalone, with status workflow
  (draft → registration → active → completed)
- `schools` — standalone, with district
- `courtrooms` — standalone, with location
- `teams` — belongs to tournament and school
  (cascade-deletes with tournament)
- `students` — belongs to school (not to team — team
  assignment happens via round rosters later)

**Rationale:**
- Mirrors the real-world domain: schools register, then
  teams are created per tournament
- Students on schools (not teams) because the same
  student could theoretically be on different teams
  across tournaments, and roster assignment is per-round
- Tournament status as a select field with fixed values —
  simple and sufficient
- Teams cascade-delete with their tournament because a
  team only makes sense within a tournament context

**Consequences:**
- No `users` auth collection yet — admin-only via
  superuser
- Round rosters (Milestone 3) will link students to teams
  per round
- If we need tournament-level student eligibility (beyond
  school membership), we'd add a junction collection
  later

---

## ADR-002: Bulma CSS framework

**Date:** 2026-02-28 (Milestone 0)

**Context:** Need a CSS framework for the Elm Land
frontend. Options considered: Bulma, Tailwind, elm-ui,
elm-css.

**Decision:** Bulma v1.0.4 via CDN link in
`elm-land.json`.

**Rationale:**
- Elm Land's own tutorials use Bulma — happiest path
- Zero build tooling — one CDN link, apply classes via
  `Html.Attributes.class`
- Tailwind would require an extra CLI watcher
- elm-ui and elm-css are effectively unmaintained (as of
  Feb 2026)
- CDN URL must use cdnjs format (not jsDelivr) because
  elm-land's HTML templating mangles `@` symbols

**Consequences:**
- All styling is class-based — no type-safe styling, but
  simple and well-documented
- Bulma is CSS-only (no JavaScript) — all interactivity
  is in Elm, which is what we want

---

## ADR-001: PocketBase as backend

**Date:** 2026-02-28 (Milestone 0)

**Context:** Need a backend for a small competition
management app. Team of 2–5 admins, ~26 teams, low
concurrent users. Must support: auth, CRUD, relations,
real-time updates (eventually), file storage (eventually).

**Decision:** PocketBase v0.36.3, used out-of-the-box with
JS migrations and hooks. No custom Go extensions. Single
binary deployed in a Docker container on fly.io with a
persistent SQLite volume.

**Rationale:**
- Single binary, zero external dependencies — ideal for
  a small project
- Built-in auth (email/password + OAuth), REST API, admin
  UI, realtime subscriptions
- SQLite is sufficient for this scale (~26 teams, <100
  concurrent users)
- JS migrations and hooks cover our customization needs
  without needing a Go build toolchain
- fly.io persistent volume for SQLite data — simple and
  cheap

**Consequences:**
- SQLite means single-writer — concurrent ballot entry
  (Milestone 8) needs care, but PocketBase handles WAL
  mode
- No horizontal scaling — single instance only, which is
  fine for this scale
- Vendor lock-in to PocketBase API format — acceptable
  given the project scope
- Migrations are version-controlled; data is local-only
  (never committed)
