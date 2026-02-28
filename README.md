# Riverside County Mock Trial

Admin-side competition management tool and public-facing site for the Riverside County Mock Trial Invitational, replacing the current spreadsheet/email/Google Forms workflow.

## Stack

- **Frontend:** [Elm Land](https://elm.land) v0.20.1 — file-based routing SPA with [Bulma](https://bulma.io) v1.0.4 CSS
- **Backend:** [PocketBase](https://pocketbase.io) v0.36.3 — SQLite-based backend-as-a-service (JS migrations and hooks, no custom Go)
- **Deployment:** [fly.io](https://fly.io) via Docker — single container serves both frontend and backend
- **CI/CD:** GitHub Actions deploys to fly.io on push to main

## Project Layout

```
├── frontend/          Elm Land app (pages, layouts, API modules)
│   ├── src/
│   │   ├── Pages/     File-based routing (Home_, Admin/*)
│   │   ├── Layouts/   Shared layouts (Admin navbar)
│   │   ├── Api.elm    PocketBase HTTP client
│   │   └── Shared/    App-wide state (auth token)
│   └── elm-land.json  Proxy config, Bulma CDN
├── backend/           PocketBase
│   ├── pb_migrations/ JS migration files (version-controlled)
│   ├── pb_hooks/      JS hook scripts (version-controlled)
│   ├── pb_data/       SQLite database (gitignored, local only)
│   ├── Dockerfile     Production multi-stage build
│   └── Dockerfile.dev Local dev container
├── docs/              Roadmap, architecture decisions, domain docs
├── fly.toml           fly.io deployment config
├── docker-compose.yml Local dev (PocketBase in Docker)
└── package.json       Dev scripts
```

## Local Development

### Prerequisites

- Node.js v18+
- Docker

### Running

```bash
# Terminal 1: Start PocketBase (auto-restarts on migration/hook changes)
npm run pb:dev

# Terminal 2: Start Elm Land dev server
npm run fe:dev
```

### URLs

| Service              | URL                         |
|----------------------|-----------------------------|
| Elm Land dev server  | http://localhost:1234        |
| PocketBase API       | http://localhost:8090/api/   |
| PocketBase admin UI  | http://localhost:8090/_/     |

### Creating a superuser

On first run, create a PocketBase superuser:

```bash
docker compose exec pocketbase pocketbase superuser upsert admin@example.com yourpassword --dir=/pb/pb_data
```

### All scripts

| Script            | Description                                    |
|-------------------|------------------------------------------------|
| `npm run dev`     | Prints instructions for running both servers   |
| `npm run pb:dev`  | Start PocketBase with watch (auto-restart)     |
| `npm run pb:start`| Start PocketBase in background                 |
| `npm run pb:stop` | Stop PocketBase                                |
| `npm run pb:kill` | Kill watch process and stop PocketBase         |
| `npm run fe:dev`  | Start Elm Land dev server                      |
| `npm run fe:build`| Build frontend for production                  |

## Documentation

- [Roadmap](docs/roadmap.md) — milestones, domain context, open questions
- [Architecture Decisions](docs/decisions.md) — key technical choices and rationale

## Development Workflow

1. **Plan** — design the approach (plan mode)
2. **Issue** — create a GitHub issue with the plan
3. **Implement** — TDD by default with real local PocketBase (no mocks)
4. **Document** — update README and `docs/` so documentation stays current
5. **Commit & PR** — branch per milestone, PR to main
6. **Merge** — merge PR to main
7. **Tag** — at milestones only (v0.1.0, v0.2.0, etc.)
