# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# rivcomocktrial

Admin-side competition management tool + public-facing site for Riverside County Mock Trial.

## Stack

- **Frontend:** Elm (elm-land v0.20.1) — file-based routing SPA
- **Backend:** PocketBase v0.36.x — SQLite-based backend-as-a-service
- **Deployment:** fly.io via Docker, single container serves both frontend and backend
- **CI/CD:** GitHub Actions deploys to fly.io on push to main

## Project Layout

- `frontend/` — Elm Land app (pages, layouts, API modules)
- `backend/` — PocketBase (Dockerfile, migrations, hooks)
- `fly.toml` — fly.io config (root level)
- `docker-compose.yml` — local dev (PocketBase in Docker)

## Conventions

- PocketBase migrations live in `backend/pb_migrations/` (JS format, version-controlled)
- PocketBase hooks live in `backend/pb_hooks/` (version-controlled)
- PocketBase data (`pb_data/`) is gitignored — never commit SQLite files
- Frontend builds are copied into PocketBase's `pb_public/` via multi-stage Docker build
- No custom Go extensions — using PocketBase out-of-the-box

## Dev Commands

- `npm run dev` — instructions for running both servers
- `npm run pb:start` — start PocketBase in background
- `npm run pb:stop` — stop PocketBase
- `npm run pb:dev` — start PocketBase with watch (auto-restarts on migration/hook changes, runs in foreground)
- `npm run pb:kill` — kill watch process and stop PocketBase
- `npm run fe:dev` — start elm-land dev server
- `npm run fe:build` — build frontend for production
- `npm run fe:test` — run Elm unit tests (elm-test)
- `npm run fe:review` — run elm-review linter
- `npm run e2e` — run Playwright end-to-end tests (requires local PocketBase running, uses 1Password for credentials)

## Development Workflow

1. **Plan** — use plan mode to design the approach
2. **Issue** — create a GitHub issue with the plan (clears context, sets benchmarks)
3. **Implement** — TDD by default (ask first); red/green/refactor with real local PocketBase
4. **Document** — update README and `docs/` so documentation is current with the code
5. **Commit & PR** — commit, push branch, open PR
6. **Merge** — merge PR to main
7. **Tag** — at milestones only (not every PR)
8. **Update memory** — capture patterns, decisions, and lessons learned

## UI Conventions

Read and follow `docs/ui-conventions.md` for all frontend UI work.
This is mandatory — do not write view code without consulting it first.

## Testing

- Unit tests: `npm run fe:test` — targets `frontend/tests/`; run a single file with `cd frontend && npx elm-test tests/MyTest.elm`
- E2E tests: `npm run e2e` — Playwright, targets port 8090 (production build). Dev server (port 1234) does not work with Playwright.
- No mocks. Integration tests hit real local PocketBase.

## Frontend Architecture

### Port-based PocketBase client (ADR-010, ADR-011)

All PocketBase operations go through Elm ports to JS, never direct HTTP from Elm.

- `frontend/src/Pb.elm` — port helpers (`adminList`, `adminCreate`, `publicList`, etc.)
- `frontend/src/Api.elm` — types, decoders, encoders only (no HTTP, no ports)
- `frontend/src/Effect.elm` — `portSend`, `incoming`, `saveCoachToken`
- `frontend/src/interop.js` — two SDK instances: `pbAdmin` (superuser) and `pb` (coach/public)

Auth tokens are in-memory only (no SDK auto-persistence); manually saved to `localStorage` under `adminToken`, `coachToken`, `coachUser`. Both are restored in `flags` on page load.

### Page module pattern

Every page follows this structure:

```elm
page : Auth.User -> Shared.Model -> Route () -> Page Model Msg

-- Model has RemoteData for fetched collections, form state as a sum type
-- Msg has PbMsg Json.Decode.Value as the single port response handler
-- update routes on Pb.responseTag value, then decodes with Pb.decodeList/decodeRecord
-- subscriptions = Pb.subscribe PbMsg
```

`Pages/Admin/Tournaments.elm` is the canonical reference implementation.

### UI helpers

`frontend/src/UI.elm` is the sole view helper module. Use its helpers (`titleBar`, `dataTable`, `primaryButton`, `textField`, etc.) instead of writing raw DaisyUI/Tailwind class strings in pages. If a helper you need is missing, add it to `UI.elm` first.

### Layouts

- `Layouts.Admin` — admin pages (auth-gated to superuser)
- `Layouts.Team` — coach pages (auth-gated to approved coach)
- `Layouts.Public` — unauthenticated pages

### Domain design

Domain modules use opaque types with smart constructors returning `Result (List Error.Error) a`. Prefer sum types over booleans for state. See `docs/decisions.md` for ADRs and `docs/domain-audit.md` for the full inventory.

## Backend Architecture

PocketBase hooks in `backend/pb_hooks/` run on record lifecycle events:

- `auth_guard.pb.js` — blocks coach login until status=approved
- `registration.pb.js` — handles coach registration side effects
- `eligibility.pb.js` — eligibility request logic
- `withdrawal.pb.js` — team withdrawal logic

Migrations in `backend/pb_migrations/` use JS format. Name new migrations with a Unix timestamp prefix (check the latest file for the current sequence).

## Key URLs (local dev)

- PocketBase admin: http://localhost:8090/_/
- PocketBase API: http://localhost:8090/api/
- Elm Land dev server: http://localhost:1234
