# Domain Model Audit

Comprehensive audit of all 24 domain modules against
least-privilege/max-enforcement principles.

**Guiding rule:** Every type is opaque unless there is a
concrete reason to expose its internals. Construction
happens through exactly two paths:
1. **JSON decoding** (from PocketBase)
2. **Smart constructor or type promotion** (from
   validated input or another type)

If a type is a `type alias`, any module can construct
it directly — the transition functions (`verify`,
`create`, `fromPairing`) become suggestions, not
enforcement. Opaque types with accessors are the fix.

---

## Layer 1: Organizational

### District.elm

**Current:** `Name(..)` exposed, `District` is a
transparent `type alias`.

**Problem:** `Name ""` compiles. Any module can
construct `District.Name` directly, bypassing any
future validation. `District` is a bare record — any
`{ name : Name }` value IS a `District`.

**Construction paths:**
- Admin form input → `Name.fromString`
- JSON decode from PocketBase

**Fix:**
```elm
module District exposing
    ( District, Name, create, name, nameToString )

type Name = Name String

fromString : String -> Maybe Name  -- non-empty

type District = District { name : Name }

create : Name -> District
name : District -> Name
nameToString : Name -> String
```

**Severity:** Medium. Low risk in isolation, but sets
a bad precedent — every other `Name` type copies this
pattern.

---

### School.elm

**Current:** Same as District — `Name(..)` exposed,
`School` is transparent.

**Problem:** Same as District. Additionally, `School`
is a record alias, so `{ name = anyName, district =
anyDistrict }` IS a `School` with no validation.

**Construction paths:**
- Admin form → smart constructor
- JSON decode from PocketBase

**Fix:** Same pattern as District. Opaque `Name` with
`fromString : String -> Maybe Name`. Opaque `School`
with `create : Name -> District -> School` and
accessors.

**Severity:** Medium.

---

### Student.elm

**Current:** `Name` is a `type alias` for a bare
record `{ first : String, last : String, preferred :
Maybe String }`. `Student` is a transparent
`type alias`.

**Problem:** `Student.Name` is not a nominal type at
all — it is structurally identical to any record with
the same fields. There is no validation. An empty
first name, empty last name, or `{ first = "", last =
"", preferred = Nothing }` are all valid.
`Student.Name` is also reused for coach names (see
Coach below), which is semantically wrong.

**Construction paths:**
- Coach submits eligible student list (form)
- JSON decode from PocketBase

**Fix:**
```elm
type Name = Name { first : String, last : String
    , preferred : Maybe String }

fromName : String -> String -> Maybe String
    -> Maybe Name
-- non-empty first, non-empty last
```

Opaque `Student` with `create : Name -> Pronouns ->
Student` and accessors `name`, `pronouns`.

**Severity:** High. `Student.Name` is referenced by
`Coach`, `Team`, `Roster`, `SubmittedBallot`, `Rank`
— fixing this propagates widely.

---

### Email.elm

**Current:** `type alias Email = String`.

**Problem:** The single worst primitive obsession in
the codebase. `Email` IS `String` at the type level.
Any `String` function works on it. Any `String` value
passes where `Email` is expected. Zero type safety.

**Construction paths:**
- Form input (coach registration)
- JSON decode from PocketBase

**Fix:**
```elm
type Email = Email String

fromString : String -> Maybe Email
-- non-empty, contains '@' at minimum
toString : Email -> String
```

**Severity:** High.

---

### Coach.elm

**Current:** All three types (`TeacherCoachApplicant`,
`TeacherCoach`, `AttorneyCoach`) are transparent
`type alias` records. Coach names reuse
`Student.Name`.

**Problems:**
1. `TeacherCoach` can be constructed directly,
   completely bypassing `verify`. The states-as-types
   pattern is theater — it looks like enforcement but
   any module can write
   `{ name = n, email = e } : TeacherCoach`.
2. Coach names use `Student.Name`. A coach name and a
   student name are semantically different (coaches
   have first + last only, no preferred name or
   pronouns). Passing a `Student.Name` where a coach
   name is expected compiles silently.

**Construction paths:**
- `TeacherCoachApplicant`: teacher registration form
  or JSON decode. Requires valid `Coach.Name` + valid
  `Email`.
- `TeacherCoach`: ONLY via `verify` or JSON decode
  (already verified in PocketBase).
- `AttorneyCoach`: teacher adds them via form, or
  JSON decode. Requires valid `Coach.Name`, optional
  `Email`.

**Fix:**
```elm
type Name = Name { first : String, last : String }

nameFromStrings : String -> String -> Maybe Name
-- non-empty first, non-empty last

type TeacherCoachApplicant =
    TeacherCoachApplicant { name : Name, email : Email }

type TeacherCoach =
    TeacherCoach { name : Name, email : Email }

type AttorneyCoach =
    AttorneyCoach { name : Name, email : Maybe Email }

-- Applicant constructor
apply : Name -> Email -> TeacherCoachApplicant

-- State promotion — the ONLY way to get TeacherCoach
-- besides JSON decode
verify : TeacherCoachApplicant -> TeacherCoach

-- AttorneyCoach constructor
createAttorneyCoach : Name -> Maybe Email
    -> AttorneyCoach

-- Accessors for all three types
name : TeacherCoach -> Name  -- (etc.)
```

**Severity:** High. The `TeacherCoach` bypass
undermines the central design pattern of the codebase.

---

### Team.elm

**Current:** `Number(..)` exposed, `Team` is
transparent, `name : String` is a raw primitive.

**Problems:**
1. `Number(..)` exposed — `Number -5` compiles.
2. `name : String` — raw primitive while every other
   entity wraps its name.
3. `Team` is a `type alias` — any record with the
   right shape IS a `Team`.
4. `students : List Student` — empty list is the
   normal case during registration (teams register
   Aug/Sep, students submitted Dec). This is
   intentional, but it means a `Team` with zero
   students is always valid, and roster validation
   must check against the team's student list
   separately.

**Construction paths:**
- Admin creates team during registration
- JSON decode from PocketBase

**Fix:**
```elm
type Number = Number Int

fromInt : Int -> Int -> Maybe Number
-- or: fromInt : Int -> Maybe Number with
-- positive-only; upper bound enforced elsewhere

type Name = Name String

nameFromString : String -> Maybe Name

type Team = Team
    { number : Number
    , name : Name
    , school : School
    , students : List Student
    , teacherCoach : TeacherCoach
    , attorneyCoach : Maybe AttorneyCoach
    }
```

Team.Number: positive integer, 1-based. The upper
bound (number of teams) is a tournament-level
constraint, not a Team-level one — enforce at the
boundary, not in the type.

**Severity:** Medium-High. `name : String` is
inconsistent; `Number(..)` exposure is a gap.

---

### Side.elm

**Current:** `Side(..)` exposed.

**Assessment:** This is correct. `Side` is a closed
enum with exactly two values. Exposing constructors
is appropriate — there is nothing to guard. Pattern
matching on `Prosecution | Defense` is the intended
usage.

**No changes needed.**

---

### Role.elm

**Current:** `Role(..)` and `Witness(..)` both
exposed. `Role.Witness` is a single-case union
wrapping `String`.

**Problems:**
1. `Role.Witness` and `Witness.Witness` are two
   different types with the same name. Any module
   importing both needs qualification. This is a
   naming collision that will cause confusion.
2. `Role.Witness` wraps a raw `String` — but it
   exists to identify which witness character a
   student is playing. With the revised `Witness`
   model (name + description), `Role` should
   reference `Witness.Witness` directly.

**Fix:** Remove `Role.Witness`. Have `ProsecutionWitness`
and `DefenseWitness` carry a `Witness.Witness`:
```elm
type Role
    = ProsecutionPretrial
    | ProsecutionAttorney
    | ProsecutionWitness Witness
    | DefensePretrial
    | DefenseAttorney
    | DefenseWitness Witness
    | Clerk
    | Bailiff
```

Where `Witness` is imported from `Witness.elm`. This
eliminates the naming collision entirely, and the
`Role` variants now carry the full witness identity
(name + description) instead of a bare string.

`Role(..)` constructors should remain exposed — they
are a closed set of domain values, like `Side`.

**Severity:** Medium. The naming collision is a
maintainability hazard. The model mismatch (bare
string vs. structured witness) is a correctness issue
that will surface when building UI.

---

### Assignment.elm

**Current:** `Assignment(..)` exposed (generic).

**Assessment:** `Assignment a` is a generic utility
type (`NotAssigned | Assigned a`). Exposing
constructors is appropriate — it is used for pattern
matching in `Trial.fromPairing` and `Pairing`
internals. The type parameter `a` provides the
safety.

**No changes needed.**

---

## Layer 2: Competition Structure

### Tournament.elm

**Current:** `Status(..)` exposed, `Config` and
`Tournament` are transparent `type alias` records.
`name : String`, `year : Int`, round counts are raw
`Int`.

**Problems:**
1. All primitives unguarded — `year = -1`,
   `numPreliminaryRounds = 0`, `name = ""` all
   compile.
2. `Status(..)` exposed — any code can construct a
   `Completed` tournament directly, skipping the
   state machine (Draft → Registration → Active →
   Completed).
3. `Config` is transparent — negative round counts
   are valid.

**Construction paths:**
- Admin creates tournament via form
- JSON decode from PocketBase
- Status transitions via admin action

**Fix:**
```elm
type Tournament = Tournament
    { name : Name
    , year : Year
    , config : Config
    , status : Status
    }

type Name = Name String
type Year = Year Int
type Config = Config
    { numPreliminaryRounds : Int
    , numEliminationRounds : Int
    }

type Status = Draft | Registration | Active
    | Completed

-- Smart constructors
createName : String -> Maybe Name
createYear : Int -> Maybe Year
createConfig : Int -> Int -> Maybe Config
-- positive round counts

create : Name -> Year -> Config -> Tournament
-- always starts as Draft

-- State transitions (applicative validation)
openRegistration : Tournament -> Result Error Tournament
activate : Tournament -> Result Error Tournament
complete : Tournament -> Result Error Tournament
```

Status transitions enforce the state machine. Each
transition validates the precondition (e.g.,
`activate` requires `Registration` status). `Status`
constructors are NOT exposed — status changes only
happen through transition functions (or JSON decode).

**Severity:** Medium-High. The state machine
enforcement is important for admin workflows.

---

### Round.elm

**Current:** `Round(..)` and `Phase(..)` exposed.

**Assessment:** Correct. These are closed enums.
`Round` exhaustively enumerates all 7 rounds.
`Phase` is derived via pattern match. Exposing
constructors is appropriate.

**No changes needed.**

---

### Courtroom.elm

**Current:** `Name` is opaque (constructor not
exposed). `name : String -> Name` is a smart
constructor but accepts any string including empty.
`Courtroom` is a transparent `type alias`.

**Problems:**
1. `name ""` is valid — no empty-string guard.
2. `Courtroom` is transparent.

**Fix:**
```elm
type Name = Name String
type Courtroom = Courtroom { name : Name }

name : String -> Maybe Name  -- non-empty
create : Name -> Courtroom
courtroomName : Courtroom -> Name
nameToString : Name -> String
```

**Severity:** Low-Medium. Courtroom is already the
best-implemented `Name` type — just needs the
`Maybe` guard and opaque `Courtroom`.

---

### Judge.elm

**Current:** `Judge(..)` is a unit type placeholder.

**Assessment:** Intentionally stubbed. Exposing the
constructor is fine for a unit type. When judge data
is added (name, credentials), it should follow the
opaque pattern.

**No changes needed (yet).**

---

### Pairing.elm

**Current:** `Pairing` is a transparent `type alias`.
`create : Team -> Team -> Pairing` does not guard
against self-pairing.

**Problems:**
1. Transparent — any module can construct a `Pairing`
   directly, bypassing `create` (and the
   `NotAssigned` initial state).
2. `create teamA teamA` compiles — a team paired
   against itself.

**Construction paths:**
- PowerMatch algorithm
- Admin manual pairing
- JSON decode from PocketBase

**Fix:**
```elm
type Pairing = Pairing
    { prosecution : Team
    , defense : Team
    , courtroom : Assignment Courtroom
    , judge : Assignment Judge
    }

create : Team -> Team -> Maybe Pairing
-- Nothing if same team; starts NotAssigned

-- Accessors
prosecution : Pairing -> Team
defense : Pairing -> Team
courtroom : Pairing -> Assignment Courtroom
judge : Pairing -> Assignment Judge

-- Transitions
assignCourtroom : Courtroom -> Pairing -> Pairing
assignJudge : Judge -> Pairing -> Pairing
```

`Trial.fromPairing` needs accessors instead of
direct field access.

**Severity:** Medium-High. Self-pairing is a real bug
waiting to happen in PowerMatch integration.

---

### Trial.elm

**Current:** `Trial` is a transparent `type alias`.
`fromPairing` is the intended constructor but can be
bypassed.

**Problem:** Any module can construct `Trial` directly
with `{ prosecution = t1, defense = t2, courtroom =
c, judge = j }`, skipping the Pairing → Trial
promotion. The type-level guarantee documented in
`domain-roadmap.md` ("fromPairing succeeds only when
all assignments are filled") is not enforced.

**Construction paths:**
- ONLY `fromPairing` (or JSON decode of an already-
  promoted trial)

**Fix:**
```elm
type Trial = Trial
    { prosecution : Team
    , defense : Team
    , courtroom : Courtroom
    , judge : Judge
    }

fromPairing : Pairing -> Maybe Trial

-- Accessors
prosecution : Trial -> Team
defense : Trial -> Team
courtroom : Trial -> Courtroom
judge : Trial -> Judge
```

**Severity:** Medium. The Pairing → Trial promotion
is the poster child for this codebase's design
philosophy. It must actually be enforced.

---

### Witness.elm

**Current:** Opaque type wrapping a single `String`.
`fromString` accepts any string including empty.

**Problems:**
1. A witness is not just a name — it's a character
   with a name AND a role/description. The current
   model cannot represent "Detective Nova Perren
   (Lead Investigator)".
2. `fromString ""` is valid.
3. The `Role.Witness` naming collision (see Role.elm).

**Construction paths:**
- Admin defines witnesses when creating tournament
  (4 prosecution + 4 defense character names)
- JSON decode from PocketBase

**Fix:**
```elm
type Witness = Witness
    { name : String
    , description : String
    }

create : String -> String -> Maybe Witness
-- non-empty name, non-empty description

name : Witness -> String
description : Witness -> String
```

This is tournament-level data set once by admin. The
`description` field helps scorers identify witnesses
("the detective", "the medical examiner") even when
they can't remember character names.

**Severity:** High. The model is structurally wrong —
it's missing data that scorers need and that the case
materials define.

---

### Roster.elm

**Current:** `Roster` is a transparent `type alias`
with `assignments : List RoleAssignment`. All
constructors exposed. No validation.

**Problems:**
1. `Roster { assignments = [] }` is valid — but an
   incomplete roster is never valid per domain rules.
2. No enforcement of roster composition rules:
   - 1 clerk
   - 1 bailiff
   - 1 pretrial attorney
   - 4 witnesses (each assigned a witness character)
   - 1–3 trial attorneys (with specific duties)
   - Pretrial attorney may double as witness; no
     other student may have multiple roles
3. Transparent — bypasses any future validation.

**Construction paths:**
- Coach submits roster via form
- JSON decode from PocketBase

**Fix:**
```elm
type Roster = Roster (List RoleAssignment)

type alias RosterError = ...  -- specific violations

create : List RoleAssignment -> Result RosterError Roster
-- validates:
--   exactly 1 clerk
--   exactly 1 bailiff
--   exactly 1 pretrial attorney
--   exactly 4 witnesses
--   1-3 trial attorneys
--   no duplicate students (except pretrial + witness)

assignments : Roster -> List RoleAssignment
```

`RoleAssignment` constructors can stay exposed — they
are value constructors for the inputs to `create`.
The enforcement happens at the `Roster` boundary.

This is an applicative-style validation: collect all
errors, don't short-circuit on the first one.

**Severity:** High. This is the most complex
validation in the domain and currently has zero
enforcement.

---

## Layer 3: Scoring

### SubmittedBallot.elm

**Current:** `Points` is opaque with `fromInt :
Int -> Maybe Points` (1–10). `ScoredPresentation(..)`
constructors exposed. `SubmittedBallot` is a
transparent `type alias`.

**Problems:**
1. `SubmittedBallot { presentations = [] }` is valid.
   An empty ballot is meaningless.
2. Transparent — any module can construct one.
3. `ScoredPresentation(..)` constructors are exposed,
   but this is acceptable because `Points` already
   guards the score range and `Side`/`Student` are
   domain types. The presentations are building
   blocks; the ballot is the enforcement boundary.

**Construction paths:**
- Scorer form submission
- JSON decode from PocketBase

**Fix:**
```elm
type SubmittedBallot =
    SubmittedBallot (List ScoredPresentation)

create : List ScoredPresentation
    -> Maybe SubmittedBallot  -- non-empty

presentations : SubmittedBallot
    -> List ScoredPresentation
```

`VerifiedBallot.verify` and `PrelimResult.courtTotal`
currently access `ballot.presentations` directly —
they need the accessor.

**Severity:** Medium-High.

---

### VerifiedBallot.elm

**Current:** Transparent `type alias`. `verify` and
`verifyWithCorrections` are the intended constructors
but can be bypassed.

**Problem:** The entire ballot lifecycle
(Submitted → Verified) is undermined. Any module can
write `{ original = sb, presentations = [] }` and
call it a `VerifiedBallot`. The audit trail guarantee
("original submission is immutable — never
overwritten") is not enforced by the type system.

**Construction paths:**
- ONLY `verify` or `verifyWithCorrections` (or JSON
  decode of already-verified ballot)

**Fix:**
```elm
type VerifiedBallot = VerifiedBallot
    { original : SubmittedBallot
    , presentations : List ScoredPresentation
    }

verify : SubmittedBallot -> VerifiedBallot
verifyWithCorrections : SubmittedBallot
    -> List ScoredPresentation -> VerifiedBallot

-- Accessors
original : VerifiedBallot -> SubmittedBallot
presentations : VerifiedBallot
    -> List ScoredPresentation
```

`PrelimResult.courtTotal` changes from
`ballot.presentations` to
`VerifiedBallot.presentations ballot`.

**Severity:** High. This is the same class of bug as
`TeacherCoach` — the state promotion exists but
doesn't actually enforce anything.

---

### PresiderBallot.elm

**Current:** Transparent `type alias`.

**Problem:** Any module can construct
`{ winner = Prosecution }` directly, bypassing `for`.
Minor issue since `Side` is fully constrained, but
inconsistent with the enforcement philosophy.

**Fix:**
```elm
type PresiderBallot = PresiderBallot Side

for : Side -> PresiderBallot
winner : PresiderBallot -> Side
```

**Severity:** Low. `Side` has only two valid values,
so there's nothing dangerous to construct. But
opaqueness is cheap and consistent.

---

### Rank.elm

**Current:** `Rank` is opaque with `fromInt` smart
constructor (1–5). `Nomination` is a transparent
`type alias`.

**Problems:**
1. `rankPoints : Int -> Rank -> Int` — the `Int`
   parameter (nominee count) is an unconstrained
   primitive. A negative count produces nonsensical
   points.
2. `Nomination` is transparent — any module can
   construct one. All fields are individually guarded
   (`Role`, `Student`, `Rank`), so the risk is low.

**Fix:**
```elm
type alias Nomination =
    { role : Role, student : Student, rank : Rank }
```

`Nomination` can stay as-is — the constituent types
provide the enforcement. Making it opaque would add
friction without preventing any real invalid state
(any combination of valid `Role` + `Student` + `Rank`
is a valid nomination).

`rankPoints` — consider a `NomineeCount` type or
guard: `rankPoints : Int -> Rank -> Maybe Int` where
count must be positive. Or accept this as an internal
computation where the caller (the awards module)
always provides a valid count.

**Severity:** Low.

---

## Layer 4: Results (Computed)

### PrelimResult.elm

**Current:** `PrelimVerdict(..)` exposed. Pure
functions over `VerifiedBallot`.

**Problem:** `prelimVerdict []` returns
`CourtTotalTied`. An empty ballot list silently
produces a "tie" — this is a bug that produces
correct-looking but meaningless results.

**Fix:**
```elm
prelimVerdict : List VerifiedBallot
    -> Maybe PrelimVerdict
-- Nothing on empty list

-- or use a NonEmpty list type:
prelimVerdict : ( VerifiedBallot, List VerifiedBallot )
    -> PrelimVerdict
```

`PrelimVerdict(..)` should stay exposed — it's an
output enum for pattern matching.

**Severity:** Medium. Silent wrong answers are worse
than crashes.

---

### ElimResult.elm

**Current:** Same pattern as PrelimResult. `elimVerdict
[]` returns `ScorecardsTied`.

**Fix:** Same — return `Maybe` or require non-empty.

**Severity:** Medium.

---

### Standings.elm

**Current:** `TeamRecord` is a transparent
`type alias` with all raw `Int` fields.

**Problem:** `TeamRecord { wins = -3, losses = -1,
pointsFor = -100, pointsAgainst = 0 }` compiles.
`TeamRecord` is a computed aggregate — it should only
be constructed by the function that aggregates round
results, never by hand.

**Construction paths:**
- ONLY computed from verified round results. Never
  from user input. Never persisted (per roadmap).

**Fix:**
```elm
type TeamRecord = TeamRecord
    { wins : Int
    , losses : Int
    , pointsFor : Int
    , pointsAgainst : Int
    }

fromRoundResults : ... -> TeamRecord
-- the only constructor besides JSON decode
-- (if we ever persist standings)

-- Accessors
wins : TeamRecord -> Int
losses : TeamRecord -> Int
pointsFor : TeamRecord -> Int
pointsAgainst : TeamRecord -> Int
```

**Severity:** Low-Medium. Computed-only types have
lower risk, but opaqueness prevents test shortcuts
that mask integration bugs.

---

### Awards.elm

**Current:** `AwardCategory(..)` and
`AwardTiebreaker(..)` exposed. `AwardCriteria` is a
transparent `type alias` for `List AwardTiebreaker`.

**Assessment:** These are output/configuration enums
for pattern matching and strategy composition.
Exposing constructors is appropriate. `AwardCriteria`
as `List AwardTiebreaker` is fine — it's a
configuration value, not a domain entity.

**Note:** `BestWitness Witness` will automatically
carry the richer `Witness` type (name + description)
once `Witness.elm` is updated. No changes needed
here.

**No changes needed.**

---

## Cross-Module Impact: Accessor Requirements

When types go opaque, these cross-module field
accesses break and need accessors:

| Call Site | Field Access | Needs |
|-----------|-------------|-------|
| `Coach.verify` | `applicant.name`, `applicant.email` | `TeacherCoachApplicant.name`, `.email` |
| `Trial.fromPairing` | `pairing.courtroom`, `.judge`, `.prosecution`, `.defense` | `Pairing.courtroom`, `.judge`, `.prosecution`, `.defense` |
| `PresiderBallot.winner` | `ballot.winner` | Already a function; just change implementation |
| `PrelimResult.courtTotal` | `ballot.presentations` | `VerifiedBallot.presentations` |
| `VerifiedBallot.verify` | `ballot.presentations` | `SubmittedBallot.presentations` |

---

## Priority Order

### Tier 1: Broken enforcement (states-as-types
pattern is theater without these)
1. **VerifiedBallot** — opaque (verify bypass)
2. **Coach.TeacherCoach** — opaque (verify bypass)
3. **SubmittedBallot** — opaque + non-empty guard
4. **Pairing** — opaque + self-pairing guard
5. **Trial** — opaque (fromPairing bypass)

### Tier 2: Primitive obsession (wrong types)
6. **Email** — opaque with validation
7. **Witness** — restructure (name + description)
8. **Role.Witness** — replace with Witness.Witness
9. **Coach.Name** — own type, not Student.Name
10. **Student.Name** — opaque with validation
11. **Team.Name** — new wrapper type
12. **Team.Number** — opaque with positive guard

### Tier 3: Consistency and completeness
13. **District.Name, School.Name** — opaque
14. **Courtroom.Name** — add Maybe guard
15. **Tournament** — opaque + state machine
16. **Roster** — opaque + composition validation
17. **PresiderBallot** — opaque (minor)
18. **TeamRecord** — opaque (computed only)

### Tier 4: Function-level guards
19. **prelimVerdict / elimVerdict** — guard empty lists
20. **Rank.rankPoints** — guard negative count

---

## Summary of New Types Needed

| New Type | Replaces | Module |
|----------|----------|--------|
| `Coach.Name` | reuse of `Student.Name` | Coach.elm |
| `Team.Name` | raw `String` | Team.elm |
| `Tournament.Name` | raw `String` | Tournament.elm |
| `Tournament.Year` | raw `Int` | Tournament.elm |
| `Witness.{ name, description }` | single `String` | Witness.elm |

## Types That Should Stay Exposed

| Type | Reason |
|------|--------|
| `Side(..)` | Closed enum, 2 values, pattern matching intended |
| `Round(..)` | Closed enum, 7 values, pattern matching intended |
| `Phase(..)` | Closed enum, 2 values, derived from Round |
| `Role(..)` | Closed enum, pattern matching intended |
| `Assignment(..)` | Generic utility, pattern matching intended |
| `Pronouns(..)` | Closed enum + `Other`, pattern matching intended |
| `ScoredPresentation(..)` | Value constructor; guarded by Points, Side, Student |
| `RoleAssignment(..)` | Value constructor; input to Roster.create |
| `AttorneyDuty(..)` | Closed enum, part of RoleAssignment |
| `Weight(..)` | Output enum |
| `PrelimVerdict(..)` | Output enum |
| `ElimVerdict(..)` | Output enum |
| `ScorecardResult(..)` | Output enum |
| `NominationCategory(..)` | Output enum |
| `Tiebreaker(..)` | Config enum |
| `AwardCategory(..)` | Config enum |
| `AwardTiebreaker(..)` | Config enum |
