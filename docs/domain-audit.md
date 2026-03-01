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

### District.elm — DONE (Tier 3, commit d459e55)

Opaque `Name` with `nameFromString` (rejects blank,
trims). Opaque `District` with `create` and
`districtName` accessor. Smart constructor returns
`Result (List Error) Name`.

---

### School.elm — DONE (Tier 3, commit d459e55)

Opaque `Name` with `nameFromString` (rejects blank,
trims). Opaque `School` with `create`, `schoolName`,
and `district` accessors. Smart constructor returns
`Result (List Error) Name`.

---

### Student.elm — DONE (Tier 2, commit 827384d)

Opaque `Name` with `nameFromStrings` (rejects blank
first/last, trims). Opaque `Student` with `create`,
`name`, `pronouns` accessors.

---

### Email.elm — DONE (Tier 2, commit 827384d)

Opaque `Email` with `fromString` (format validation
via elm-validate). `toString` accessor.

---

### Coach.elm — DONE (Tier 1, commit 86a9c1b)

All three coach types opaque. `Coach.Name` is its own
type (first+last only, not `Student.Name`).
`nameFromStrings` smart constructor. State promotion
via `verify` enforced.

---

### Team.elm — DONE (Tier 2, commit 827384d)

Opaque `Name` with `nameFromString`, opaque `Number`
with `numberFromInt` (positive guard). Opaque `Team`
with `create` and accessors.

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

### Role.elm — DONE (Tier 2, commit 827384d)

`Role.Witness` collision eliminated. Role now imports
`Witness` from `Witness.elm`. Constructors remain
exposed (closed enum).

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

### Tournament.elm — DONE (Tier 3, commit d459e55)

Opaque `Name`, `Year` (2000–2100), `Config` (positive
rounds), `Status`, and `Tournament`. State machine
enforced: `Draft→Registration→Active→Completed` via
`openRegistration`, `activate`, `complete`. Invalid
transitions return `Result (List Error) Tournament`.
`statusToString` works via accessor. `Status`
constructors not exposed.

---

### Round.elm

**Current:** `Round(..)` and `Phase(..)` exposed.

**Assessment:** Correct. These are closed enums.
`Round` exhaustively enumerates all 7 rounds.
`Phase` is derived via pattern match. Exposing
constructors is appropriate.

**No changes needed.**

---

### Courtroom.elm — DONE (Tier 3, commit d459e55)

Opaque `Name` with `nameFromString` (rejects blank,
trims). Opaque `Courtroom` with `create` and
`courtroomName` accessor.

---

### Judge.elm

**Current:** `Judge(..)` is a unit type placeholder.

**Assessment:** Intentionally stubbed. Exposing the
constructor is fine for a unit type. When judge data
is added (name, credentials), it should follow the
opaque pattern.

**No changes needed (yet).**

---

### Pairing.elm — DONE (Tier 1, commit 86a9c1b)

Opaque `Pairing` with self-pairing guard. `create`
returns `Result (List Error) Pairing`. Accessors and
transition functions (`assignCourtroom`, `assignJudge`).

---

### Trial.elm — DONE (Tier 1, commit 86a9c1b)

Opaque `Trial`. `fromPairing` is the only constructor.
Accessors for all fields.

---

### Witness.elm — DONE (Tier 2, commit 827384d)

Opaque `Witness` with `create` (name + description,
both non-empty). `name` and `description` accessors.

---

### Roster.elm — PARTIALLY DONE (Tier 3, commit d459e55)

Opaque `Roster` with `create` (rejects empty list)
and `assignments` accessor. `RoleAssignment` and
`AttorneyDuty` constructors remain exposed (value
constructors).

**Deferred:** Full composition validation (exact
counts for clerk, bailiff, witnesses, attorneys;
no-duplicate-student rule) deferred to its own issue.

---

## Layer 3: Scoring

### SubmittedBallot.elm — DONE (Tier 1, commit 86a9c1b)

Opaque `SubmittedBallot` with non-empty guard.
`presentations` accessor.

---

### VerifiedBallot.elm — DONE (Tier 1, commit 86a9c1b)

Opaque `VerifiedBallot`. `verify` and
`verifyWithCorrections` are the only constructors.
`original` and `presentations` accessors.

---

### PresiderBallot.elm — DONE (Tier 1, commit 86a9c1b)

Opaque `PresiderBallot`. `for` constructor, `winner`
accessor.

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

`rankPoints` now guarded — returns
`Result (List Error) Int`, rejects non-positive count.

**Severity:** Low. (Done in Tier 4.)

---

## Layer 4: Results (Computed)

### PrelimResult.elm — DONE (Tier 4, commit cd37320)

`prelimVerdict` and `prelimVerdictWithPresider` now
return `Result (List Error)`, rejecting empty ballot
lists. `PrelimVerdict(..)` still exposed (output enum).

---

### ElimResult.elm — DONE (Tier 4, commit cd37320)

`elimVerdict` and `elimVerdictWithPresider` now return
`Result (List Error)`, rejecting empty ballot lists.
`ElimVerdict(..)` still exposed (output enum).

---

### Standings.elm — DONE (Tier 3, commit d459e55)

Opaque `TeamRecord` with `teamRecord` constructor
(no validation — computed values are trusted) and
`wins`, `losses`, `pointsFor`, `pointsAgainst`
accessors.

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

All cross-module accessor requirements have been
resolved in Tiers 1–3.

---

## Priority Order

### Tier 1: DONE (commit 86a9c1b, 215 tests)
1. ~~VerifiedBallot~~ — opaque
2. ~~Coach.TeacherCoach~~ — opaque
3. ~~SubmittedBallot~~ — opaque + non-empty guard
4. ~~Pairing~~ — opaque + self-pairing guard
5. ~~Trial~~ — opaque

### Tier 2: DONE (commit 827384d, 257 tests)
6. ~~Email~~ — opaque with validation
7. ~~Witness~~ — restructured (name + description)
8. ~~Role.Witness~~ — replaced with Witness.Witness
9. ~~Coach.Name~~ — own type
10. ~~Student.Name~~ — opaque with validation
11. ~~Team.Name~~ — new wrapper type
12. ~~Team.Number~~ — opaque with positive guard

### Tier 3: DONE (commit d459e55, 312 tests)
13. ~~District.Name, School.Name~~ — opaque
14. ~~Courtroom.Name~~ — non-empty guard + opaque
15. ~~Tournament~~ — opaque + state machine
16. ~~Roster~~ — opaque + non-empty guard
    (composition validation deferred)
17. ~~PresiderBallot~~ — already done in Tier 1
18. ~~TeamRecord~~ — opaque (computed only)

### Tier 4: DONE (commit cd37320, 318 tests)
19. ~~prelimVerdict / elimVerdict~~ — guard empty lists
20. ~~Rank.rankPoints~~ — guard non-positive count

## Follow-up

- **elm-validate consistency** (issue #29): Migrate
  all manual `if/else` validators to elm-validate for
  consistent error accumulation.
- **Roster composition validation**: Full count/role
  enforcement deferred to its own issue.

---

## Summary of New Types Added

| New Type | Replaces | Module | Tier |
|----------|----------|--------|------|
| `Coach.Name` | reuse of `Student.Name` | Coach.elm | 1 |
| `Team.Name` | raw `String` | Team.elm | 2 |
| `Team.Number` | exposed `Number(..)` | Team.elm | 2 |
| `Tournament.Name` | raw `String` | Tournament.elm | 3 |
| `Tournament.Year` | raw `Int` | Tournament.elm | 3 |
| `Tournament.Config` | transparent record | Tournament.elm | 3 |
| `Witness.{ name, description }` | single `String` | Witness.elm | 2 |
| `District.Name` | exposed `Name(..)` | District.elm | 3 |
| `School.Name` | exposed `Name(..)` | School.elm | 3 |
| `Courtroom.Name` | unguarded `name` | Courtroom.elm | 3 |

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
