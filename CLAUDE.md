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

- `npm run pb:start` — start dev PocketBase in background (port 8090)
- `npm run pb:stop` — stop dev PocketBase
- `npm run pb:dev` — start dev PocketBase with watch (auto-restarts on migration/hook changes, runs in foreground)
- `npm run pb:kill` — kill watch process and stop dev PocketBase
- `npm run pb:test:up` — start the **isolated test PocketBase** (port 28090, separate Docker volume)
- `npm run pb:test:down` — stop the test PocketBase and wipe its data volume
- `npm run pb:test:reset` — full reset of the test PocketBase
- `npm run e2e` — run Playwright e2e tests (requires dev PocketBase running, sources `.env.test` for credentials)

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

No mocks. All integration tests hit a real local PocketBase.

### Two PocketBase containers

Two PocketBase containers run on different ports, each with its own
SQLite volume. Tests must never touch the dev volume.

| Container | Compose file | Host port | Volume | Used by |
|---|---|---|---|---|
| Dev | `docker-compose.yml` | 8090 | `./backend/pb_data` (mounted) | `npm run dev`, `npm run e2e` |
| Test | `docker-compose.test.yml` | 28090 | `pb_test_data` (named, wipeable) | `test:hooks`, `test:schema` |

The test container auto-seeds the superuser via its compose `command:`
using credentials from `.env.test` (single source of truth for test
admin email/password and the test PB URL). The production
`bootstrap_superuser.pb.js` hook is not used for tests — it stays
focused on production cold start.

### Testing layers

| Layer | Command | Location | Container | Use for |
|---|---|---|---|---|
| Schema | `npm run test:schema` | `web/src/lib/schema/` | test (28090) | Migration-produced rule strings |
| Hook integration | `npm run test:hooks` | `web/src/lib/hooks/` | test (28090) | Pre/post hook behavior via real PB API |
| UI e2e | `npm run e2e` | `tests/e2e/` | dev (8090) | Pages, forms, browser navigation |

`test:hooks` and `test:schema` start the test container automatically
(via `pb:test:up`) and source `.env.test`. To wipe the test database
between runs: `npm run pb:test:reset`.

**Pick the lowest layer that reaches the behavior under test.** Hook
behavior does not need a browser — use `test:hooks`. Only reach for
`e2e` when the test must load a page or navigate.

### Hook test cleanup

`web/src/lib/hooks/registration.spec.ts` cleans up by collection class
in dependency order (`join_requests → teams → users → tournaments`),
not LIFO insertion order. The sole-coach delete guard fires when a
user delete leaves a team with no coaches, so dependent records must
be deleted first regardless of when they were tracked. Cleanup throws
on any failure — silent orphan accumulation is a bug, not a feature.

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
