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

## Key URLs (local dev)

- PocketBase admin: http://localhost:8090/_/
- PocketBase API: http://localhost:8090/api/
- Elm Land dev server: http://localhost:1234
