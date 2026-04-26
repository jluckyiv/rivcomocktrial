# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# rivcomocktrial

Admin-side competition management tool + public-facing site for Riverside County Mock Trial.

## Stack

- **Frontend:** SvelteKit + TypeScript (Svelte 5)
- **Backend:** PocketBase v0.36.x — SQLite-based backend-as-a-service
- **Deployment:** fly.io via Docker, single container serves both frontend and backend
- **CI/CD:** GitHub Actions deploys to fly.io on push to main

## Project Layout

- `web/` — SvelteKit app (in progress; replaces `frontend/`)
- `frontend/` — Elm Land app (legacy; kept for algorithm tests and domain reference)
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

- `npm run pb:start` — start PocketBase in background
- `npm run pb:stop` — stop PocketBase
- `npm run pb:dev` — start PocketBase with watch (auto-restarts on migration/hook changes, runs in foreground)
- `npm run pb:kill` — kill watch process and stop PocketBase
- `npm run e2e` — run Playwright end-to-end tests (requires local PocketBase running, uses 1Password for credentials)

SvelteKit dev commands (run from `web/`):

- `npm run dev` — start SvelteKit dev server (http://localhost:5173)
- `npm run build` — production build
- `npm run check` — svelte-check type checking
- `npm run test:unit` — Vitest unit tests
- `npm run test:e2e` — Playwright end-to-end tests
- `npm run lint` — ESLint + Prettier check
- `npm run format` — Prettier format

To run both servers: `npm run pb:dev` from repo root (foreground), then `cd web && npm run dev` in a second terminal.

## Development Workflow

1. **Plan** — use plan mode to design the approach
2. **Issue** — create a GitHub issue with the plan (clears context, sets benchmarks)
3. **Implement** — TDD by default (ask first); red/green/refactor with real local PocketBase
4. **Document** — update README and `docs/` so documentation is current with the code
5. **Commit & PR** — commit, push branch, open PR
6. **Merge** — merge PR to main
7. **Tag** — at milestones only (not every PR)
8. **Update memory** — capture patterns, decisions, and lessons learned

## Testing

- E2E tests: `npm run e2e` — Playwright, targets port 8090 (production build).
- No mocks. Integration tests hit real local PocketBase.

- Unit tests: `cd web && npm run test:unit` — Vitest, targets `web/src/`
- E2E tests: `npm run e2e` from repo root — Playwright, targets port 8090 (production build).

## Frontend Architecture

### File structure

```
web/src/
  app.d.ts              — App.Locals declaration (pb, user)
  hooks.server.ts       — per-request PocketBase client; cookie auth
  lib/
    pocketbase.ts       — singleton client (client-side use only)
    pocketbase-types.ts — generated TypeScript types (pocketbase-typegen)
    components/         — shadcn-svelte components
  routes/               — file-based routing (+page.svelte, +page.server.ts)
```

### Auth

httpOnly cookies + server-side session. `hooks.server.ts` creates one
`PocketBase` client per request, loads auth from the request cookie, refreshes
if valid, and writes the cookie back on every response. Pages access
`event.locals.pb` and `event.locals.user`.

Two roles: superuser (admin) and coach. Login routes TBD (e.g. `/admin/login`,
`/login`). The existing `auth_guard.pb.js` hook still gates coach login.

### Data loading and mutations

- **Load:** `+page.server.ts` `load()` calls PocketBase via `locals.pb`.
- **Mutations:** SvelteKit form actions in `+page.server.ts`.
- **Domain logic:** plain TypeScript modules in `src/lib/domain/`.
- **Components:** shadcn-svelte primitives; Tailwind for layout and spacing.

### Types

`src/lib/pocketbase-types.ts` is auto-generated — do not edit by hand.
Regenerate with: `cd web && npx pocketbase-typegen --db ../backend/pb_data/data.db --out src/lib/pocketbase-types.ts`

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

- SvelteKit dev server: http://localhost:5173
