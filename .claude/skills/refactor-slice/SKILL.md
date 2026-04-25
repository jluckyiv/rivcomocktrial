---
name: refactor-slice
description: Walk a single workflow-driven slice of the rivcomocktrial frontend refactor through its four gated passes (Brief, Domain, Page, Lock). Use when the user says "let's do the next slice", "start the X slice", "/refactor-slice", or names a workflow step (registration, pairing, ballots, etc.) in the context of the active refactor. Loads the conventions and gates each pass on the previous one being green.
---

# Refactor slice protocol

You are running a single slice of the active rivcomocktrial frontend
refactor. Read these first, in order, before doing anything else:

1. `docs/elm-conventions.md` — what idiomatic Elm looks like here.
2. `docs/refactor-process.md` — the full slice template.
3. `docs/decisions.md` ADR-012 and ADR-013 — architecture and freeze.
4. The most recent slice doc in `docs/slices/` (if any) — to see
   what the previous slice taught us.

Then walk the four passes below. **Do not advance to the next pass
until the previous one is green.** Each pass is a commit.

## Pass 1 — Brief (doc-only)

Create `docs/slices/NN-step-name.md` with these sections:

- **Workflow step** — number and name (from `docs/competition-workflow.md`).
- **Pages migrated** — file paths.
- **Entities touched** — for each, classify as:
  - **sacrosanct** (do not modify): list which existing tests cover it
  - **extend** (add functions, paired test edits): list current state
  - **new** (does not yet exist): rationale
- **Existing tests that apply** — file paths.
- **Gaps the slice fills** — what we are adding.
- **Definition of done** — checklist.

**Stop and have the user sign off on the brief before pass 2.** This
is the most important gate.

## Pass 2 — Extend the entity module (TDD)

For each entity in the slice, in its existing top-level module
(e.g. `frontend/src/School.elm`), add what the slice needs — all in
the same module, no sidecars:

- Type refinements (`NewX` if entity has identity; sum variants for
  lifecycle states).
- `decoder : Decoder X` — calls smart constructor inside, fails on
  `Err`.
- `encoder : NewX -> Encode.Value`.
- Typed network functions: `list`, `create`, `update`, `delete`.
  Each takes a record including `onResponse`, returns `Effect msg`.
  Internally calls `Pb.adminList`/etc.
- Accessors and helpers.

Tests live in `frontend/tests/<Entity>Test.elm`. **Test scope**:
business rules in smart constructors, pure algorithms, state
transitions, decoder behavior on fixture JSON. **Do not test**
decoder mechanics, accessors, type-system guarantees, or impossible
branches. (See `docs/elm-conventions.md` §7.)

**Use the Kearns workflow:**
- Make a wish (write code as if it existed).
- Let the compiler tell you what's missing.
- Hard-code values to get to green.
- Make the change easy, then make the easy change (Beck).

The TDD hook (`.claude/hooks/tdd-first-guard.sh`) will block writes
to a new domain module unless its sibling test file exists with at
least one test. Override only for legitimate scaffolding:
`TDD_BYPASS=1`.

**Stop and verify** `npm run fe:test` is green before pass 3.

## Pass 3 — Page rewrite

`frontend/src/Pages/.../<Page>.elm`:

- `Model` holds **domain types**, never `Api.X`.
- The page imports only the entity modules it uses, `Effect`,
  Elm Land bits, `UI`, and whatever else it actually needs.
  **It does not import `Api` or `Pb`.**
- Form state lives in the page Model. Field-change messages call
  smart constructors and store the `Result`. Errors appear as the
  user types.
- The Elm Land surface is unchanged: same `page` signature, same
  layout, same auth, same view shape.
- View helpers stay in the page module or move to `UI.elm`.
  No components-with-state.

**Stop and verify** `npm run fe:test` and `npm run fe:build` are
green before pass 4.

## Pass 4 — Lock

- Remove the page's module name from the `stillOnApi` allowlist in
  `frontend/review/src/NoPbOrApiInMigratedPages.elm`.
- Run `npx elm-review` — should be green.
- Manual smoke test against local PocketBase: `npm run pb:dev`,
  `npm run fe:dev`, exercise the page (CRUD where applicable).
- Verify all pre-existing tests are still green.
- Verify no edits to frozen paths in this slice's commits:
  `git log --name-only HEAD~N..HEAD | grep -E '(backend/pb_hooks/|backend/pb_migrations/|frontend/src/Api\.elm|frontend/src/Pb\.elm)'`
  should be empty.

Then: PR.

## What to do when something doesn't fit

- **Wire format needs a change?** Stop. Do not edit `Api.elm` or
  PocketBase. Surface the proposal (failing assumption, repro,
  proposed change). Default answer is "work around in the entity's
  module." Override only if the workaround would introduce a lying
  type — then user authorizes a one-commit thaw with an ADR.
- **Existing module is "sacrosanct" but the slice wants to change
  it?** Re-classify in the brief and have the user sign off again.
  Sacrosanct modules are sacrosanct because changing them risks
  breaking pure tested logic; reclassification needs explicit
  authorization.
- **Compiler insists on a Maybe somewhere that "always has a
  value"?** That's the type system telling you the model has a
  hidden multiple-source-of-truth bug, or that the data shape is
  wrong. Restructure rather than `Maybe.withDefault`.
- **A test is hard to write?** The business rule is in the wrong
  module — usually inside a view function or update wiring.
  Extract it.

## When to stop and ask

Stop and ask the user when:

- A workflow step has ambiguous business rules (the brief surfaces
  this; do not guess).
- A migration would require touching a sacrosanct module without
  re-classification.
- A wire-format change seems required.
- The slice is growing beyond one workflow step (split it).
