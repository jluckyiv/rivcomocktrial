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
- [direnv](https://direnv.net/) (recommended) — auto-loads `.env.local`

### Credentials (`.env.local`)

Scripts and smoke tests read credentials from environment
variables. Populate them once into `.env.local` and direnv
will load them automatically every time you `cd` into the repo.

```bash
cp .env.local.example .env.local
# Fill in the values from 1Password (manually via the GUI),
# or — if you have the 1Password CLI signed in — pull them all
# in one shot:
scripts/load-1p-creds.sh > .env.local

direnv allow   # one-time, after the file exists
```

`.env.local` is gitignored. `op` is invoked exactly once when
you (re)generate the file; nothing else in the repo shells out
to 1Password at runtime. Re-run `scripts/load-1p-creds.sh` after
rotating any credential.

Without direnv, source the file manually before running scripts:
`set -a && . ./.env.local && set +a`.

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
| `npm run pb:seed-admins`    | Seed superusers from admins.json   |
| `npm run pb:test:up`     | Start isolated test PocketBase (port 28090) |
| `npm run pb:test:down`   | Stop test PB and wipe its data volume |
| `npm run pb:test:reset`  | Full reset of the test PB     |
| `npm run test:hooks`     | Vitest hook tests (auto-starts test PB) |
| `npm run test:schema`    | Vitest schema tests (auto-starts test PB) |
| `npm run e2e`            | Playwright e2e against test PB on 28090 (auto-starts test PB, builds + previews on 4173) |
| `npm run deploy:staging` | Trigger staging deploy via gh CLI |
| `npm run deploy:prod`    | Trigger production deploy via gh CLI |
| `npm run web:dev`        | SvelteKit dev server          |
| `npm run web:build`      | Build frontend for prod       |
| `cd web && npm run test:smoke:staging` | Read-only smoke tests against staging |
| `cd web && npm run test:smoke:prod`    | Read-only smoke tests against production |

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

To deploy production:

```bash
npm run deploy:prod
```

This runs `gh workflow run deploy.yml -f target=production`. The
`production` GitHub Environment is gated by required reviewer —
approve the prompt in GitHub Actions after triggering. You can also
trigger staging manually:

```bash
npm run deploy:staging
```

### DNS and TLS for the production domain

DNS is hosted at Namecheap (registrar nameservers
`dns1.registrar-servers.com` / `dns2.registrar-servers.com`).

#### Current live records

| Hostname                     | Type   | Value                     | Fly app                  |
|------------------------------|--------|---------------------------|--------------------------|
| `rivcomocktrial.org`         | `A`    | `66.241.124.227`          | `rivcomocktrial`         |
| `rivcomocktrial.org`         | `AAAA` | `2a09:8280:1::10b:b21f:0` | `rivcomocktrial`         |
| `www.rivcomocktrial.org`     | `A`    | `66.241.124.227`          | `rivcomocktrial`         |
| `www.rivcomocktrial.org`     | `AAAA` | `2a09:8280:1::10b:b21f:0` | `rivcomocktrial`         |
| `staging.rivcomocktrial.org` | `A`    | `66.241.124.95`           | `rivcomocktrial-staging` |
| `staging.rivcomocktrial.org` | `AAAA` | `2a09:8280:1::da:c698:0`  | `rivcomocktrial-staging` |

To re-fetch IPs: `fly ips list -a rivcomocktrial` and
`fly ips list -a rivcomocktrial-staging`.

#### Bootstrap procedure

One-time bootstrap. Re-run if the prod app is destroyed and rebuilt
under a new IP, or if the domain moves to a new registrar.

Always pass `--app rivcomocktrial` (or `--config fly.toml`) — the
repo has both `fly.toml` and `fly.staging.toml`, so flyctl won't
auto-pick one and errors out without it.

**1. Make sure the production app exists.**

```bash
fly apps list
```

If `rivcomocktrial` isn't in the list, create it (this only
registers the app — it doesn't deploy anything):

```bash
fly apps create rivcomocktrial
```

**2. Allocate fly IPs for the production app.**

```bash
fly ips list --app rivcomocktrial
```

If no IPv4 / IPv6 is shown, allocate them. Use a *shared* IPv4 to
avoid the per-IP fee unless the app needs a dedicated one:

```bash
fly ips allocate-v4 --shared --app rivcomocktrial
fly ips allocate-v6 --app rivcomocktrial
```

Re-run `fly ips list --app rivcomocktrial` and note the IPv4 (`A`
record target) and IPv6 (`AAAA` record target).

**3. Add DNS records at the registrar.**

> **Namecheap host-field gotcha:** the `Host` column wants `@` for the
> apex (`rivcomocktrial.org`), not the full domain. If you type
> `rivcomocktrial.org` in the Host field, Namecheap silently creates a
> record for `rivcomocktrial.org.rivcomocktrial.org` and queries
> return nothing.

For the apex (`rivcomocktrial.org`):

| Type   | Host | Value                     |
|--------|------|---------------------------|
| `A`    | `@`  | the IPv4 from step 2      |
| `AAAA` | `@`  | the IPv6 from step 2      |

For the staging subdomain (`staging.rivcomocktrial.org`), if the
project keeps using one:

| Type    | Host      | Value                            |
|---------|-----------|----------------------------------|
| `CNAME` | `staging` | `rivcomocktrial-staging.fly.dev` |

**4. Tell fly about the cert.**

```bash
fly certs add rivcomocktrial.org --app rivcomocktrial
```

If fly outputs an `_acme-challenge.rivcomocktrial.org` record for
DNS-01 validation, add that at the registrar too. Skip if it asks
only for the `A`/`AAAA` records you already added (HTTP-01).

**5. Wait for fly to issue the cert and verify.**

```bash
fly certs show rivcomocktrial.org --app rivcomocktrial
```

`Status: Ready` means TLS is live. DNS propagation typically takes
a few minutes; cert issuance another minute or two after that.

**6. Sanity-check from the outside.**

```bash
dig +short rivcomocktrial.org           # should match the IPv4 from step 2
dig @dns1.registrar-servers.com +short rivcomocktrial.org   # bypass resolver cache
xh https://rivcomocktrial.org/          # should return SvelteKit HTML
xh -h https://rivcomocktrial.org/_/     # should return PB admin SPA
```

Querying the registrar's nameserver directly
(`@dns1.registrar-servers.com`) is the fastest way to confirm a record
just took, before recursive resolvers update.

If any check fails, re-read fly's output from `fly certs show` —
it lists exactly what's missing.

#### `www.rivcomocktrial.org`

Currently has `A` and `AAAA` records pointing to the prod IPs and a
fly cert issued (see Current live records above). Decision pending in
[#211](https://github.com/jluckyiv/rivcomocktrial/issues/211) — leave
as alias, 301 to apex, or drop entirely. Update this section once
chosen.

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

### Bootstrapping a superuser on a fresh deploy

`backend/pb_hooks/bootstrap_superuser.pb.js` creates one baseline
superuser at PocketBase startup if `BOOTSTRAP_SUPERUSER_EMAIL` and
`BOOTSTRAP_SUPERUSER_PASSWORD` are set. Idempotent — skips if the
email already exists.

Push the credentials to fly via the helper. It reads from
`.env.local` (loaded by direnv) — `STAGING_ADMIN_*` for staging,
`PROD_ADMIN_*` for production — and runs `fly secrets set`.

```bash
# Staging
scripts/seed-prod-bootstrap.sh rivcomocktrial-staging

# Production
scripts/seed-prod-bootstrap.sh rivcomocktrial
```

Safe to re-run; the hook only creates the superuser if one with
that email doesn't already exist. The hook does **not** update an
existing superuser's password — to rotate, log in via the admin
UI or run `pocketbase superuser update` over SSH.

**Fallback** if you can't use the helper: `fly secrets set
BOOTSTRAP_SUPERUSER_EMAIL=... BOOTSTRAP_SUPERUSER_PASSWORD=... --app
<app>` directly, or SSH in and run
`pocketbase superuser upsert email password --dir=/pb/pb_data`.

## Operations

Day-2 runbook for staging and production. Replace `<app>` with
`rivcomocktrial` (prod) or `rivcomocktrial-staging` (staging).

### Tail logs

```bash
fly logs --app <app>
```

### Shell into the running machine

```bash
fly ssh console --app <app>
```

### Roll back a deploy

```bash
fly releases rollback --app <app>
```

> **Note:** PocketBase migrations are forward-only. Rolling back the
> image does **not** roll back the schema — the database stays at the
> migration level it reached before rollback.

### Manual volume snapshot (before risky migrations)

CI snapshots automatically on every deploy. To snapshot manually:

```bash
VOLUME_ID=$(fly volumes list --app <app> --json | jq -r '.[0].id')
fly volumes snapshots create "$VOLUME_ID" --app <app>
```

### Wake a stopped staging machine

Staging uses `auto_start_machines = true` — any HTTP request wakes
it. You can also start it explicitly:

```bash
fly machine start --app rivcomocktrial-staging
```

Or trigger a redeploy:

```bash
npm run deploy:staging
```

### Add a second superuser on a running app

```bash
fly ssh console --app <app>
# Inside the container:
pocketbase superuser upsert email@example.com password \
  --dir=/pb/pb_data
```

### Uptime monitor

TODO: add dashboard URL once #212 lands.

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
