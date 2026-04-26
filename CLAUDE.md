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

<!-- TODO: fill in after Phase A scaffolding — add web/ dev commands (SvelteKit dev server, build, test, check) and update npm run dev description to cover both servers -->

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

<!-- TODO: fill in after Phase A scaffolding — add Vitest unit test commands for web/ -->

## Frontend Architecture

<!-- TODO: fill in after Phase A scaffolding — SvelteKit patterns (server load, form actions, hooks.server.ts, auth via httpOnly cookies), file structure under web/src/, shadcn-svelte component usage -->

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

<!-- TODO: fill in after Phase A scaffolding — SvelteKit dev server URL -->
