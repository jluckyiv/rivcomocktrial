# Refactor Process

How we move the codebase toward the conventions in
`docs/elm-conventions.md`. Active for the duration of the
domain-rebuild refactor (ADR-012, ADR-013).

If you are about to write Elm code as part of this refactor, read
this and `docs/elm-conventions.md` first. They cost two minutes
each and they are what keeps us from going off the rails again.

---

## The shape of the work

We move the codebase one **slice** at a time. A slice is one
**workflow step** (e.g. "create a tournament", "register a
coach", "submit a roster") and the page or pages that implement
it. Slices ship as small, reviewable PRs and follow the tournament
workflow in order (`docs/competition-workflow.md`).

**Do not pre-plan the slices.** Plan the next slice in detail.
Ship it. Let what we learn shape the next one. The official Elm
guide is explicit: "do not plan ahead." The compiler makes
refactoring cheap; we use that.

---

## The slice template

Four passes per slice. Each pass is a commit.

### Pass 1 — Brief (doc-only)

Write `docs/slices/NN-step-name.md`:

- Workflow step number and name.
- The page or pages being migrated.
- The entity or entities the page touches.
- Existing domain-module status for each touched entity:
  **sacrosanct** (do not modify), **extend** (add functions, with
  paired test edits), or **new** (does not yet exist).
- Existing tests that apply.
- Gaps the slice fills.
- Definition-of-done checklist.

User signs off on the brief before pass 2.

### Pass 2 — Extend the entity module (TDD)

In each entity's existing module (e.g. `frontend/src/School.elm`),
add what the slice needs, all in the same module:

- Type refinements (`NewX` if the entity has identity, sum
  variants for lifecycle states).
- `decoder : Decoder X` — calls the smart constructor inside,
  fails the decoder on `Err`.
- `encoder : NewX -> Encode.Value` — writes the PocketBase JSON
  shape from a validated value.
- Typed network functions: `list`, `create`, `update`, `delete`
  — each takes a record of inputs including `onResponse`, returns
  `Effect msg`. Internally calls `Pb.adminList`/etc.
- Accessors and helpers as needed.

Tests live in `frontend/tests/<Entity>Test.elm`. Per
`docs/elm-conventions.md` §7: tests target business rules and
algorithms, not data validation or type-system guarantees.

Use the Kearns workflow: make a wish, let the compiler tell you
what's missing, hard-code to green, refactor with "make the
change easy, then make the easy change."

### Pass 3 — Page rewrite

`frontend/src/Pages/.../<Page>.elm`:

- `Model` holds domain types, never `Api.X`.
- The page imports only the domain modules it uses (e.g.
  `School`), `Effect`, Elm Land bits, `UI`, and whatever else it
  actually needs. **It does not import `Api` or `Pb`.**
- Form state lives in the page Model. Field-change messages call
  smart constructors and store the `Result`. Validation feedback
  appears as the user types, not on submit.
- The Elm Land surface (page builder, layout, auth, view shape)
  is unchanged.
- View helpers stay in the page module or move to `UI.elm`. No
  components-with-state.

### Pass 4 — Lock

- Remove the page's module name from the `stillOnApi` allowlist
  in `frontend/review/src/NoPbOrApiInMigratedPages.elm`.
- `npm run fe:test`, `npm run fe:build`, `npx elm-review` all
  green.
- Manual smoke test against local PocketBase
  (`npm run pb:dev`, `npm run fe:dev`).
- All pre-existing tests still green.

---

## Persistence freeze

Per ADR-013. These paths are read-only for the duration of the
refactor:

- `backend/pb_hooks/**`
- `backend/pb_migrations/**`
- `frontend/src/Api.elm` (until deleted; see below)
- `frontend/src/Pb.elm` internals

**When a slice wants a wire change:** stop. Do not edit. Surface
the proposal (failing assumption, minimal repro, proposed change).
Default response is "work around it in the entity's module." Only
if the workaround would introduce a lying type does the user thaw
the freeze for that one commit. Each thaw is documented as its
own ADR.

**Override mechanism:**

- In-session: `PERSISTENCE_UNFREEZE=1` env var.
- Commit-time: `ALLOW_FROZEN_EDIT=1 git commit ...`.

Both are explicit, per-invocation, and leave a trail.

`frontend/src/Api.elm` is frozen until it has no remaining
importers (per ADR-012), at which point we delete it. After
deletion, the deny rule for that path becomes moot and is removed.

---

## TDD discipline

- New file in `frontend/src/<Entity>.elm` requires
  `frontend/tests/<Entity>Test.elm` to exist with at least one
  failing test before the implementation file is created.
  Enforced by PreToolUse hook.
- Modifying an existing domain module requires a paired edit to
  its test file in the same commit. Enforced by lefthook.
- All pre-existing tests stay green.

**Override** (scaffolding only): `TDD_BYPASS=1` for the
in-session hook, `ALLOW_UNPAIRED=1` for lefthook.

---

## Test scope (recap)

From `docs/elm-conventions.md` §7 — repeated here because it is
load-bearing:

- **Test:** business rules in smart constructors; pure algorithm
  functions; state-machine transitions; decoder behavior on
  fixture JSON when the decoder runs business validation.
- **Do not test:** decoder mechanics; trivial accessors;
  impossible branches; type-system guarantees.

If a business rule is hard to test, it is in the wrong module.
Extract it.

---

## Per-slice obligations (checklist)

The brief (Pass 1) must include:

- [ ] Workflow step number and name.
- [ ] Pages migrated by this slice (file paths).
- [ ] Entities touched, each classified as sacrosanct / extend /
      new with rationale.
- [ ] Existing tests that apply (file paths).
- [ ] Definition of done.

The lock (Pass 4) must verify:

- [ ] No new module imports `Api` or `Pb` directly.
- [ ] Page no longer in the `stillOnApi` allowlist.
- [ ] All pre-existing tests green.
- [ ] Manual smoke test passed.
- [ ] No frozen-path edits in the slice's commits
      (`git log --name-only` against the freeze list).

---

## How to use this in a session

Use the `/refactor-slice` skill at the start of each slice. It
loads this checklist into context and walks the four passes as
gated stages. If you are starting a slice without invoking the
skill, you have a higher chance of drifting; do not skip it.
