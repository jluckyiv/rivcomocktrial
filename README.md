# Riverside County Mock Trial

Admin-side competition management tool and public-facing
site for the Riverside County Mock Trial Invitational,
replacing the current spreadsheet/email/Google Forms
workflow.

## Stack

- **Frontend:** [SvelteKit](https://kit.svelte.dev) +
  Svelte 5 + TypeScript +
  [Tailwind CSS](https://tailwindcss.com) v4 +
  [shadcn-svelte](https://www.shadcn-svelte.com)
- **Backend:** [PocketBase](https://pocketbase.io)
  v0.36.3 — SQLite-based backend-as-a-service (JS
  migrations and hooks, no custom Go). PocketBase
  exposes a server-side JSVM (Goja) for hooks and
  migrations; these are *not* browser JavaScript and
  have nothing to do with the PocketBase JS SDK.
- **Email:** [Resend](https://resend.com) (production) /
  [Mailpit](https://mailpit.axllent.org) (local dev)
- **Deployment:** [fly.io](https://fly.io) via Docker —
  single container runs PocketBase, the SvelteKit Node
  bundle, and a Caddy reverse proxy
- **CI/CD:** GitHub Actions auto-deploys staging on push
  to main; production deploys via manual
  `workflow_dispatch`

## Project Layout

```
├── web/               SvelteKit app
│   ├── src/
│   │   ├── routes/    File-based routing
│   │   ├── lib/
│   │   │   ├── domain/   Pure domain logic + Vitest tests
│   │   │   ├── components/
│   │   │   ├── pocketbase.ts
│   │   │   └── pocketbase-types.ts  (generated)
│   │   ├── hooks.server.ts  Per-request PocketBase client
│   │   └── app.d.ts   App.Locals declaration
│   └── vite.config.ts
├── backend/           PocketBase
│   ├── pb_migrations/ JS migrations (VCS) — run inside
│   │                  PocketBase's server-side JSVM,
│   │                  not the browser
│   ├── pb_hooks/      JS hooks (VCS) — same JSVM
│   ├── pb_seed/       Seed data (schools, admins)
│   ├── pb_data/       SQLite (gitignored)
│   ├── Dockerfile     Production build
│   └── Dockerfile.dev Local dev container
├── docs/              Architecture decisions, workflows
├── fly.toml           fly.io config (production, future)
├── fly.staging.toml   fly.io config (staging)
├── .dockerignore      Excludes node_modules from build
├── docker-compose.yml Local dev (Docker — PB + Mailpit)
└── package.json       Dev scripts
```

## Local Development

### Prerequisites

- Node.js v20+
- Docker

### Running

```bash
# Terminal 1: PocketBase + Mailpit (auto-restarts on
# migration/hook changes)
npm run pb:dev

# Terminal 2: SvelteKit dev server
npm run web:dev
```

### URLs

| Service             | URL                       |
|---------------------|---------------------------|
| SvelteKit dev       | http://localhost:5173      |
| PocketBase API      | http://localhost:8090/api/ |
| PocketBase admin UI | http://localhost:8090/_/   |
| Mailpit (email UI)  | http://localhost:8025      |

### Creating a superuser

On first run, create a PocketBase superuser:

```bash
docker compose exec pocketbase \
  pocketbase superuser upsert \
  admin@example.com yourpassword \
  --dir=/pb/pb_data
```

### All scripts

| Script              | Description                  |
|---------------------|------------------------------|
| `npm run pb:dev`         | PocketBase + Mailpit (watch)  |
| `npm run pb:start`       | PocketBase in background      |
| `npm run pb:stop`        | Stop PocketBase               |
| `npm run pb:kill`        | Kill watch + stop             |
| `npm run pb:seed-districts` | Seed districts from districts.json |
| `npm run pb:seed-schools`   | Seed schools (requires districts)  |
| `npm run pb:seed-admins`    | Seed superusers from admins.json   |
| `npm run web:dev`        | SvelteKit dev server          |
| `npm run web:build`      | Build frontend for prod       |

## Email

### Local development

Mailpit runs automatically with `npm run pb:dev`. It
intercepts all outbound email — nothing is delivered.
Browse captured messages at http://localhost:8025.

### Production (Resend)

Transactional email goes through
[Resend](https://resend.com) using the custom domain
`rivcomocktrial.org`.

**One-time domain setup** (DNS verification pending):

1. Add domain `rivcomocktrial.org` in the Resend
   dashboard.
2. Copy the DNS records Resend provides (SPF, DKIM,
   DMARC) and add them at your registrar.
3. Wait for Resend to verify (usually minutes).
4. Create a Resend API key and set it as a fly secret:

```bash
fly secrets set SMTP_PASSWORD=re_xxxxxxxxxxxx \
  --app rivcomocktrial-staging
```

Non-secret SMTP settings (host, port, sender address)
are already in `fly.staging.toml` under `[env]`.
PocketBase reads all SMTP settings from env vars on
startup via `backend/pb_hooks/smtp_config.pb.js`.

## Seeding Admins

Add admin email addresses to `backend/pb_seed/admins.json`:

```json
[
  { "email": "admin@rivcomocktrial.org" }
]
```

Then run (PocketBase must be running):

Districts and schools seed automatically on first startup via
PocketBase migrations — no manual step needed.

```bash
npm run pb:seed-admins
```

Each admin is created with a random password they never need —
they log in via magic link. Safe to re-run; existing accounts
are skipped.

For staging, pass `PB_URL` and credentials directly:

```bash
PB_URL=https://rivcomocktrial-staging.fly.dev \
PB_ADMIN_EMAIL=you@example.com \
PB_ADMIN_PASSWORD=yourpassword \
node backend/pb_seed/seed_admins.js
```

## Deployment

Single-origin Caddy reverse proxy fronts both apps in one container
on fly.io. Caddy listens on `:8090` (matching the PocketBase docs
port). Internally it routes `/api/*` and `/_/*` to PocketBase on
`127.0.0.1:8091` and everything else to the SvelteKit Node bundle on
`localhost:3000`. See [ADR-015](docs/decisions.md) for the
realtime/cookie rationale.

### Environments

| Env        | App                       | URL                                      | Config            |
|------------|---------------------------|------------------------------------------|-------------------|
| Staging    | `rivcomocktrial-staging`  | https://rivcomocktrial-staging.fly.dev/  | `fly.staging.toml`|
| Production | `rivcomocktrial`          | https://rivcomocktrial.org/              | `fly.toml`        |

Staging data is disposable. Production holds real data.

### Pipeline

- **Staging** auto-deploys on push to `main` when `web/`, `backend/`,
  fly configs, or `.dockerignore` change.
- **Production** deploys via manual GitHub Actions
  `workflow_dispatch`. The `production` GitHub Environment is gated
  by required reviewer.

To deploy production: GitHub → Actions → "Deploy to fly.io" → Run
workflow → target `production`. Approve the environment prompt.

### Secrets

Non-secret env (SMTP host, sender, port, ORIGIN) lives in the fly
toml files. Secrets are set per-app via `fly secrets`:

```bash
# Staging
fly secrets set SMTP_PASSWORD=re_xxxxxxxxxxxx \
  --app rivcomocktrial-staging

# Production
fly secrets set SMTP_PASSWORD=re_xxxxxxxxxxxx \
  --app rivcomocktrial
```

### Creating a superuser on a deployed env

```bash
fly ssh console --config fly.staging.toml -C \
  "pocketbase superuser upsert \
  admin@example.com yourpassword \
  --dir=/pb/pb_data"
```

(Use `--config fly.toml` for production.)

## Documentation

- [Competition Workflow](docs/competition-workflow.md)
  — end-to-end competition sequence and rules
- [Architecture Decisions](docs/decisions.md) — key
  technical choices and rationale

## Development Workflow

1. **Plan** — design the approach (plan mode)
2. **Implement** — TDD with real local PocketBase
   (no mocks)
3. **Document** — update README and `docs/` as you go
4. **Commit & PR** — `feat/<topic>` or `fix/<topic>`
   branch, PR to main
5. **Tag** — patch bump every PR; minor at milestones
