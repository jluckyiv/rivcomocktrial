# PocketBase v0.36 JSVM Notes

Practical notes on writing PocketBase hooks and migrations
in JavaScript. The JSVM is Goja-based and has surprising
edges that have bitten this project; this is the
short list of patterns that actually work.

## Hook callbacks run in a fresh VM context

Each hook callback runs in its own VM at trigger time.
**Top-level `const` declarations from the hook file are NOT
visible inside the callback.** If you reference them, you'll
see `ReferenceError: NAME is not defined at /pb.js:LINE` in
the PB error log — and it usually surfaces to the client as
a generic "Something went wrong while processing your
request." 400.

**Wrong:**

```js
const STATUS_REGISTRATION = "registration";

onRecordCreateRequest((e) => {
  // ReferenceError at runtime
  if (e.record.get("status") === STATUS_REGISTRATION) { ... }
}, "users");
```

**Right:** put shared values in a module file (leading
underscore so PB doesn't auto-load it as a hook), and
`require()` it inside each callback.

```js
// backend/pb_hooks/_constants.js
module.exports = {
  TOURNAMENT_STATUS: { REGISTRATION: "registration", ... },
};
```

```js
// backend/pb_hooks/registration.pb.js
onRecordCreateRequest((e) => {
  const { TOURNAMENT_STATUS } = require(`${__hooks}/_constants.js`);
  // ...
}, "users");
```

`__hooks` is a JSVM-provided global pointing to the hooks
directory.

## Use `unmarshal()` for nested struct fields

Direct property assignment on PB Go structs through JSVM is
unreliable and panics in some cases. Use `unmarshal()` to
merge changes:

```js
// Wrong — panics PB at startup
collection.authAlert.enabled = false;
app.save(collection);

// Right
unmarshal({ authAlert: { enabled: false } }, collection);
app.save(collection);
```

Same rule applies to settings:

```js
// Don't do this in a hook — has been observed to crash
$app.save($app.settings()); // even with no changes
```

For application-wide settings (SMTP, etc.), prefer
configuring via the admin UI on first deploy or using
PocketBase's native env-var support, not via hooks.

## Auto-generated migrations from the admin UI

Toggling a collection setting in the admin UI generates a
migration like `1777193384_updated_users.js`. These work but
have two issues:

1. They use the **legacy collection ID** (e.g.
   `_pb_users_auth_`) rather than the friendly name
2. The filename includes the timestamp but no description

After you toggle something in the admin UI:

1. Find the auto-generated file in
   `backend/pb_migrations/`
2. Replace it with a hand-written migration using
   `findCollectionByNameOrId("users")` and a clear filename
   (e.g. `1800000007_disable_login_alerts.js`)
3. Add a comment explaining **why** the change was made
4. Delete the auto-generated file

PB tracks applied migrations by filename, so the
hand-written replacement runs once on environments that
haven't seen the auto-generated version yet, and the
auto-generated record (if it exists in `_migrations`)
becomes a harmless orphan. Idempotent migrations are safe
to re-run.

## `BadRequestError` from a hook

Throwing `BadRequestError("message")` returns HTTP 400 with
the message in the response body. The PocketBase JS SDK on
the client side surfaces this as `ClientResponseError` with
`status: 400` and `message: "message"`.

```js
onRecordCreateRequest((e) => {
  if (badThing) {
    throw new BadRequestError("Useful explanation for the user.");
  }
  return e.next();
}, "users");
```

If the message disappears and the client sees a generic
error instead, the cause is usually #1 above (a
`ReferenceError` in the same callback masking the throw).

## `findRecordsByFilter` parameter binding

```js
$app.findRecordsByFilter(
  "tournaments",
  "status = {:status}",
  "-created", // sort
  2, // limit
  0, // offset
  { status: "registration" } // params
);
```

Params object can be a single argument; multiple param
objects are spread.

## Smoke check after touching backend

After any change to `backend/pb_hooks/` or
`backend/pb_migrations/`, restart PB and watch the docker
log for panics:

```bash
npm run pb:kill && npm run pb:dev
```

A clean startup ends with `Server started at
http://0.0.0.0:8090`. Anything else — silence, partial
output, a Go panic stack — means the change broke
something.

## Hook function names (v0.36)

- Before-create validation: `onRecordCreateRequest`
  (NOT `onRecordBeforeCreateRequest` — that name does
  not exist in v0.36 and crashes on load)
- Always `return e.next()` from a successful
  `onRecordCreateRequest` handler
- After-create side effects: `onRecordAfterCreateSuccess`
- Before-auth: `onRecordAuthRequest`
- After-update: `onRecordAfterUpdateSuccess`
- After-delete: `onRecordAfterDeleteSuccess`

## When PB crashes at startup

The JSVM panics rarely but spectacularly. If
`docker compose logs pocketbase` shows a Goja stack trace
during bootstrap:

1. Identify which hook or migration is running (check the
   trace for filenames near `goja.RunProgram`)
2. Rename the offending file to `.disabled` to confirm it's
   the culprit
3. Either rewrite to avoid the panic (often `unmarshal()`
   instead of property assignment) or move the work to the
   admin UI

Disabled files: keep the `.pb.js.disabled` suffix so they
don't load, and link the open issue tracking the rewrite
in the file's header comment.

## See also

- [decisions.md](decisions.md) — architectural decisions
  for the project as a whole
- Issues #146, #147 — current JSVM-related backlog
