# Elm Conventions

How we write Elm in this codebase. Read this before writing or
reviewing any Elm code. Distilled from canonical sources (cited
inline). Matches the conventions of the elm-land framework we use
and of the Elm community at large.

If you find a tension between these conventions and what the code
already does, the conventions win — the code is wrong, not these
rules. ADR-012 explains why.

---

## 1. One module per domain concept

Each domain concept gets one module that owns everything related
to it: the type, smart constructors, accessors, sum types it
references, JSON `decoder` and `encoder`, and any I/O wrappers
(network calls, port helpers). All in one file.

```elm
module School exposing
    ( School
    , NewSchool
    , create
    , name
    , district
    , decoder
    , encoder
    , list
    , create_     -- network call: POST a NewSchool
    , update_     -- network call: PUT a School
    , delete_     -- network call: DELETE a School
    )
```

### Anti-patterns

- **Sidecar modules.** No `SchoolCodec.elm`, no `SchoolAssembly.elm`,
  no `SchoolForm.elm`. The decoder/encoder/network calls live in
  `School.elm`. If a sub-concept earns its own file later (after
  the module has grown organically), it can be split — but never
  speculatively.
- **A flat `Api.elm` that mirrors every wire shape.** The disease
  is the *flat* file with every type in one place — not the
  existence of a module named `Api`. Per-resource modules own
  their own wire concerns. (elm-land's realworld example uses an
  `Api/` *namespace* with per-resource files like `Api/User.elm`;
  that is fine. A single 50-type `Api.elm` is what we are
  removing per ADR-012.) For this project, we keep entity modules
  at the top level (`School.elm`, `Tournament.elm`, etc.) because
  that matches the existing convention of 50+ top-level domain
  modules.
- **Splitting by architectural role.** No `Model.elm`,
  `Update.elm`, `View.elm` for a page. The page module owns all of
  it. Use comment headers (`-- MODEL`, `-- UPDATE`, `-- VIEW`) to
  organize within the file.

### The criterion for splitting a module is *finding a substructure*

Files can be 600 or 2000 lines. That is fine. Split when you
discover a piece of the file that is itself a coherent type with
its own logic — not when the file gets long. The compiler makes
refactoring cheap, so you can always split later.

**Sources:** Czaplicki, *The Life of a File* (Elm Europe 2017);
Feldman, *Make Data Structures*; the official guide,
[Web Apps — Structure](https://guide.elm-lang.org/webapps/structure);
elm-land's `realworld-app` example.

---

## 2. Make impossible states impossible

If two fields can never both be true, the type system should reject
the combination. If a value can be in three states, model them as a
sum type, not three booleans.

```elm
-- Wrong: nothing prevents { fetching = True, success = True, ... }
type alias FetchState =
    { fetching : Bool
    , success : Bool
    , error : Bool
    , errorMessage : String
    }

-- Right: only one variant at a time, and Failure carries its proof
type FetchState a
    = NotAsked
    | Loading
    | Failure String
    | Success a
```

### Specific patterns we use

- **`RemoteData a`** (from `krisajenkins/remotedata`) for request
  state. Do not write a homebrew version.
- **`Assignment a = NotAssigned | Assigned a`** (already in
  `frontend/src/Assignment.elm`) for slot-like fields. Prefer this
  to `Maybe` whenever the field has assignment semantics (judge
  slot, courtroom slot, ID-after-persistence).
- **`NewX` vs `X`** for unpersisted vs persisted entities. `NewX`
  is what a validated form produces (no ID, no timestamps). `X` is
  what comes back from PocketBase (with typed ID and timestamps).
  Smart constructor for `X` requires an ID; smart constructor for
  `NewX` does not.
- **State-machine sums** for lifecycle entities. A `Tournament`
  with phases is `Draft DraftData | Registration RegistrationData |
  Active ActiveData | Completed CompletedData`, where each variant
  carries only the fields that exist in that state.

**Sources:** Feldman, *Make Data Structures* and *Making Impossible
States Impossible*; Fairbank, *Solving the Boolean Identity Crisis*;
ADR-009.

---

## 3. Single source of truth via immutable relational data

Going from JS objects (mutable references) to Elm records
(immutable values) accidentally creates duplicate truth. Nested
records become independent copies. Update one, the others go
stale.

The fix: store IDs in the inner types and keep entities in
top-level `Dict`s on the `Model`. Look up by ID. Compose with
`Dict.filter`, `Dict.intersect`, `Dict.get`.

```elm
-- Wrong: Pairing carries full Team records. If a team's name
-- changes, the pairing has stale data.
type Pairing = Pairing
    { prosecution : Team
    , defense : Team
    }

-- Right: Pairing references teams by ID. The Model holds one Dict
-- of teams. Lookup at use time.
type Pairing = Pairing
    { prosecution : TeamId
    , defense : TeamId
    }

type alias Model =
    { teams : Dict TeamId Team
    , pairings : Dict PairingId Pairing
    , ...
    }
```

Treat the `Model` like a relational database. SQL-ish queries map
naturally onto `Dict` operations:

```elm
-- "all voting-age users in St. Louis" via Dict.intersect
locals =
    Dict.filter (\_ city -> city == StLouis) model.residents

votingAgeStLLocals =
    Dict.intersect locals (Dict.filter isVotingAge model.users)
```

**Exception:** caching for measured performance reasons. In
practice this is rare; `Html.lazy` usually solves perceived
performance problems without you needing duplicate state. If you
think you need a cache, prove it first.

**Source:** Feldman, *Immutable Relational Data*.

---

## 4. Parse, don't validate

Validate inputs once, at the boundary, with smart constructors that
return `Result (List Error.Error) a`. Downstream code receives the
parsed type and the type proves the value is valid. There are no
runtime checks scattered through the codebase.

```elm
-- The only way to construct a School name is through this function.
-- The Name type is opaque; you cannot create one any other way.
type Name = Name String

nameFromString : String -> Result (List Error) Name
nameFromString raw =
    let
        trimmed = String.trim raw
    in
    if trimmed == "" then
        Err [ Error "School name cannot be blank" ]
    else
        Ok (Name trimmed)
```

In a form, run the smart constructor on every input change and
store the `Result` in the Model. Validation feedback appears as
the user types, not after submit.

**Sources:** Alexis King, *Parse, Don't Validate*; ADR-009;
Feldman, *Make Data Structures*.

---

## 5. Communicate through types

Custom types around primitives buy compiler-enforced argument
order, unit safety, and rejection of nonsensical operations. Type
aliases do not — the compiler cannot tell `Float` from `Float`.

```elm
-- Wrong: argument order errors will not compile-fail.
speed : Float -> Float -> Float
speed distance time = distance / time

-- Right: distance and time are distinct types. Mixing them up
-- fails to compile.
type Meters = Meters Float
type Seconds = Seconds Float
type MetersPerSecond = MetersPerSecond Float

speed : Meters -> Seconds -> MetersPerSecond
speed (Meters d) (Seconds t) = MetersPerSecond (d / t)
```

For "same data, distinct meaning" use **phantom types**:

```elm
type Currency a = Currency Float

type USD = USD
type EUR = EUR

usd : Float -> Currency USD
usd amount = Currency amount

add : Currency a -> Currency a -> Currency a
add (Currency x) (Currency y) = Currency (x + y)
-- add (usd 5) (eur 10) → compile error
```

**Introduce these gradually.** Start with `Float` or `String`,
switch one site, the compiler tells you everywhere it leaks.

For IDs: phantom-typed `Id a` or per-entity opaque IDs are both
idiomatic. Pick whichever fits each case. The constraint: no
persisted entity uses raw `String` for its ID, and the compiler
must reject mixing IDs from different entities.

**Source:** Quenneville, *What's in a Number?*

---

## 6. Develop incrementally, with the compiler as feedback loop

The development workflow:

1. **Make a wish.** Write code as if it existed. Reference types
   and functions you have not yet defined.
2. **Let the compiler tell you what's missing.** Add the minimum
   to satisfy the next compiler error.
3. **Fake it till you make it.** Hard-code values to get to green.
4. **Make the change easy, then make the easy change** (Beck).
   Refactor the code into a shape where the next change is
   trivial. Then make that next change.
5. **Validate end-to-end as quickly as possible.** Wire the whole
   pipeline with hard-coded values; *then* go back and fill in
   the real implementations.

This is how you stay in the build–discover–refactor cycle without
overdesigning.

**Source:** Kearns, *Incremental Type Driven Development*.

---

## 7. Test scope: business logic only

Tests target business rules and algorithms, **not** data
validation or type-system guarantees.

### Test these

- Business rules encoded in smart constructors (e.g. "names must
  be non-blank", "rosters must have 8–25 students", "year must be
  2000–2100").
- Pure algorithmic functions (e.g. `PowerMatch.powerMatch`,
  `Standings.compute`, `BallotAssembly` aggregations).
- State transitions on lifecycle entities (e.g. "a `Draft`
  tournament can become `Registration` but not `Active`
  directly").
- Decoder behavior on actual fixture JSON when the decoder runs
  business validation (e.g. "this real PocketBase response decodes
  into a domain `School` correctly").

### Do not test these

- Decoder mechanics for round-tripping JSON (the compiler and
  `elm/json` handle the mechanics).
- Trivial accessor functions.
- "Impossible" branches that the type system already excludes.
- Type-conformance that the compiler enforces.

### Refactor signal

If a business rule is hard to test, it is living in the wrong
place — usually inside a view function or update wiring. Extract
it to a pure module. TDD is the forcing function: writing the test
first prevents you from accidentally entangling the rule with the
view.

**Sources:** Feldman, *Elm in the Spring 2020* keynote; Kearns,
[*To test or not to test*](https://incrementalelm.com/to-test-or-not-to-test/).

---

## 8. Page module conventions (Elm Land)

Pages follow the elm-land conventions, which we do not modify:

- File path determines the route. `Pages/Admin/Schools.elm` →
  `/admin/schools`.
- The `page` function:

  ```elm
  page : Auth.User -> Shared.Model -> Route () -> Page Model Msg
  page _ _ _ =
      Page.new { init, update, view, subscriptions }
          |> Page.withLayout (\_ -> Layouts.Admin {})
  ```

- `init`/`update` return `( Model, Effect Msg )`, not `Cmd`.
- `view : Model -> View Msg` returns `{ title, body }`.
- All I/O goes through `Effect`. PocketBase calls go through the
  domain module's typed network functions (which internally use
  `Pb`).
- Pages import only domain modules and `Effect`. They never import
  `Api` or `Pb` directly. The `NoPbOrApiInMigratedPages`
  elm-review rule enforces this per-page as the migration
  proceeds.
- Form state lives in the page Model. Field-change messages call
  smart constructors on the input and store the `Result`.
- View helpers are functions (`viewForm`, `viewRow`), not modules
  with their own `Msg`/`Model`. Components-with-state are
  forbidden — see Czaplicki: "actively trying to make components
  is a recipe for disaster in Elm."
- View helpers shared across pages live in `UI.elm` (existing
  convention) or, if substantial, in a `Components/` module that
  exposes only pure view functions.

**Sources:** elm-land's `realworld-app`; the official guide on
Web Apps — Structure; project ADR-008 (URL design).

---

## 9. Style mechanics

- 4-space indent.
- Type annotations on every top-level declaration.
- Imports: prefer non-exposing; expose explicitly when needed;
  avoid `exposing (..)` except for tagged-union constructors when
  pattern matching is the API.
- Pipe operators (`|>`, `<|`) on new lines, not buried in
  expressions.
- Records: leading-comma style.
- Markdown documentation: word-wrap at 80 characters.

**Source:** [ohanhi/elm-style-guide](https://github.com/ohanhi/elm-style-guide).

---

## Reference reading

Read before contributing major changes:

- Official guide: [Web Apps — Structure](https://guide.elm-lang.org/webapps/structure)
- elm-land: [`realworld-app`](https://github.com/elm-land/realworld-app)
- Czaplicki, *The Life of a File* (Elm Europe 2017)
- Feldman, *Make Data Structures*
- Feldman, *Immutable Relational Data*
- Feldman, *Making Impossible States Impossible*
- Kearns, *Incremental Type Driven Development* (Elm Europe 2019)
- Kearns, [*To test or not to test*](https://incrementalelm.com/to-test-or-not-to-test/)
- Fairbank, *Solving the Boolean Identity Crisis*
- Quenneville, *What's in a Number?*
- King, *Parse, Don't Validate*
- Wlaschin, *Domain Modeling Made Functional* (book; F# but principles transfer)
