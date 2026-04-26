/// <reference path="../pb_data/types.d.ts" />

// Configure SMTP from environment variables on every server start.
// No-ops if SMTP_HOST is unset (local dev without Mailpit, CI).
//
// Calls e.next() first so the app is fully bootstrapped before we
// touch settings. Does not call $app.save(settings): Settings is not
// a Model and passing it to save() caused a nil pointer dereference in
// PocketBase v0.36 (core/db.go:314). In-memory modification is enough
// because we re-apply on every startup from env vars.
onBootstrap((e) => {
    e.next();

    const host = $os.getenv("SMTP_HOST");
    if (!host) return;

    const s = $app.settings();
    s.smtp.enabled = true;
    s.smtp.host = host;
    s.smtp.port = parseInt($os.getenv("SMTP_PORT") || "587");
    s.smtp.username = $os.getenv("SMTP_USERNAME") || "";
    s.smtp.password = $os.getenv("SMTP_PASSWORD") || "";
    s.smtp.tls = $os.getenv("SMTP_TLS") === "true";
    s.meta.senderAddress = $os.getenv("SMTP_SENDER_ADDRESS") || "";
    s.meta.senderName = $os.getenv("SMTP_SENDER_NAME") || "Riverside County Mock Trial";
});
