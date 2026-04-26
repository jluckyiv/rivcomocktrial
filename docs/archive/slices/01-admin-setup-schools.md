# Slice 01 — Admin Setup: School Management

## Workflow step

**Admin Setup: School Management** — prerequisite to Step 1
(Teams Register). Schools must exist before teams can register.
Not a numbered step in `competition-workflow.md`; it is the
management UI for the `schools` PocketBase collection.

---

## Pages migrated

- `frontend/src/Pages/Admin/Schools.elm`

---

## Entities touched

### `School` (`frontend/src/School.elm`) — **extend**

**Current state:** `School { name : Name, district : District }` —
pure domain concept with no PocketBase ID. `create`, `nameFromString`,
`nameToString`, `schoolName`, `district` are all currently exported.
Used in `Team.elm`, `Conflict.elm`, `Fixtures.elm` as an embedded
domain type (no ID needed in those contexts).

**Naming tension (design decision required):**
`docs/elm-conventions.md` §2 says the bare name (`School`) should be
the *persisted* type (with ID) and `NewSchool` the unpersisted form
result. The current `School` is actually the unpersisted concept. Full
renaming (`School` → `NewSchool`, add `School` with `Id`) would also
require touching `Team.elm`, `Conflict.elm`, `Fixtures.elm`, and their
tests — broader than one slice.

**Proposed resolution for this slice:** Keep `School` as the pure
domain concept (no change to existing API). Add:

- `type Id = Id String` (opaque)
- `type alias Record = { id : Id, name : Name, district : District }`
  — the PocketBase-persisted shape
- `idToString : Id -> String`

The page Model holds `RemoteData String (List Record)`. The form
validates to `School` (via existing `create`), which is then encoded
for wire. The full `NewSchool`/`School` rename is deferred to when
`Team` and `Conflict` are also being sliced, so the rename ships in
one coherent commit.

**Functions to add:**

```
decoder       : Decoder Record
encoder       : School -> Encode.Value
list          : Effect msg
create_       : School -> Effect msg
update_       : Id -> School -> Effect msg
delete_       : Id -> Effect msg
respondList   : Decode.Value -> Maybe (RemoteData String (List Record))
respondSave   : Decode.Value -> Maybe (RemoteData String Record)
respondDelete : Decode.Value -> Maybe (RemoteData String Id)
```

`list`, `create_`, `update_`, `delete_` internally call `Pb.adminList`
/ `Pb.adminCreate` / `Pb.adminUpdate` / `Pb.adminDelete` with fixed
tags (`"list-schools"`, `"save-school"`, `"delete-school"`).

`respond*` helpers check `Pb.responseTag` and decode the port value,
returning `Nothing` for unrecognised tags. The page calls these from
a single `Effect.incoming` subscription — no `Pb` import needed in
the page.

---

## Existing tests that apply

- `frontend/tests/SchoolTest.elm` — covers `nameFromString`,
  `nameToString`, `create`, `schoolName`, `district`. **All must stay
  green.** These tests are sacrosanct; the existing exports are not
  removed or renamed.

**New test to add in this slice:**

- Decoder test on a fixture JSON value representative of a real
  PocketBase response (per elm-conventions.md §7 — "decoder behavior
  on fixture JSON when the decoder runs business validation").

---

## Gaps the slice fills

1. `School.Id` opaque type — eliminates raw `String` school IDs from
   the page.
2. `School.Record` — the persisted wire type, replacing `Api.School`
   in the page.
3. `School.decoder` and `School.encoder` — wire concerns move from
   `Api.elm` into `School.elm`.
4. `School.list`, `create_`, `update_`, `delete_` — typed network
   functions; the page no longer calls `Pb` directly.
5. `School.respond*` helpers — the page decodes port values through
   domain helpers, not through `Pb.decodeList` / `Pb.decodeRecord`.
6. Page rewrite — Model holds `RemoteData String (List School.Record)`;
   page imports only `School`, `District`, `Effect`, `UI`, and Elm
   Land modules; no `Api` or `Pb` imports.

---

## Definition of done

- [ ] `School.elm` exports `Id`, `Record`, `idToString`, `decoder`,
      `encoder`, `list`, `create_`, `update_`, `delete_`,
      `respondList`, `respondSave`, `respondDelete`.
- [ ] `SchoolTest.elm` updated with decoder test on fixture JSON;
      all pre-existing tests still pass.
- [ ] `Pages/Admin/Schools.elm` imports only `School`, `District`,
      `Effect`, `UI`, `RemoteData`, `Html.*`, `Json.Decode`,
      `Auth`, `Layouts`, `Page`, `Route`, `Shared`, `View`.
      No `Api` or `Pb`.
- [ ] `Pages.Admin.Schools` removed from `stillOnApi` in
      `frontend/review/src/NoPbOrApiInMigratedPages.elm`.
- [ ] `npm run fe:test` green (all pre-existing tests pass).
- [ ] `npm run fe:build` green.
- [ ] `npx elm-review` green.
- [ ] Manual smoke: `/admin/schools` loads, list renders, create /
      edit / delete / bulk-import all work against local PocketBase.
- [ ] No frozen-path edits:
      `git log --name-only HEAD~4..HEAD | grep -E '(pb_hooks|pb_migrations|Api\.elm|Pb\.elm)'`
      returns empty.
