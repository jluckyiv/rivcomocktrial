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
- No mocks in tests — use real PocketBase instances or skip

## Dev Commands

- `npm run dev` — instructions for running both servers
- `npm run pb:dev` — start PocketBase via docker-compose
- `npm run pb:stop` — stop PocketBase
- `npm run fe:dev` — start elm-land dev server
- `npm run fe:build` — build frontend for production

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

- TDD by default — ask before skipping
- No mocks — use the real local PocketBase instance for integration tests
- Dev data is local only; migrations are version-controlled

## Key URLs (local dev)

- PocketBase admin: http://localhost:8090/_/
- PocketBase API: http://localhost:8090/api/
- Elm Land dev server: http://localhost:1234
