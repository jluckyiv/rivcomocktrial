/// <reference path="../pb_data/types.d.ts" />

// Auto-create one baseline superuser at startup if BOOTSTRAP_SUPERUSER_EMAIL
// and BOOTSTRAP_SUPERUSER_PASSWORD are set. Idempotent — skips if a
// superuser with that email already exists.
//
// Intended for fresh fly volumes (production cold start, env rebuild,
// disaster recovery) so the first deploy doesn't require a manual
// `fly ssh console -C "pocketbase superuser upsert ..."`.
//
// Local dev: leave the env vars unset; the hook is a no-op. Existing
// `pb:seed-admins` continues to work for non-bootstrap admin seeding.
//
// Configure via fly secrets sourced from 1Password — see
// `scripts/seed-prod-bootstrap.sh`.
onBootstrap((e) => {
    e.next();

    const email = $os.getenv("BOOTSTRAP_SUPERUSER_EMAIL");
    const password = $os.getenv("BOOTSTRAP_SUPERUSER_PASSWORD");
    if (!email || !password) {
        return;
    }

    try {
        $app.findFirstRecordByFilter(
            "_superusers",
            "email = {:email}",
            { email }
        );
        // Already exists — leave it alone.
        return;
    } catch (_) {
        // findFirstRecordByFilter throws on no match → create path.
    }

    const collection = $app.findCollectionByNameOrId("_superusers");
    const record = new Record(collection);
    record.set("email", email);
    record.set("password", password);

    try {
        $app.save(record);
        console.log("[bootstrap] created superuser " + email);
    } catch (err) {
        console.error("[bootstrap] failed to create superuser " + email + " — " + err);
    }
});
