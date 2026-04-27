# PocketBase Data Backup Policy

Fly.io takes automatic daily volume snapshots. This document describes
what is covered, what is not, and how to recover.

## What is backed up

Fly volume snapshots capture the entire `pb_data` volume, which
contains:

- `data.db` — the SQLite database (all records, auth, collections)
- `data.db-wal` / `data.db-shm` — SQLite write-ahead log files
- Any media files stored by PocketBase in `pb_data/storage/`

**Retention:** 14 days. Both `rivcomocktrial` (production) and
`rivcomocktrial-staging` volumes are configured with this retention.

**Frequency:** Daily automatic snapshots. Manual snapshots can be
created at any time with `fly volumes snapshots create`.

## What is NOT backed up

- **Hooks** (`backend/pb_hooks/`) — these live in git, not on the
  volume.
- **Migrations** (`backend/pb_migrations/`) — these live in git.
- **Fly secrets** — these are managed via `fly secrets` and are not
  part of the volume.
- **Application code** — the SvelteKit build and PocketBase binary
  live in the Docker image, not on the volume.
- **Anything outside `pb_data/`** — the volume only mounts that
  directory.

## Recovery procedure

Recovery forks a snapshot into a new volume, then attaches it to the
machine in place of the current volume. Expect ~5–10 minutes end to
end.

### 1. Identify the target snapshot

```sh
fly volumes snapshots list <VOLUME_ID> -a <APP_NAME>
```

Example for production:

```sh
fly volumes snapshots list vol_re1mn0n1jp612w14 -a rivcomocktrial
```

Pick the snapshot ID immediately before the data loss event.

### 2. Create a new volume from the snapshot

```sh
fly volumes create pb_data_recovery \
  --snapshot-id <SNAPSHOT_ID> \
  -a <APP_NAME> \
  -r <REGION> \
  -s 1 \
  --yes
```

Example for production (region `lax`, 1 GB volume):

```sh
fly volumes create pb_data_recovery \
  --snapshot-id vs_RpqkkjoM1Ybc5x9oaoY \
  -a rivcomocktrial \
  -r lax \
  -s 1 \
  --yes
```

Note the new volume ID from the output (e.g. `vol_NEWVOLUMEID`).

> Note: `fly volumes fork` takes a volume ID and forks from its latest
> snapshot — use `fly volumes create --snapshot-id` when you need to
> restore from a specific earlier snapshot.

### 3. Verify the new volume contains data.db (optional pre-attach check)

Run a one-shot alpine machine to inspect the volume before attaching
it to production:

```sh
fly machine run \
  --app <APP_NAME> \
  --volume <NEW_VOLUME_ID>:/pb_data \
  --restart no \
  alpine -- sleep 60
```

In a second terminal, exec in while the machine is running:

```sh
fly machine exec <MACHINE_ID> "ls -la /pb_data" --app <APP_NAME>
```

Confirm `data.db` exists with a reasonable size. Then stop and destroy
the verification machine to release the volume:

```sh
fly machine stop <MACHINE_ID> --app <APP_NAME>
fly machine destroy <MACHINE_ID> --app <APP_NAME> --force
```

### 4. Stop the production machine

```sh
fly machine list -a <APP_NAME>
fly machine stop <MACHINE_ID> -a <APP_NAME>
```

### 5. Attach the new volume to the machine

```sh
fly machine update <MACHINE_ID> \
  --mount volume=<NEW_VOLUME_ID>,path=/pb_data \
  -a <APP_NAME>
```

### 6. Restart the machine

```sh
fly machine start <MACHINE_ID> -a <APP_NAME>
```

### 7. Verify

```sh
fly logs -a <APP_NAME>
```

Confirm PocketBase starts cleanly and migrates without errors. Check
the admin UI at the app URL to verify data integrity.

### 8. Clean up the old volume (optional, after confirming recovery)

Once you are confident the recovery is good, destroy the old
(corrupted) volume:

```sh
fly volumes destroy <OLD_VOLUME_ID> -a <APP_NAME> --yes
```

### Pre-deploy snapshots (Task 10)

Once Task 10 is implemented, every deploy will create a snapshot tagged
with the commit SHA. To roll back from a bad deploy, fork the snapshot
taken immediately before that deploy rather than the most recent daily
snapshot.

---

**Rehearsal:** The recovery procedure above was rehearsed end-to-end
on `rivcomocktrial-staging` on 2026-04-26. See PR #230 for the full
transcript.
