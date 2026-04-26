# Architecture Decisions

Decisions made during development, with context and
rationale. Newest first.

---

## ADR-015: Single-origin deploy via Caddy reverse proxy

**Date:** 2026-04-26

**Context:** The SvelteKit rebuild (ADR-014) authenticates with
httpOnly cookies set by `web/src/hooks.server.ts`. The tournament-day
admin UI will use PocketBase realtime (Server-Sent Events). The PB JS
SDK reads its auth token from a JS-accessible store to authenticate
the realtime subscription, which conflicts with our httpOnly cookie if
the SvelteKit app and PocketBase live on different origins.

Two-origin deploys (e.g. Vercel for SvelteKit + Fly for PB) force one
of:

1. Share the auth cookie at parent domain `.rivcomocktrial.org` plus a
   custom PB hook that reads it.
2. A SvelteKit endpoint that mints a short-lived realtime token for
   the SDK to use.

Both add real complexity, a class of subtle cross-origin bugs, and
SameSite=None cookies (which Safari ITP and Brave actively penalize).

**Decision:** Deploy SvelteKit and PocketBase together in a single
container behind a Caddy reverse proxy. One Fly app per environment.

Internal layout:

- PocketBase listens on `localhost:8090` (unchanged from dev).
- SvelteKit Node bundle (`adapter-node`) listens on `localhost:3000`.
- Caddy listens on `:8080` (the only port Fly's edge connects to).
- Caddy routes `/api/*` and `/_/*` to PocketBase; everything else to
  SvelteKit. `flush_interval -1` on the PB route preserves SSE.
- A small shell entrypoint supervises all three with `trap` +
  `wait -n`. `tini` reaps zombies. No s6-overlay.
- Fly terminates TLS at the edge; Caddy listens plain HTTP
  (`auto_https off`).

**Rationale:** Cookies stay SameSite=Lax because the browser, the
SvelteKit Node bundle, and the PB API all share one origin. The PB
SDK works as-is for realtime — no token-mint endpoint, no cookie
bridging. CORS is gone. One URL per environment.

**Alternatives considered:**

- **SvelteKit proxies PocketBase.** SvelteKit forwards `/api/*` and
  `/_/*` to localhost:8090 itself. Rejected: SvelteKit must proxy SSE
  and PocketBase admin assets — more edge cases than Caddy and a
  larger blast radius if SvelteKit hangs.
- **Two Fly apps.** Independent deploys, but two URLs and a CORS
  surface. Rejected for the cookie/realtime reasons above.
- **Netlify (web) + Fly (PB).** Free PR previews, simpler Dockerfile.
  Rejected for the same reasons. Revisit only if realtime is dropped
  or a token-mint endpoint becomes acceptable.

**Consequences:**

- One image, one machine, one URL per environment. PB admin UI lives
  at `rivcomocktrial.org/_/`, not a separate hostname.
- Memory tightens: Node ~80 MB + PB ~30 MB + Caddy ~20 MB on a 512 MB
  shared-cpu-1x machine. Workable; bump to `1gb` if PB OOMs under WAL
  pressure.
- Vertical scaling only. The SQLite volume is single-attach, so
  scaling to >1 machine requires splitting PB onto its own app
  (revisits this ADR). Not a concern at current load.
- Three processes to supervise. Shell + `trap` + `wait -n` is enough
  because Fly already restarts the whole machine on exit; per-service
  restart isn't needed.
- Caddy version pin (`caddy=...` in `apk add`) is worth considering if
  SSE buffering regresses on a future release.

---

## ADR-014: Elm rebuild abandoned; switching to SvelteKit

**Date:** 2026-04-25

**Supersedes:** ADR-012, ADR-013

**Context:** After months of work on an Elm rebuild of the frontend
(ADR-012), the project never reached a working end-to-end state. The
core problem was AI-assisted development: Claude Code consistently
produced React-shaped Elm (flat DTO layers, components with state,
wire types in page models) despite repeated correction. The correction
overhead compounded with each session until the refactor stalled. The
Elm architecture is sound — the problem is that the AI's training data
biases it toward patterns that are idiomatic in React/TypeScript but
anti-patterns in Elm. Correcting that bias mid-session is possible but
costly, and the corrections did not persist across sessions.

**Decision:** Abandon the Elm frontend. Rebuild the SvelteKit app at
`web/` in the repo root. Stack: SvelteKit + Svelte 5 (runes) +
TypeScript + Tailwind v4 + shadcn-svelte + Vitest + Playwright.

The existing `backend/` PocketBase instance (schema, migrations, hooks)
is unchanged. The Elm algorithm modules in `frontend/src/` serve as
domain reference and their tests in `frontend/tests/` serve as the
spec for porting to TypeScript. The `frontend/` directory stays until
the SvelteKit rebuild reaches parity, then is deleted.

Auth moves to httpOnly cookies + server-side session
(`src/hooks.server.ts`), replacing the Elm app's localStorage tokens
and dual `pbAdmin`/`pb` SDK pattern.

The persistence freeze (ADR-013) no longer applies. The backend is
open for schema changes as the SvelteKit rebuild proceeds.

**Rationale:** SvelteKit + TypeScript aligns with the AI's defaults.
The patterns the AI produces without prompting — server load functions,
form actions, `$state` runes, shadcn components — are idiomatic
SvelteKit. No correction overhead. The domain logic (algorithms,
competition rules) transfers directly to TypeScript and remains the
user's primary area of control.

**Consequences:**

- `frontend/` is legacy. Untracked Elm files in it are left alone
  until the directory is deleted wholesale.
- `docs/elm-conventions.md`, `docs/refactor-process.md`,
  `docs/ui-conventions.md`, `docs/domain-audit.md`, `docs/roadmap.md`,
  `docs/domain-roadmap.md`, and `docs/slices/` archived to
  `docs/archive/`.
- Algorithm modules ported slice by slice with Vitest tests.
- ADR-012 and ADR-013 are superseded by this decision.

---

## ADR-013: Persistence layer freeze during domain refactor

**Superseded by ADR-014.**

**Date:** 2026-04-25

**Context:** ADR-012 begins a workflow-driven rebuild
of the frontend domain layer. The rebuild needs space
to think domain-first without persistence concerns
leaking back in. Past sessions have repeatedly resolved
domain modeling tensions by reaching for the wire
format — adding fields to PocketBase migrations,
tweaking hooks, expanding `Api.elm` decoders — instead
of solving the problem in the domain layer.

**Decision:** Freeze the persistence layer for the
duration of the refactor. The following paths are
read-only:

- `backend/pb_hooks/**`
- `backend/pb_migrations/**`
- `frontend/src/Api.elm`
- `frontend/src/Pb.elm` (internals; the public surface
  stays usable)

Three-layer enforcement:

1. **Claude Code hooks** — `permissions.deny` entries
   in `.claude/settings.json` block `Edit`/`Write`/
   `MultiEdit` against frozen paths. A `PreToolUse`
   `Bash` hook (`freeze-bash-guard.sh`) blocks shell
   write idioms (`>`, `tee`, `sed -i`, `mv`, `cp`,
   `rm`) targeting frozen paths.
2. **lefthook pre-commit** — blocks any commit that
   stages a frozen path.
3. **CI** — blocks any PR whose diff touches a frozen
   path without an authorized override.

When a slice wants a wire change, the default response
is "work around it in the entity's module." The slice
stops, surfaces the proposal (failing assumption,
minimal repro, proposed change), and waits. Only if a
domain-side workaround would introduce a lying type
does the user thaw the freeze for that one commit.
Approved changes are documented as their own ADR.
Deferred changes accumulate in
`docs/persistence-debt.md` and are addressed in a
dedicated catch-up milestone after the prelim-round
slices land.

`frontend/src/Api.elm` is frozen until it has no
remaining importers (per ADR-012), at which point it
is deleted. After deletion, the deny rule for that
specific path becomes moot and is removed.
`frontend/src/Pb.elm` stays — it is the port-mechanics
module used internally by domain modules — and its
internals stay frozen.

**Override mechanism:**

- In-session: `PERSISTENCE_UNFREEZE=1` env var (the
  Bash guard checks for this).
- Commit-time: `ALLOW_FROZEN_EDIT=1 git commit ...`
  (matches the existing `ALLOW_MAIN_COMMIT=1` idiom in
  `.claude/settings.local.json`).

Both are explicit, per-invocation, and leave a trail
in the agent transcript or commit log.

**Rationale:**

- The hardest part of a domain rebuild is staying in
  the domain. Removing the path of least resistance
  (modifying the wire format) forces the work into the
  right layer.
- Defense in depth: Claude hooks block in-session,
  lefthook catches manual `git commit`, CI catches
  `--no-verify` bypasses on push.
- Per-invocation overrides preserve the user's ability
  to make legitimate persistence changes when they're
  truly necessary, without leaving a persistent flag
  that could silently disable the freeze.

**Consequences:**

- Some wire-format issues defer to a queue. The queue
  is bounded (the catch-up milestone) so debt does not
  accumulate forever.
- New PocketBase migrations cannot be added during the
  freeze. Schema changes wait for the catch-up milestone
  or trigger a freeze thaw with an ADR.
- The freeze applies to AI assistants and humans alike;
  the user must opt in deliberately when overriding.

---

## ADR-012: One module per domain concept; pages talk only to domain modules

**Superseded by ADR-014.**

**Date:** 2026-04-25

**Context:** The frontend has 50+ top-level domain
modules and 49 unit test files. The early domain work
(opaque types, smart constructors,
`Result (List Error.Error) a`,
`Assignment a = NotAssigned | Assigned a`,
`PowerMatch.elm`) is sound. The disease lives at the
page boundary:

- `frontend/src/Api.elm` is one giant flat module that
  mirrors every PocketBase table. Pages import it and
  cache `Api.X` records in their `Model`.
- Pages call `Pb.adminList { collection = "schools" }`
  and decode with `Api.schoolDecoder` inline. Pages
  know about wire shapes, collection names, and
  decoder mechanics.
- Form state is raw `String`; validation runs only on
  submit, duplicating logic that domain modules
  already encode.

The shape is React/TypeScript-style: a typed DTO layer
(`Api.elm`) that pages consume directly. Idiomatic Elm
does not work this way.

**Reference:** elm-land's official realworld example
(`github.com/elm-land/realworld-app`) and the official
guide section "Web Apps - Structure"
(`guide.elm-lang.org/webapps/structure`).

**Decision:** Adopt the elm-land convention. Each
domain concept is one module that owns everything
related to that concept:

- The type (and any related sum types).
- Smart constructors returning `Result (List Error) a`.
- Accessors.
- `decoder : Decoder X` — produces a domain value
  directly, calling the smart constructor inside and
  failing the decoder on `Err`.
- `encoder : NewX -> Encode.Value` (or equivalent for
  whatever the write payload is).
- Typed network functions:
  `list : { onResponse : RemoteData (List X) -> msg } -> Effect msg`,
  `create : { value : NewX, onResponse : ... } -> Effect msg`,
  `update`, `delete`. These wrap the existing
  `Pb.adminList`/`Pb.adminCreate`/etc. port helpers.

A page imports only the domain modules it uses (e.g.
`School`) and `Effect`. It does not import `Api` or
`Pb`. It calls `School.list { onResponse = GotSchools }`
and stores `RemoteData (List School)` in its `Model`.

The flat `Api.elm` is the React-shaped artifact. It
gets deleted, not isolated. As each page migrates, it
stops importing `Api`. When no page imports `Api`, the
module has no callers and we delete it.

**Architecture lock:** A custom elm-review rule
(`NoPbOrApiInMigratedPages`) maintains a per-page
allowlist of pages still importing `Pb` or `Api`. The
list shrinks one entry per migrated page and reaches
`[]` at refactor completion.

**Patterns we adopt (kept where they exist, added where they
do not):**

- **`Assignment a = NotAssigned | Assigned a`** for slot-like
  fields. Already in `frontend/src/Assignment.elm`. Prefer to
  `Maybe`.
- **`RemoteData a` from the `krisajenkins/remotedata` package**
  for request state. The current
  `frontend/src/RemoteData.elm` is a homebrew knockoff with
  fewer states (no `NotAsked`), a degraded error type
  (`String`, not parameterized), and only `map` defined; it
  will be replaced by the package and deleted as the first
  concrete code change of this refactor.
- **`New X` vs `X`** for unpersisted vs persisted entities
  when an entity has identity. The page form holds field state
  and runs smart constructors on input; the assembled `NewX`
  is what the encoder receives.
- **Typed IDs.** Phantom-typed `Id a` or per-entity opaque IDs
  — either is fine, picked per case. The constraint is no raw
  `String` IDs in persisted types, and the compiler must
  reject mixing IDs from different entities. (Quenneville,
  *What's in a Number?*)
- **Single source of truth via immutable relational data.**
  Going from JS objects to Elm records accidentally creates
  multiple sources of truth — nested records become
  independent copies. Store IDs in inner types and keep
  entities in top-level `Dict`s on the `Model`. Compose with
  `Dict.filter`/`Dict.intersect`/`Dict.get`. Treat the `Model`
  like a relational database. Existing modules that embed
  full records (e.g., `Pairing` carrying `Team`) will switch
  to ID-based references during their respective slices.
  (Feldman, *Immutable Relational Data*.)
- **Test scope: business logic only.** Per
  `docs/elm-conventions.md` §7. Tests target business rules
  in smart constructors, pure algorithm functions, state
  transitions, and decoder behavior on fixture JSON when the
  decoder runs business validation. They do not target
  decoder mechanics, accessors, type-system guarantees, or
  trivially-impossible branches. (Feldman, *Elm in the Spring
  2020* keynote; Kearns, *To test or not to test*.)

**Anti-patterns this ADR rules out:**

- Sidecar modules (`<Entity>Assembly.elm`,
  `<Entity>Codec.elm`, `<Entity>Form.elm`) that split
  what belongs in one module. Decoders/encoders/network
  calls live with the type.
- Components with their own `Model`/`Msg`/`update`. Per
  the official guide: "actively trying to make
  components is a recipe for disaster." View helpers
  are pure functions, named `viewX`, taking a record
  of inputs and returning `Html msg`. They live in
  `UI.elm` (existing convention) or in a new
  `Components/` directory if the helper earns its own
  file.
- Pre-splitting modules speculatively. The official
  guide says "do not plan ahead." Files grow as
  needed; we split when a sub-concept earns its own
  file.
- Mirroring PocketBase column shapes in Elm types
  (e.g. `scorer1`/`scorer2`/.../`scorer5`). The domain
  type uses `List Scorer`; the encoder writes the five
  columns; the decoder reads them. The wire shape
  stays in the encoder/decoder; it does not leak into
  the domain type.

**Rationale:**

- This is what elm-land's framework author actually
  does in the canonical example. Following the
  framework's own conventions removes guesswork and
  matches what the framework's tooling expects.
- Aligns with ADR-009 (parse, don't validate; sum
  types over booleans).
- The official guide is explicit: build modules
  around a central type; do not separate code into
  Model/Update/View files; don't make components.
- Eliminating `Api.elm` makes the bad pattern
  structurally impossible. Future work cannot
  regress to "pages cache wire-shaped records"
  because the shapes don't exist.

**Consequences:**

- Each existing domain module grows new exports as
  its slice is reached: `decoder`, `encoder`, `list`,
  `create`, `update`, `delete`. All TDD'd.
- Pages stop importing `Api` and `Pb`. The mechanical
  knowledge (collection names, port tagging) moves
  from each page into the entity's module, defined
  once.
- `Api.elm` shrinks per slice and is deleted at the
  end of the refactor.
- The `NoPbOrApiInMigratedPages` elm-review rule's
  allowlist tracks migration progress in source.
- ADR-013 freezes the wire format during this work,
  so the refactor cannot resolve domain tensions by
  changing PocketBase. Workarounds happen in the
  domain module first; freeze thaws are explicit and
  documented.

---

## ADR-011: Dual auth store isolation

**Date:** 2026-04-15

**Context:** ADR-010 introduced two PocketBase SDK
instances (`pb` for coaches, `pbAdmin` for superusers).
The default PocketBase SDK auth store is `LocalAuthStore`,
which persists the auth token to `localStorage` under the
key `pocketbase_auth`. Both instances shared that key —
a coach login would write the coach token to
`pocketbase_auth`, and on the next navigation `pbAdmin`
would load the coach token instead of the admin token,
causing all admin list/update/delete calls to fail with
401 or permission errors.

**Decision:** Both `pb` and `pbAdmin` use
`new BaseAuthStore()` (in-memory only). Auth tokens are
persisted manually to distinct `localStorage` keys and
restored in `interop.js` on page load:

- `adminToken` — superuser JWT
- `coachToken` — coach user JWT
- `coachUser` — serialized coach user record

The `flags` function reads all three from `localStorage`
at startup and passes them to Elm, so both admin and coach
sessions survive page refresh.

**Rationale:**
- In-memory auth stores can never collide, regardless of
  how many SDK instances exist
- Manual persistence gives full control over what is
  stored and under which key
- The `flags` restore path is explicit and testable —
  no SDK magic loading tokens from unexpected places

**Trade-offs:**
- More code in `interop.js` to save/restore tokens vs
  SDK auto-persistence
- Must remember to clear the right key on logout (handled
  by `SaveAdminToken null` and `SaveCoachToken null`
  port messages)

---

## ADR-010: PocketBase JS SDK as sole PB client

**Date:** 2026-03-07

**Context:** The frontend needs to communicate with
PocketBase for CRUD operations, authentication, and
eventually realtime subscriptions. The initial approach
used hand-rolled Elm HTTP calls in `Api.elm` — each
collection required list/create/update/delete functions
that manually constructed URLs, headers, and JSON
bodies.

As the app grew to 11 pages across 8 collections, this
approach didn't scale: every new collection required
~100 lines of boilerplate HTTP functions in Elm, all
reimplementing what the PocketBase JS SDK already
handles (auth token management, pagination, error
normalization, filter syntax, realtime SSE).

**Decision:** Use the PocketBase JS SDK (`pocketbase`
npm package v0.25.x) as the sole client for all
PocketBase operations. All PB calls go through Elm
ports to JavaScript, where two SDK instances handle
the requests:

- `pbAdmin` — superuser operations (admin CRUD)
- `pb` — coach/public operations (login, registration)

The architecture has three layers:

1. **`Api.elm`** — data layer only: type aliases,
   JSON decoders, JSON encoders. No HTTP, no effects.
2. **`Pb.elm`** — port-based PB client: `adminList`,
   `adminCreate`, `adminUpdate`, `adminDelete`,
   `publicList`, `publicCreate`, `adminLogin`,
   `coachLogin`. Each operation sends a tagged message
   through `Effect.portSend` and responses arrive on
   `Effect.incoming`.
3. **`interop.js`** — JS glue: receives `PbSend` port
   messages, routes to the appropriate SDK instance,
   sends results back via the `incoming` port as
   `{ tag, data }` or `{ tag, error }`.

Pages subscribe to `Pb.subscribe PbMsg` and route
responses via `Pb.responseTag value` pattern matching.

**Rationale:**
- **No duplication** — the SDK handles auth headers,
  pagination, error formats, and will handle realtime
  subscriptions when needed
- **Fewer lines** — ~30 lines in `Pb.elm` replace
  ~300 lines of HTTP functions that were in `Api.elm`
- **Auth management** — the SDK manages token
  refresh and auth store; we persist tokens to
  localStorage
- **Future-proof** — OAuth2, realtime, file uploads all
  come free with the SDK
- **Two instances** — separates admin superuser auth
  from coach user auth cleanly, avoiding token conflicts

**Trade-offs:**
- Port indirection adds a layer vs direct HTTP
- Responses are `Json.Decode.Value` (dynamic) rather
  than typed `Result Http.Error a` — but `Pb.elm`
  decoder helpers restore type safety at the boundary
- JS SDK is a runtime dependency (~50KB)

---

## ADR-009: Parse, don't validate — prefer types over booleans

**Date:** 2026-03-04

**Context:** During issue #49 (round lifecycle domain
types), the plan included boolean query functions like
`isFullySubmitted`, `isFullyVerified`, and
`missingScorers`. These check a property and return
`Bool` or a derived value, discarding the proof. This
is the "validate" pattern described in Alexis King's
["Parse, Don't Validate"][parse-dont-validate].

[parse-dont-validate]: https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/

**Decision:** Prefer sum types that encode state over
boolean accessor functions. When code needs to know
"what state is this in?", return a type that proves
which state it's in — don't return a `Bool` that the
caller must re-interpret.

Concrete example from `BallotTracking`:

```elm
-- AVOID: boolean queries that discard information
isFullySubmitted : BallotTracking -> Bool
missingScorers : BallotTracking -> List Volunteer

-- PREFER: a type that encodes the state
type ScorerStatus
    = AwaitingSubmissions (List Volunteer)
    | AwaitingVerification
    | AllVerified

scorerStatus : BallotTracking -> ScorerStatus
```

A caller pattern-matching on `AllVerified` *knows*
everything is verified — the type proves it. And
`AwaitingSubmissions` carries *who* is missing, so
there's no separate `missingScorers` function needed.

**Principles (ongoing):**

1. **Parse at boundaries, not everywhere.** Validate
   inputs once (smart constructors), then use types
   that make invalid states unrepresentable downstream.

2. **Sum types over booleans.** A `Bool` is just
   `True | False` — it throws away *which* state.
   A named sum type carries meaning the compiler can
   check.

3. **Carry the proof.** If checking a property produces
   useful data (e.g., which scorers are missing), the
   return type should carry that data — not discard it
   and force the caller to recompute.

4. **Avoid primitive obsession.** `String`, `Int`,
   `Bool` rarely capture domain intent. Wrap them in
   domain types (`Name`, `Points`, `TrialStatus`) so
   the compiler prevents mixing them up.

5. **Let the type system be the documentation.** If a
   function only accepts `ActiveTrial` (not `Trial`),
   the type signature documents that the trial must
   have been activated — no runtime check needed.

**Rationale:**
- Aligns with Wlaschin's "Making Illegal States
  Unrepresentable" and King's "Parse, Don't Validate"
- Elm's exhaustive pattern matching makes sum types
  cheap to use — the compiler forces handling every case
- Reduces test surface: fewer boolean combinations to
  test when states are mutually exclusive by construction
- Already established in the codebase (opaque types,
  smart constructors, `Result (List Error) a`) — this
  ADR makes the principle explicit and extends it to
  query functions

**Consequences:**
- Modules may expose more types (e.g., `ScorerStatus`,
  `PresiderStatus`) but fewer functions
- Callers use pattern matching instead of
  `if isFullyVerified then ...` — more verbose but
  compiler-checked
- Ongoing discipline: when tempted to add a `Bool`
  accessor, ask "should this be a type instead?"

---

## ADR-008: URL design principles

**Date:** 2026-03-04

**Context:** The app has two audiences — admins managing
the competition and public users (coaches, scorers,
spectators) consuming it. URLs will appear in QR codes,
text messages, bookmarks, and printed materials. Elm
Land's file-based routing maps page filenames directly
to URL paths, so URL design and file structure are the
same decision. Influenced by [URLs are UI][hanselman],
[URL Design][warpspire], [Cool URIs Don't Change][tbl],
and Ember.js's philosophy that URLs are a public API
for application state.

[hanselman]: https://www.hanselman.com/blog/urls-are-ui
[warpspire]: https://warpspire.com/posts/url-design
[tbl]: https://www.w3.org/Provider/Style/URI

**Decision:**

1. **`/admin/*` namespace for all admin pages.** Admin
   pages live under `Pages/Admin/` and route to
   `/admin/*`. This is already established.

2. **Public URLs are top-level.** Spectator and coach
   pages live at `/standings`, `/schedule`,
   `/rounds/:number`, `/teams/:name`, etc. — no
   `/public` prefix. The public site is the default;
   admin is the exception.

3. **Dynamic segments use IDs, not slugs.** Detail
   pages use PocketBase record IDs:
   `/admin/tournaments/:id`. IDs are stable and
   unambiguous. Human-readable suffixes may be appended
   but are ignored for routing (StackOverflow pattern).

4. **Querystrings for filtering and view state.**
   Filters like round or courtroom use query params:
   `/admin/pairings?round=2`. Pages must work without
   querystrings (show a default view).

5. **Scoring URLs optimized for mobile and QR.**
   Ballot scoring paths are short and typeable:
   `/score/:code` rather than deeply nested admin
   paths. The `:code` is a short, unique identifier
   (not a full PocketBase ID) to reduce QR density
   and typing errors.

6. **URLs are a contract.** Once a URL is shared
   (bookmarked, printed, linked in email), it must
   continue to work. Changing a URL requires a
   redirect. Plan URL structure before building pages.

7. **Elm Land conventions apply.** File naming maps to
   URLs per Elm Land rules:
   - Folder nesting = path segments
     (`Pages/Admin/Teams.elm` → `/admin/teams`)
   - CamelCase → kebab-case
     (`SignIn.elm` → `/sign-in`)
   - Trailing underscore = dynamic segment
     (`Id_.elm` → `/:id`)
   - `ALL_.elm` = catch-all for variable-depth paths

**Rationale:**
- Top-level public URLs are shorter, more shareable,
  and signal that the public site is the primary
  product — admin is a back-office tool
- ID-based routes avoid slug uniqueness problems and
  rename fragility. Slugs can be appended for SEO/
  readability without being load-bearing
- Querystrings for filters follow web conventions and
  keep base URLs functional without parameters
- Short scoring URLs reduce QR code density (fewer
  modules = easier phone scanning) and are faster to
  type when QR fails
- Treating URLs as a contract forces upfront design
  and prevents link rot

**Consequences:**
- Public page files go in `Pages/` (not `Pages/Public/`)
  to get top-level URLs — must be careful not to
  collide with domain module names (ADR-006)
- Need a short-code generation scheme for scoring URLs
  (deferred to issue #33/#34)
- Detail pages require new files with dynamic segments
  (e.g., `Pages/Admin/Tournaments/Id_.elm`) — this is
  future work as admin detail views are added
- URL changes after launch require redirect support,
  which PocketBase hooks or middleware can handle

---

## ADR-007: Auth UX — role self-identification

**Date:** 2026-03-01 (updated 2026-04-15)

**Context:** The app has multiple user roles (teacher
coach, attorney coach, scorer/judge, admin) with
different auth needs. This ADR was originally written
when OAuth2 was the planned auth mechanism. OAuth2 was
subsequently dropped (issue #60 closed) in favor of a
simpler username/password workflow matched to RCOE's
existing manual approval process.

**Decision (current):**

1. **Role selection first.** The `/register` screen
   presents role cards ("How are you participating?").
   Currently only "Teacher Coach" leads to a working
   flow. Other roles are placeholders.

2. **Teacher coaches use email/password registration.**
   The `/register/teacher-coach` form collects name,
   email, password, school, and team name. On submit,
   PocketBase creates a `users` record (status:
   `pending`) and a `teams` record (status: `pending`)
   atomically via a server-side hook.

3. **RCOE approves coaches manually.** The admin reviews
   registrations at `/admin/registrations` and approves
   or rejects. An auth guard hook blocks login until the
   coach is approved.

4. **Attorney coaches are excluded from direct
   registration.** RCOE has no direct communication
   channel with attorney coaches — outreach goes through
   the Bar Association. System access for attorney
   coaches is deferred and may not happen. If it does,
   the access level is TBD (likely read-only).

5. **Scorer/judge auth is deferred.** The planned
   approach — magic link or tournament-day QR — is still
   the right direction, but implementation is deferred to
   milestone 4. See issue #77 for the future magic link
   consideration.

6. **Admin and SuperUser are never self-registered.**
   Created by existing admins via PocketBase admin UI or
   the `superuser upsert` CLI command.

**Rationale:**
- Username/password matches RCOE's existing workflow:
  coaches email RCOE, RCOE sends a registration URL, coach
  fills the form, RCOE approves in the admin UI
- OAuth adds configuration complexity (two providers,
  domain verification) for a marginal benefit when RCOE
  already reviews every registration manually
- Excluding attorney coaches avoids building a feature
  for an audience RCOE cannot directly reach or support
- Magic link / QR for scorers remains the right approach
  for tournament day — deferred until ballot entry is built

**Consequences:**
- Coach passwords are stored in PocketBase's `users` auth
  collection — PocketBase handles bcrypt hashing
- Coaches must remember their password (no OAuth SSO)
- Attorney coaches have no system access for MVP; RCOE
  shares results with them through existing channels
- Scorer auth is undefined until milestone 4

---

## ADR-006: Flat module-per-concept for domain types

**Date:** 2026-03-01

**Context:** Building a pure domain layer (no persistence
concerns). Need to decide how to organize domain types
in the Elm frontend. Options considered: a single
`Domain.elm` module, a `Domain.*` namespace, or flat
top-level modules named after domain concepts.

**Decision:** One flat module per domain concept, named
after the noun: `School.elm`, `Student.elm`, `Coach.elm`,
`Team.elm`. No `Domain` namespace.

**Rationale:**
- Follows elm-spa-example convention (Feldman): each
  module is the domain concept, not a layer
- Consistent with ML-family best practices (Haskell,
  OCaml, F#) — `Domain` is an OOP/DDD-ism that adds
  a redundant namespace
- "The Life of a File" (Czaplicki): split around domain
  concepts, not architectural layers
- `School.elm` is self-evidently a domain concept —
  wrapping it in `Domain.School` adds noise
- Types and their functions live together in the same
  module (test combinators, not type definitions)

**Consequences:**
- Domain types tested via combinators/derived values,
  not construction — Elm's type system already prevents
  invalid construction
- May need to rename if a module name collides with
  an Elm Land page module (unlikely for domain nouns)
- Related types grouped by proximity: e.g., `District`
  lives in `School.elm` since it's tightly coupled

---

## ADR-005: Staging environment on fly.io

**Date:** 2026-02-28

**Context:** The admin team (2–5 people) needs to try
the app and give UI feedback without running locally.
We need a deployed instance before the app is
production-ready.

**Decision:** Create a separate `rivcomocktrial-staging`
app on fly.io with its own config (`fly.staging.toml`)
and deploy token. GitHub Actions deploys to staging on
push to main, scoped to app-relevant paths only
(`frontend/**`, `backend/**`, fly configs,
`.dockerignore`). Reserve `fly.toml` and the
`rivcomocktrial` app name for future production use.

**Rationale:**
- Separate staging app avoids risk to future production
  data
- Path-scoped deploys avoid unnecessary builds for
  documentation-only changes
- Same Dockerfile for both environments — no config
  drift
- `node:20-slim` (not alpine) required for the frontend
  build stage because the elm npm binary needs glibc

**Consequences:**
- Two fly.io apps to manage (staging now, production
  later)
- Each environment needs its own `FLY_API_TOKEN` — may
  need to rename the GitHub secret when production is
  added
- Staging data is disposable and not backed up
- Dockerfile uses a mixed base image strategy:
  `node:20-slim` for build (glibc for elm) and
  `alpine:3.19` for runtime (small image for
  PocketBase)

---

## ADR-004: Admin auth via PocketBase superuser (Milestone 1)

**Date:** 2026-02-28

**Context:** The system needs multiple auth roles (admin,
teacher coach, attorney coach, scorer, public). We need to
decide how to authenticate admins first, since they're the
primary users for Milestone 1.

**Decision:** Use PocketBase's built-in superuser auth for
admin login. The Elm frontend sends email/password to
`/api/collections/_superusers/auth-with-password` and
stores the returned token in `Shared.Model`. Admin pages
are guarded by `Auth.elm` which redirects to `/admin/login`
when no token is present.

**Rationale:**
- Simplest possible auth for Milestone 1 — no custom auth
  collections needed
- PocketBase superuser has full API access, which is what
  admins need
- Token is stored in memory only (lost on page refresh) —
  acceptable for now, can add localStorage persistence
  later
- Coach OAuth (Google/MS) and other roles are deferred to
  later milestones

**Consequences:**
- Admin must re-login on every page refresh (no token
  persistence yet)
- Only one auth type exists right now — role separation
  comes later
- The `/api/collections/_superusers/auth-with-password`
  endpoint is PocketBase-specific; if we ever migrate
  away from PocketBase, auth would need rework

---

## ADR-003: PocketBase collections schema (Milestone 1)

**Date:** 2026-02-28

**Context:** Need to model the core domain entities. Key
domain fact: School ≠ Team. A school can field 1–2 teams
per tournament. Students belong to schools (not teams) and
get assigned to teams per tournament via round rosters
(Milestone 3).

**Decision:** Five base collections for Milestone 1:

- `tournaments` — standalone, with status workflow
  (draft → registration → active → completed)
- `schools` — standalone, with district
- `courtrooms` — standalone, with location
- `teams` — belongs to tournament and school
  (cascade-deletes with tournament)
- `students` — belongs to school (not to team — team
  assignment happens via round rosters later)

**Rationale:**
- Mirrors the real-world domain: schools register, then
  teams are created per tournament
- Students on schools (not teams) because the same
  student could theoretically be on different teams
  across tournaments, and roster assignment is per-round
- Tournament status as a select field with fixed values —
  simple and sufficient
- Teams cascade-delete with their tournament because a
  team only makes sense within a tournament context

**Consequences:**
- No `users` auth collection yet — admin-only via
  superuser
- Round rosters (Milestone 3) will link students to teams
  per round
- If we need tournament-level student eligibility (beyond
  school membership), we'd add a junction collection
  later

---

## ADR-002: Bulma CSS framework

**Date:** 2026-02-28 (Milestone 0)

**Context:** Need a CSS framework for the Elm Land
frontend. Options considered: Bulma, Tailwind, elm-ui,
elm-css.

**Decision:** Bulma v1.0.4 via CDN link in
`elm-land.json`.

**Rationale:**
- Elm Land's own tutorials use Bulma — happiest path
- Zero build tooling — one CDN link, apply classes via
  `Html.Attributes.class`
- Tailwind would require an extra CLI watcher
- elm-ui and elm-css are effectively unmaintained (as of
  Feb 2026)
- CDN URL must use cdnjs format (not jsDelivr) because
  elm-land's HTML templating mangles `@` symbols

**Consequences:**
- All styling is class-based — no type-safe styling, but
  simple and well-documented
- Bulma is CSS-only (no JavaScript) — all interactivity
  is in Elm, which is what we want

---

## ADR-001: PocketBase as backend

**Date:** 2026-02-28 (Milestone 0)

**Context:** Need a backend for a small competition
management app. Team of 2–5 admins, ~26 teams, low
concurrent users. Must support: auth, CRUD, relations,
real-time updates (eventually), file storage (eventually).

**Decision:** PocketBase v0.36.3, used out-of-the-box with
JS migrations and hooks. No custom Go extensions. Single
binary deployed in a Docker container on fly.io with a
persistent SQLite volume.

**Rationale:**
- Single binary, zero external dependencies — ideal for
  a small project
- Built-in auth (email/password + OAuth), REST API, admin
  UI, realtime subscriptions
- SQLite is sufficient for this scale (~26 teams, <100
  concurrent users)
- JS migrations and hooks cover our customization needs
  without needing a Go build toolchain
- fly.io persistent volume for SQLite data — simple and
  cheap

**Consequences:**
- SQLite means single-writer — concurrent ballot entry
  (Milestone 8) needs care, but PocketBase handles WAL
  mode
- No horizontal scaling — single instance only, which is
  fine for this scale
- Vendor lock-in to PocketBase API format — acceptable
  given the project scope
- Migrations are version-controlled; data is local-only
  (never committed)
