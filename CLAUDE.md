# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

# rivcomocktrial

Admin-side competition management tool + public-facing site for Riverside County Mock Trial.

## Stack

- **Frontend:** SvelteKit + TypeScript (Svelte 5)
- **Backend:** PocketBase v0.36.x — SQLite-based backend-as-a-service
- **Deployment:** fly.io via Docker. One container runs PocketBase, the SvelteKit
  Node server (adapter-node), and Caddy under tini.
- **Routing:** Caddy listens on port 8090 and reverse-proxies `/api/*` and `/_/*`
  to PocketBase (127.0.0.1:8091); everything else goes to the SvelteKit Node
  server (127.0.0.1:3000).
- **CI/CD:** GitHub Actions deploys to fly.io on push to main

## Project Layout

- `web/` — SvelteKit app (in progress; replaces `frontend/`)
- `frontend/` — Elm Land app (legacy; kept for algorithm tests and domain reference)
- `backend/` — PocketBase (Dockerfile, migrations, hooks)
- `fly.toml` — fly.io config (root level)
- `docker-compose.yml` — local dev (PocketBase in Docker)
- `docker-compose.test.yml` — isolated test PocketBase (port 28090, named volume)

## Conventions

- PocketBase migrations live in `backend/pb_migrations/` (JS format, version-controlled)
- PocketBase hooks live in `backend/pb_hooks/` (version-controlled)
- PocketBase data (`pb_data/`) is gitignored — never commit SQLite files
- SvelteKit builds as a Node server (adapter-node) served by Caddy alongside
  PocketBase — not copied into `pb_public/`
- No custom Go extensions — using PocketBase out-of-the-box

## Dev Commands

- `npm run pb:start` — start dev PocketBase in background (port 8090)
- `npm run pb:stop` — stop dev PocketBase
- `npm run pb:dev` — start dev PocketBase with watch (auto-restarts on migration/hook changes, runs in foreground)
- `npm run pb:kill` — kill watch process and stop dev PocketBase
- `npm run pb:test:up` — start the **isolated test PocketBase** (port 28090, separate Docker volume)
- `npm run pb:test:down` — stop the test PocketBase and wipe its data volume
- `npm run pb:test:reset` — full reset of the test PocketBase
- `npm run e2e` — run Playwright e2e tests against the test PocketBase (auto-starts test container, builds + previews SvelteKit on port 4173, sources `.env.test`)

SvelteKit dev commands (run from `web/`):

- `npm run dev` — start SvelteKit dev server (http://localhost:5173)
- `npm run build` — production build
- `npm run check` — svelte-check type checking
- `npm run test:unit` — Vitest unit tests
- `npm run test:smoke:staging` — Playwright smoke tests against staging
- `npm run test:smoke:prod` — Playwright smoke tests against production
- `npm run lint` — ESLint + Prettier check
- `npm run format` — Prettier format

To run both servers: `npm run pb:dev` from repo root (foreground), then `cd web && npm run dev` in a second terminal.

## Operations

- Backups: Fly volume snapshots, 14-day retention. See `docs/backups.md` for the recovery procedure.

## Development Workflow

1. **Worktree** — create a worktree at `.claude/worktrees/<task>` on branch
   `feat/<topic>` (or `fix/`, `docs/`, `ci/`, `refactor/`). Never commit to main.
2. **Plan** — use plan mode to design the approach
3. **Issue** — create a GitHub issue with the plan (clears context, sets benchmarks)
4. **Implement** — TDD by default (ask first); red/green/refactor with real local PocketBase
5. **Document** — update README, `docs/`, and CHANGELOG on the feature branch before
   opening the PR. All docs ship with the code, never as a post-merge chore commit.
6. **Commit & PR** — use `/ship` to commit, push, and open the PR
7. **Merge** — merge PR to main
8. **Tag** — at milestones only (not every PR)
9. **Update memory** — capture patterns, decisions, and lessons learned

## Testing

No mocks. All integration tests hit a real local PocketBase.

### Two PocketBase containers

Two PocketBase containers run on different ports, each with its own
SQLite volume. Tests must never touch the dev volume.

| Container | Compose file | Host port | Volume | Used by |
|---|---|---|---|---|
| Dev | `docker-compose.yml` | 8090 | `./backend/pb_data` (mounted) | `npm run web:dev` (manual local development) |
| Test | `docker-compose.test.yml` | 28090 | `pb_test_data` (named, wipeable) | `test:hooks`, `test:schema`, `e2e` |

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
| UI e2e | `npm run e2e` | `tests/e2e/` | test (28090) | Pages, forms, browser navigation |
| Deploy smoke (staging) | `cd web && npm run test:smoke:staging` | `web/e2e/deploy-smoke.e2e.ts` | live staging | Read-only checks against the deployed site |
| Deploy smoke (prod) | `cd web && npm run test:smoke:prod` | `web/e2e/deploy-smoke.e2e.ts` | live production | Read-only checks against production |

All three local layers (`test:hooks`, `test:schema`, `e2e`) start the
test container automatically (via `pb:test:up`) and source `.env.test`.
The e2e layer also builds and previews the SvelteKit app on port 4173
with `PB_INTERNAL_URL` pointed at the test container, so SSR talks to
the test PB and never the dev container. To wipe the test database
between runs: `npm run pb:test:reset`.

**Pick the lowest layer that reaches the behavior under test.** Hook
behavior does not need a browser — use `test:hooks`. Only reach for
`e2e` when the test must load a page or navigate.

### Test cleanup

Hook and e2e tests that create coach/team records clean up by
collection class in dependency order (`join_requests → teams → users
→ tournaments`), not LIFO insertion order. The sole-coach delete
guard fires when a user delete leaves a team with no coaches, so
dependent records must be deleted first regardless of when they were
tracked. Cleanup throws on any failure — silent orphan accumulation
is a bug, not a feature.

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

Two roles: superuser (admin) and coach. Login is at `/login` and handles both
roles: it tries `_superusers` first, then `users`. Successful superuser login
redirects to `/admin`; coach login redirects to `/team`. The `/admin/*` layout
guard redirects unauthenticated visitors to `/login?next=<path>`. The existing
`auth_guard.pb.js` hook still gates coach login on `status=approved`.

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
