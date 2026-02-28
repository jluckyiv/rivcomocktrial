# Architecture Decisions

Decisions made during development, with context and rationale. Newest first.

---

## ADR-004: Admin auth via PocketBase superuser (Milestone 1)

**Date:** 2026-02-28

**Context:** The system needs multiple auth roles (admin, teacher coach, attorney coach, scorer, public). We need to decide how to authenticate admins first, since they're the primary users for Milestone 1.

**Decision:** Use PocketBase's built-in superuser auth for admin login. The Elm frontend sends email/password to `/api/admins/auth-with-password` and stores the returned token in `Shared.Model`. Admin pages are guarded by `Auth.elm` which redirects to `/admin/login` when no token is present.

**Rationale:**
- Simplest possible auth for Milestone 1 — no custom auth collections needed
- PocketBase superuser has full API access, which is what admins need
- Token is stored in memory only (lost on page refresh) — acceptable for now, can add localStorage persistence later
- Coach OAuth (Google/MS) and other roles are deferred to later milestones

**Consequences:**
- Admin must re-login on every page refresh (no token persistence yet)
- Only one auth type exists right now — role separation comes later
- The `/api/admins/auth-with-password` endpoint is PocketBase-specific; if we ever migrate away from PocketBase, auth would need rework

---

## ADR-003: PocketBase collections schema (Milestone 1)

**Date:** 2026-02-28

**Context:** Need to model the core domain entities. Key domain fact: School ≠ Team. A school can field 1–2 teams per tournament. Students belong to schools (not teams) and get assigned to teams per tournament via round rosters (Milestone 3).

**Decision:** Five base collections for Milestone 1:

- `tournaments` — standalone, with status workflow (draft → registration → active → completed)
- `schools` — standalone, with district
- `courtrooms` — standalone, with location
- `teams` — belongs to tournament and school (cascade-deletes with tournament)
- `students` — belongs to school (not to team — team assignment happens via round rosters later)

**Rationale:**
- Mirrors the real-world domain: schools register, then teams are created per tournament
- Students on schools (not teams) because the same student could theoretically be on different teams across tournaments, and roster assignment is per-round
- Tournament status as a select field with fixed values — simple and sufficient
- Teams cascade-delete with their tournament because a team only makes sense within a tournament context

**Consequences:**
- No `users` auth collection yet — admin-only via superuser
- Round rosters (Milestone 3) will link students to teams per round
- If we need tournament-level student eligibility (beyond school membership), we'd add a junction collection later

---

## ADR-002: Bulma CSS framework

**Date:** 2026-02-28 (Milestone 0)

**Context:** Need a CSS framework for the Elm Land frontend. Options considered: Bulma, Tailwind, elm-ui, elm-css.

**Decision:** Bulma v1.0.4 via CDN link in `elm-land.json`.

**Rationale:**
- Elm Land's own tutorials use Bulma — happiest path
- Zero build tooling — one CDN link, apply classes via `Html.Attributes.class`
- Tailwind would require an extra CLI watcher
- elm-ui and elm-css are effectively unmaintained (as of Feb 2026)
- CDN URL must use cdnjs format (not jsDelivr) because elm-land's HTML templating mangles `@` symbols

**Consequences:**
- All styling is class-based — no type-safe styling, but simple and well-documented
- Bulma is CSS-only (no JavaScript) — all interactivity is in Elm, which is what we want

---

## ADR-001: PocketBase as backend

**Date:** 2026-02-28 (Milestone 0)

**Context:** Need a backend for a small competition management app. Team of 2–5 admins, ~26 teams, low concurrent users. Must support: auth, CRUD, relations, real-time updates (eventually), file storage (eventually).

**Decision:** PocketBase v0.36.3, used out-of-the-box with JS migrations and hooks. No custom Go extensions. Single binary deployed in a Docker container on fly.io with a persistent SQLite volume.

**Rationale:**
- Single binary, zero external dependencies — ideal for a small project
- Built-in auth (email/password + OAuth), REST API, admin UI, realtime subscriptions
- SQLite is sufficient for this scale (~26 teams, <100 concurrent users)
- JS migrations and hooks cover our customization needs without needing a Go build toolchain
- fly.io persistent volume for SQLite data — simple and cheap

**Consequences:**
- SQLite means single-writer — concurrent ballot entry (Milestone 8) needs care, but PocketBase handles WAL mode
- No horizontal scaling — single instance only, which is fine for this scale
- Vendor lock-in to PocketBase API format — acceptable given the project scope
- Migrations are version-controlled; data is local-only (never committed)
