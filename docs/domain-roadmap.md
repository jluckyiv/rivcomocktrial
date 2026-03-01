# Domain Roadmap

Domain-first development plan for the Elm frontend,
organized by concept layers. Each layer depends only on
layers below it — no cycles.

The original [roadmap.md](roadmap.md) (organized around
PocketBase collections and UI milestones) remains for
reference. This document is the active implementation
plan for domain modeling.

See also: [ADR-006](decisions.md#adr-006-flat-module-per-concept-for-domain-types)
for the flat-module convention.

---

## Dependency Graph

```
Layer 4 (Results):    TrialResult  Standings  BlueRibbon
                          │            │          │
Layer 3 (Scoring):      Score       Ballot      Rank
                          │            │          │
Layer 2 (Competition):  Tournament  Round  Courtroom
                          │            │
                        Trial       Roster
                          │            │
Layer 1 (Organizational): District  School  Student
                          Coach  Email  Team  Side  Role
```

Each layer depends only on layers below it.

---

## Layer 1: Organizational — DONE

The people, places, and groups that exist before any
competition begins.

| Module       | Key Types                         | Status |
| ------------ | --------------------------------- | ------ |
| District.elm | District, District.Name           | Done   |
| School.elm   | School, School.Name               | Done   |
| Student.elm  | Student, Student.Name, Pronouns   | Done   |
| Coach.elm    | TeacherCoach, AttorneyCoach        | Done   |
| Email.elm    | Email                             | Done   |
| Team.elm     | Team, Team.Number                 | Done   |
| Side.elm     | Side (Prosecution \| Defense)     | Done   |
| Role.elm     | Role (side encoded in variants)   | Done   |

**Key decisions:**
- Module namespacing for type safety — `School.Name`
  and `Student.Name` are distinct types the compiler
  enforces
- Side belongs on pairings/trials, not on teams — teams
  switch sides each round
- Role encodes side in its variants (ProsecutionAttorney,
  DefenseWitness, etc.) — Clerk and Bailiff have no
  side, making impossible states unrepresentable
- Wrap primitives (Int, String) in custom types when the
  value is an identifier, not data you compute with

**Tests:** 68 total. Test derived values and functions,
not type construction — Elm's type system already
prevents invalid construction.

---

## Layer 2: Competition Structure

The tournament, its rounds, and what happens in each
trial. This is where organizational entities meet
competition rules.

### Tournament.elm

A tournament is the top-level container for a
competition season.

```elm
type Status
    = Draft
    | Registration
    | Active
    | Completed

type alias Config =
    { numPreliminaryRounds : Int
    , numEliminationRounds : Int
    }

type Phase
    = Preliminary
    | Elimination
```

**Key insight:** Phase is derived from round number +
config, not stored. A round doesn't know whether it's
preliminary or elimination — the tournament determines
that from the round's position.

**Functions:** `phase : Config -> Round.Number -> Phase`

### Round.elm

A round is a set of concurrent trials within a
tournament.

```elm
-- Round.Number wraps Int
type Number = Number Int

type PublishStatus
    = Unpublished
    | Published
```

**Key insight:** Round does NOT store its own type or
phase. Whether a round is preliminary or elimination
comes from its position in the tournament (see
Tournament.phase). This avoids the impossible state of
a round claiming to be "preliminary" when its number
says otherwise.

**Functions:** `isPreliminary : Config -> Number -> Bool`

### Courtroom.elm

Minimal module — a named location where trials happen.

```elm
-- Courtroom.Name wraps String
type Name = Name String
```

### Trial.elm

A trial is one matchup within a round: prosecution team
vs. defense team in a courtroom.

```elm
type alias Matchup =
    { prosecution : Team
    , defense : Team
    }
```

**Key insight:** Courtroom is `Maybe Courtroom` —
assigned after pairing, not during. Trial does not
reference its round directly — context provides that
(a round contains a list of trials).

### Roster.elm

The most complex module in this layer. A roster assigns
students to roles for a specific trial.

```elm
type RoleAssignment
    = PretorialAttorney Student
    | TrialAttorney Student AttorneyDuty
    | WitnessRole Student Witness
    | ClerkRole Student
    | BailiffRole Student

type AttorneyDuty
    = Opening
    | DirectOf WitnessNumber
    | CrossOf WitnessNumber
    | Closing

-- WitnessNumber wraps Int (1-4)
type WitnessNumber = WitnessNumber Int
```

**Key insight:** RoleAssignment is a sum type where each
variant carries exactly the data needed for that role.
An attorney has a duty; a witness has a character; clerk
and bailiff carry nothing extra. This eliminates
nullable fields and "this field only applies when role
is X" conditionals.

**Functions:** validation (correct count per role,
witness numbers in range, no duplicate students)

---

## Layer 3: Scoring

How individual presentations are evaluated. The key
domain insight: scoring is per **presentation**, not per
role. An attorney who does opening and closing gets two
separate scores on the ballot.

### Score.elm

A single numeric score for one presentation.

```elm
-- Points wraps Int
type Points = Points Int
```

**Functions:** `isValid : Role -> Points -> Bool`,
`maxPoints : Role -> Int` (1–10 for most roles, 1–5
for clerk/bailiff)

### Ballot.elm

A scorer's complete evaluation of one trial. Contains
scored presentations, not role assignments — the
distinction matters because one person can give
multiple performances.

```elm
type ScoredPresentation
    = Pretrial Student Points
    | Opening Student Points
    | DirectExamination Student Points
    | CrossExamination Student Points
    | Closing Student Points
    | WitnessExamination Student Points
    | ClerkPerformance Student Points
    | BailiffPerformance Student Points

type Weight
    = Single  -- ×1
    | Double  -- ×2
```

**Weighting rules:**
- Pretrial: ×2
- Closing: ×2
- All others: ×1

**Functions:** `weight : ScoredPresentation -> Weight`,
`weightedPoints : ScoredPresentation -> Int`,
`prosecutionTotal : Ballot -> Int`,
`defenseTotal : Ballot -> Int`,
`winner : Ballot -> Maybe Side`

### Rank.elm

Separate from scoring. Scorers rank participants by
category.

```elm
type RankCategory
    = AttorneyRanking   -- up to 5, minimum 3
    | NonAttorneyRanking -- up to 5, minimum 3
```

**Functions:** validation (minimum 3, maximum 5 per
category)

---

## Layer 4: Results (Computed)

Pure functions over Layer 3 data. No new persistent
state — everything here is derived.

### TrialResult.elm

The outcome of a single trial, determined by majority
of ballots.

```elm
type Verdict
    = ProsecutionVerdict
    | DefenseVerdict
    | Tie
```

**Key rule:** Majority of ballots determines the winner
(not total points). The presiding judge votes only on
ties — their ballot is a tiebreaker, not a regular
score.

**Functions:** `verdict : List Ballot -> Verdict`,
`verdictWithPresider : Ballot -> List Ballot -> Side`

### Standings.elm

Team rankings across rounds.

```elm
type alias TeamRecord =
    { wins : Int
    , losses : Int
    , pointsFor : Int
    , pointsAgainst : Int
    }
```

**Ranking order:**
1. Wins (most first)
2. Cumulative percentage tiebreaker (pointsFor /
   (pointsFor + pointsAgainst))

**Functions:** `record : Team -> List TrialResult -> TeamRecord`,
`compare : TeamRecord -> TeamRecord -> Order`,
`rank : List (Team, TeamRecord) -> List (Team, TeamRecord)`

### BlueRibbon.elm

Individual awards from preliminary rounds only
(rounds 1–4).

14 award categories. Witness categories carry character
names (e.g., "Best Witness — Alex Parker"). Exact
AMTA-style criteria TBD — will be refined when we
implement scoring.

**Functions:** category definitions, filtering to
preliminary rounds, ranking within categories

---

## Implementation Sequence

One module + tests at a time, TDD (red/green/refactor):

1. Tournament.elm — Status, Config, phase derivation
2. Round.elm — Number, PublishStatus, isPreliminary
3. Courtroom.elm — Name (minimal)
4. Trial.elm — Matchup, accessors
5. Roster.elm — RoleAssignment, AttorneyDuty, validation
6. Score.elm — Points, isValid, maxPoints
7. Ballot.elm — ScoredPresentation, weight, totals
8. Rank.elm — validation
9. TrialResult.elm — verdict, presider tiebreaker
10. Standings.elm — record, compare, rank
11. BlueRibbon.elm — categories

Each step: write failing tests, implement the types and
functions, refactor. No persistence, no UI — pure domain
logic.

---

## What This Plan Does NOT Cover

These are intentionally deferred:

- **PocketBase collections** — persistence mapping comes
  after the domain types are stable
- **UI / pages** — admin and public pages come after
  persistence
- **PowerMatch refactor** — the existing PowerMatch
  module works; refactoring it to use domain types is a
  separate task
- **Elimination bracket seeding** — rules not yet
  finalized
- **MVP nominations** — not in current competition rules
- **Courtroom artist / journalist awards** — not in
  current competition rules
- **Coach auth / OAuth** — deferred to a later milestone

---

## Relationship to Original Roadmap

| Original Milestone   | Domain Layers         |
| -------------------- | --------------------- |
| Milestone 1 (done)   | Layer 1 (done)        |
| Milestone 2 (done)   | PowerMatch (done)     |
| Milestone 3 (roster) | Layer 2 (Roster)      |
| Milestone 4 (ballot) | Layer 3 (all)         |
| Milestone 5 (awards) | Layer 4 (all)         |
| Milestone 6 (elim)   | Tournament.Phase      |
| Milestone 7 (public) | No new domain types   |
| Milestone 8 (polish) | No new domain types   |

The domain types in Layers 2–4 will be built before
their corresponding persistence and UI milestones. Types
first, then collections, then pages.
