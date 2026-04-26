/// <reference path="../pb_data/types.d.ts" />
// Disable PocketBase v0.36's built-in "new login" alert email on the
// `users` collection. With it enabled, every coach registration
// fails the entire request when SMTP is unreachable in dev — and
// even with SMTP reachable, the alert email creates noise the
// coaches don't expect.
//
// Superusers keep their alerts enabled (security-sensitive accounts).
//
// Note: direct property assignment (`collection.authAlert.enabled = false`)
// panics the JSVM in PB v0.36. Use `unmarshal` to merge changes.
migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("users");
    unmarshal({ authAlert: { enabled: false } }, collection);
    app.save(collection);
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("users");
    unmarshal({ authAlert: { enabled: true } }, collection);
    app.save(collection);
  }
);
