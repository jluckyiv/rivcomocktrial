# Domain Roadmap

We are discovering the domain through our types.

This document is the active domain modeling plan. It
reflects what we've built, what we've learned, and
where we're headed. It evolves as we implement.

## Design Principles

Informed by Wlaschin's *Domain Modeling Made
Functional*, Ploeh's algebraic domain modeling, and
the *Designing with Types* series:

1. **Make illegal states unrepresentable.** Use sum
   types so invalid combinations can't compile.
   (Ploeh: "easy domain modelling with types")
2. **States are types, not fields.** A `SubmittedBallot`
   and a `VerifiedBallot` are different types with
   different data, not the same record with a status
   flag. Functions accept only the states they need.
   (Wlaschin: "state machines with types")
3. **Use types as documentation.** The type signature
   tells you what a function does. If a function only
   accepts `VerifiedBallot`, you know unverified data
   can't sneak in. (Wlaschin: "types are not just
   for type checking")
4. **Discover the domain through types.** When a type
   feels wrong, it's the domain telling you something.
   Refactor the types, and the code follows.
   (Wlaschin: "discovering new concepts")
5. **Wrap primitives with domain meaning.** `School.Name`
   is not a `String` — it's a type the compiler
   enforces. Single-case unions for identifiers.
   (Wlaschin: "single-case union types")
6. **Constrained types via smart constructors.** When a
   value has a restricted range, expose a constructor
   that validates and returns `Maybe`. The type
   guarantees validity; callers can't bypass it.
7. **Separate what changes from what doesn't.** A
   `Pairing` changes (assignments get filled). A
   `Trial` doesn't (everything is resolved). Different
   types for different lifecycles.

See also:
- [ADR-006](decisions.md) — flat module-per-concept
- [competition-workflow.md](competition-workflow.md)
  — end-to-end competition sequence
- [power-matching-analysis.md](power-matching-analysis.md)
  — cross-bracket rule analysis

---

## Dependency Graph

```
Layer 4 (Results):     PrelimResult  ElimResult
                       Standings  Awards
                           │          │
Layer 3 (Scoring):     SubmittedBallot → VerifiedBallot
                       PresiderBallot   Rank
                           │              │
Layer 2 (Competition): Tournament  Round  Courtroom
                       Pairing → Trial   Judge
                       Roster
                           │
Layer 1 (Organizational):
  District  School  Student  Coach  Email
  Team  Side  Role

Generic: Assignment  (Layer 1, reusable)
```

Arrows (→) show state promotions: a type that becomes
a different type when conditions are met. These are
type-level guarantees, not runtime checks.

Each layer depends only on layers below it.

---

## Layer 1: Organizational — DONE

The people, places, and groups that exist before any
competition begins.

| Module         | Key Types                       |
| -------------- | ------------------------------- |
| District.elm   | District, District.Name         |
| School.elm     | School, School.Name             |
| Student.elm    | Student, Student.Name, Pronouns |
| Coach.elm      | TeacherCoachApplicant, TeacherCoach, AttorneyCoach |
| Email.elm      | Email                           |
| Team.elm       | Team, Team.Number               |
| Side.elm       | Side (Prosecution \| Defense)   |
| Role.elm       | Role (side in variants)         |
| Assignment.elm | Assignment a (generic)          |

**Key decisions:**
- Module namespacing for type safety — `School.Name`
  and `Student.Name` are distinct compiler-enforced
  types
- Side belongs on pairings/trials, not teams — teams
  switch sides each round
- Role encodes side in its variants — Clerk and
  Bailiff have no side, making impossible states
  unrepresentable
- `Assignment a` (`NotAssigned | Assigned a`) replaces
  `Maybe` with domain language
- Coach state promotion: `TeacherCoachApplicant` →
  `TeacherCoach` via `verify`. Same fields, different
  types — compiler prevents unverified coaches on
  teams. `AttorneyCoach` has no verification step.

**Tests:** 76 total (Layer 1 original) + 2 Coach.

---

## Layer 2: Competition Structure — DONE

The tournament, its rounds, and what happens in each
trial. Organizational entities meet competition rules.

### Tournament.elm — DONE

```elm
type Status = Draft | Registration | Active | Completed

type alias Config =
    { numPreliminaryRounds : Int
    , numEliminationRounds : Int
    }
```

### Round.elm — DONE

Rounds are explicit variants, not wrapped integers.
Phase is derived — no impossible states.

```elm
type Round
    = Preliminary1 | Preliminary2
    | Preliminary3 | Preliminary4
    | Quarterfinal | Semifinal | Final

type Phase = Preliminary | Elimination
```

The competition has a fixed structure (4 prelims +
3 elims). Variants make phase derivation a pattern
match and eliminate out-of-range values. If round
count becomes configurable, we revisit.

### Courtroom.elm — DONE

Opaque `Name` wrapper — a named location.

### Judge.elm — DONE (placeholder)

```elm
type Judge = Judge
```

We know a judge exists on a trial. We don't yet know
the shape — a presider with a name and tiebreaker
authority, or something else. The placeholder is
honest about what we know. We'll discover the type
when we model judicial assignments.

### Pairing.elm → Trial.elm — DONE

**State promotion:** Pairing is the pre-trial state
where pieces are being assembled. Trial is the
fully-resolved state, ready for competition.

```elm
-- Pairing: slots being filled
type alias Pairing =
    { prosecution : Team
    , defense : Team
    , courtroom : Assignment Courtroom
    , judge : Assignment Judge
    }

-- Trial: everything resolved
type alias Trial =
    { prosecution : Team
    , defense : Team
    , courtroom : Courtroom
    , judge : Judge
    }

-- Promotion: type-level guarantee
fromPairing : Pairing -> Maybe Trial
```

`fromPairing` succeeds only when all assignments are
filled. This is the domain saying "we're ready." A
round can't start until every Pairing promotes to a
Trial.

### Witness.elm — DONE

Opaque type wrapping a string — the character name
(e.g., "Jordan Riley"). Tournament-level data: admin
defines 4 prosecution + 4 defense witnesses when
creating the tournament.

```elm
type Witness = Witness String

fromString : String -> Witness
toString : Witness -> String
```

`toString` is a function, not a field accessor — the
internal representation is hidden. `WitnessNumber` is
not a domain concept — list position = number.

### Roster.elm — DONE

A roster assigns students to roles for a specific
round and team.

```elm
type RoleAssignment
    = PretorialAttorney Student
    | TrialAttorney Student AttorneyDuty
    | WitnessRole Student Witness
    | ClerkRole Student
    | BailiffRole Student

type AttorneyDuty
    = Opening
    | DirectOf Witness
    | CrossOf Witness
    | Closing
```

**Key insight:** `WitnessNumber` is not a domain
concept — it's a human-readable label. A roster has
a `List Witness`; position in the list is the witness
number. "Witness 1" is derived for display, not
stored. `DirectOf Witness` and `CrossOf Witness`
reference the witness directly, not by number.

**Domain rules:**
- Rosters are per-round, per-team.
- Due X days before round (configurable).
- Editable until Y minutes before (configurable,
  typically ~1 hour).
- Students must be on the team's eligible list.

**Validation:** correct count per role, no duplicate
students. Deferred — depends on exact count rules.

### Summary

| Module         | Status | Key Pattern              |
| -------------- | ------ | ------------------------ |
| Tournament.elm | Done   | Status as sum type       |
| Round.elm      | Done   | Variants over Int        |
| Courtroom.elm  | Done   | Opaque wrapper           |
| Judge.elm      | Done   | Placeholder              |
| Assignment.elm | Done   | Domain language          |
| Pairing.elm    | Done   | Pre-resolved state       |
| Trial.elm      | Done   | Fully-resolved state     |
| Witness.elm    | Done   | Opaque wrapper           |
| Roster.elm     | Done   | Sum type per role        |

**Tests:** 113 total (78 Layer 1 + 35 Layer 2).

---

## Layer 3: Scoring — DONE

How individual presentations are evaluated. Scoring
is per **presentation**, not per role — an attorney
who does opening and closing gets two separate scores.

### SubmittedBallot.elm — DONE

Immutable scorer input. Contains scored presentations.
Metadata (scorer, submittedAt) deferred until auth/
time APIs are available.

```elm
type alias SubmittedBallot =
    { presentations : List ScoredPresentation }

type ScoredPresentation
    = Pretrial Side Student Points
    | Opening Side Student Points
    | DirectExamination Side Student Points
    | CrossExamination Side Student Points
    | Closing Side Student Points
    | WitnessExamination Side Student Points
    | ClerkPerformance Student Points
    | BailiffPerformance Student Points
```

**Points:** Opaque type, 1–10 via smart constructor.
**Weight:** Pretrial x2, Closing x2, all others x1.
Derived from variant, not stored.
**Side:** Clerk→Prosecution, Bailiff→Defense. Derived
via `side` function — a scoring rule, not a property.

### VerifiedBallot.elm — DONE

Admin-reviewed. Links to original for audit trail.

```elm
type alias VerifiedBallot =
    { original : SubmittedBallot
    , presentations : List ScoredPresentation
    }

verify : SubmittedBallot -> VerifiedBallot
verifyWithCorrections :
    SubmittedBallot
    -> List ScoredPresentation
    -> VerifiedBallot
```

**Why two types instead of a status field:**
- `SubmittedBallot` is immutable — never overwritten.
- `VerifiedBallot` may have corrections. Original
  preserved for audit trail.
- Functions that compute results accept only
  `VerifiedBallot`. Compile error to use unverified.
- A round can't close until all ballots are verified.

Motivated by real 2026 data issues: R1 Dept 2G score
entry error ("10" → "1"), R2 Dept 52 duplicate.

### PresiderBallot.elm — DONE

Separate type — not a scored ballot. The presiding
judge selects a side, used only on ties.

```elm
type alias PresiderBallot =
    { winner : Side }

for : Side -> PresiderBallot
winner : PresiderBallot -> Side
```

### Rank.elm — DONE

Scorers rank participants by nomination category.
Separate from point scoring — drives individual
awards.

```elm
type Rank = Rank Int  -- 1–5, smart constructor

type NominationCategory
    = Advocate       -- attorneys + pretrial
    | NonAdvocate    -- witnesses + clerk + bailiff

type alias Nomination =
    { role : Role
    , student : Student
    , rank : Rank
    }

nominationCategory : Role -> NominationCategory
rankPoints : Int -> Rank -> Int
-- (count + 1) - rank: 1st of 5 = 5 pts
```

**Discovery from 2026 ballot:** Two nomination pools
(Advocate, NonAdvocate) derived from Role. Min/max
nomination count parameterized (currently 3–5, likely
to change). Our app uses dropdowns of eligible
performers, not free-text names.

**Playoff note:** Playoff ballots use attorney-only
ranks. This may mean rank categories vary by phase,
or playoffs use a different ballot type entirely.

### Summary

| Module             | Status | Key Pattern              |
| ------------------ | ------ | ------------------------ |
| SubmittedBallot.elm | Done  | Immutable scorer input   |
| VerifiedBallot.elm | Done   | State promotion + audit  |
| PresiderBallot.elm | Done   | Tiebreaker side select   |
| Rank.elm           | Done   | Smart constructor + nomination |

**Tests:** 51 total Layer 3.

---

## Layer 4: Results (Computed) — DONE

Pure functions over Layer 3 data. No new persistent
state — everything here is derived from verified
ballots.

### PrelimResult.elm — DONE

Prelim winner is determined by aggregate Court Totals
across all scorers. Different type from ElimResult
because the inputs, computation, and meaning are all
different.

```elm
type PrelimVerdict
    = ProsecutionWins   -- higher Court Total
    | DefenseWins       -- higher Court Total
    | CourtTotalTied    -- presider decides

courtTotal : Side -> VerifiedBallot -> Int
prelimVerdict :
    List VerifiedBallot -> PrelimVerdict
prelimVerdictWithPresider :
    PresiderBallot
    -> List VerifiedBallot
    -> Side
```

Only accepts `VerifiedBallot` — compile-time guarantee
that unverified data can't produce results.
`courtTotal` exposed as building block for Standings.

### ElimResult.elm — DONE

Elim winner is determined by scorecard majority —
each scorer's ballot is independently a win, loss, or
tie. (Rule 5.5L)

```elm
type ScorecardResult
    = ProsecutionWon | DefenseWon | ScorecardTied

type ElimVerdict
    = ProsecutionAdvances
    | DefenseAdvances
    | ScorecardsTied

scorecardResult : VerifiedBallot -> ScorecardResult
elimVerdict :
    List VerifiedBallot -> ElimVerdict
elimVerdictWithPresider :
    PresiderBallot
    -> List VerifiedBallot
    -> Side
```

**Why two result types, not one sum type:** The
functions have different signatures and semantics.
`prelimVerdict` sums points across all ballots.
`elimVerdict` counts each ballot as a unit vote.
Collapsing them into one type would require a phase
parameter that the type system can enforce instead.

`scorecardResult` reuses `PrelimResult.courtTotal` —
same per-ballot logic, different aggregation.

### Standings.elm — DONE

Team rankings across rounds. Tiebreakers are modeled
as types, not hardcoded.

```elm
type Tiebreaker
    = ByWins
    | ByCumulativePercentage
    | ByPointDifferential
    | ByHeadToHead
    -- extensible as rules change

type alias RankingStrategy =
    List Tiebreaker  -- priority order

type alias TeamRecord =
    { wins : Int
    , losses : Int
    , pointsFor : Int
    , pointsAgainst : Int
    }

cumulativePercentage : TeamRecord -> Float
rank :
    RankingStrategy
    -> List ( team, TeamRecord )
    -> List ( team, TeamRecord )
```

**Ranking order** (current rules, 5.5E/5.5M):
1. Wins (most first)
2. Cumulative percentage

Strength of schedule is NOT a factor. (Rule 5.5M)

`rank` is generic over team type. `ByHeadToHead` is
a placeholder (returns EQ) — needs pairing history.

### Awards.elm — DONE (types; scoring algorithm deferred)

Individual awards from preliminary rounds only
(R1–R4). Presented countywide after R4.

```elm
type AwardCategory
    = BestAttorney Side
    | BestWitness Witness
    | BestClerk
    | BestBailiff
    -- 14 total; witness categories carry character

type alias AwardCriteria =
    List AwardTiebreaker

type AwardTiebreaker
    = ByRankPoints     -- rank points across ballots
    | ByRawScore       -- raw point totals
    | ByMedianDelta    -- distance from ballot median
    -- extensible as criteria are finalized

nominationCategory :
    AwardCategory -> NominationCategory
```

Same pattern as team tiebreakers — criteria as types,
strategy as an ordered list. The compiler enforces
exhaustive handling. `nominationCategory` links award
categories to the Advocate/NonAdvocate nomination
pools from Rank.

**Status:** Criteria in flux. What we know:
- Based on ballot ranks (min/max configurable,
  currently 3–5 per category)
- Rank points = (count + 1) - rank position
- May use AMTA-style criteria
- Playoff "top advocate" happened in 2026 finals but
  is undocumented in the handbook

**Known problem: relative vs absolute quality.**
In 2026, some students received high ranks despite
low point scores (5–6/10) because their opponents
were worse. Rank-only awards reward "best of the
meh." The award algorithm must account for absolute
performance, not just relative ranking within a
trial. Possible approaches:
- **Score threshold** — nominations only count if
  point score meets a minimum. Simple but arbitrary.
- **Ballot median delta** — compare student's score
  to the median on that ballot. Captures "actually
  good" vs "less bad." Already listed as a tiebreaker.
- **Weighted composite** — combine rank points with
  normalized scores (e.g., z-score across category).
- **AMTA-style tiering** — rank points primary, raw
  scores and median delta as tiebreakers.

The raw data needed (point scores + rank nominations)
is already captured in Layer 3 (SubmittedBallot +
Rank). The combination logic belongs here in Layer 4.

### Summary

| Module           | Status | Key Pattern              |
| ---------------- | ------ | ------------------------ |
| PrelimResult.elm | Done   | Court Total aggregate    |
| ElimResult.elm   | Done   | Scorecard majority       |
| Standings.elm    | Done   | Configurable tiebreakers |
| Awards.elm       | Done   | Types; algorithm deferred |

**Tests:** 35 total Layer 4.

---

## Crosscutting: Side Assignment

Side assignment rules span the entire tournament.
Elimination rules (5.5K) require full pairing history.

| Round | Rule |
|-------|------|
| R1 | Random drawing |
| R2 | Flip from R1 (5.5B) |
| R3 | Higher-ranked flips from previous (5.5C) |
| R4 | Flip from R3 (5.5D) |
| R5+ first meeting | Higher-ranked flips from previous (5.5K) |
| R5+ rematch | Reverse from that meeting (5.5K) |
| R5+ third meeting | Coin flip (5.5K) |

The PowerMatch module handles prelim side constraints.
Elimination side logic is new — requires pairing
history lookup across all rounds.

---

## Crosscutting: Pairing Rules

Power matching rules also have configurable elements
that should be modeled as types:

```elm
type CrossBracketStrategy
    = HighHigh  -- best upper vs best lower
    | HighLow   -- best upper vs worst lower

type SideConstraint
    = FlipFromPrevious     -- R2 from R1, R4 from R3
    | HigherRankedFlips    -- R3, playoffs first meeting
    | ReverseFromMeeting   -- playoff rematch
    | CoinFlip             -- playoff third meeting
```

Already partially implemented in PowerMatch module.

---

## Implementation Sequence

TDD: write failing tests, implement types and
functions, refactor. No persistence, no UI — pure
domain logic.

### Done (199 tests)
1. District, School, Student, Coach, Email, Team,
   Side, Role — Layer 1 organizational types
2. Assignment — generic reusable type
3. Tournament — Status, Config
4. Round — variants, Phase derivation
5. Courtroom — opaque Name wrapper
6. Judge — placeholder
7. Pairing, Trial — state promotion via fromPairing
8. Coach state promotion — TeacherCoachApplicant →
   TeacherCoach via verify
9. Witness — opaque type, tournament-level data
10. Roster — RoleAssignment, AttorneyDuty, student
    accessor
11. SubmittedBallot — ScoredPresentation, Points
    smart constructor, weight, side derivation
12. VerifiedBallot — promotion from Submitted,
    audit trail, corrections
13. PresiderBallot — tiebreaker side selection
14. Rank — smart constructor, NominationCategory,
    rankPoints, Nomination
15. PrelimResult — courtTotal, prelimVerdict,
    prelimVerdictWithPresider
16. ElimResult — scorecardResult, elimVerdict,
    elimVerdictWithPresider
17. Standings — TeamRecord, cumulativePercentage,
    configurable RankingStrategy
18. Awards — AwardCategory, AwardTiebreaker,
    nominationCategory linkage

### Deferred implementation
- Awards scoring algorithm — criteria in flux
- Standings ByHeadToHead — needs pairing history
- Roster validation — needs exact count rules
- Ballot metadata (scorer, timestamps) — needs auth

### Next (domain types stable)
19. PocketBase collections — persistence mapping
20. Admin UI — pages for each workflow step
21. Coach UI — roster submission, score viewing
22. Public UI — standings, bracket, results
23. PowerMatch refactor — use domain types

---

## What This Plan Does NOT Cover

Intentionally deferred:

- **PocketBase collections** — after domain types
  stabilize
- **UI / pages** — after persistence
- **PowerMatch refactor** — works as-is; refactor to
  domain types is a separate task
- **Elimination bracket seeding** — rules documented
  (1v8, 2v7 etc. per Rule 5.5H), implementation
  deferred
- **Scorer recruitment/assignment** — outside the app
- **Coach auth / OAuth** — later milestone
- **Notification/publishing** — later milestone

---

## Relationship to Original Roadmap

| Original Milestone   | Domain Layers              |
| -------------------- | -------------------------- |
| Milestone 1 (done)   | Layer 1 (done)             |
| Milestone 2 (done)   | PowerMatch (done)          |
| Milestone 3 (roster) | Layer 2 (done)             |
| Milestone 4 (ballot) | Layer 3 (done)             |
| Milestone 5 (awards) | Layer 4 (done — types)     |
| Milestone 6 (elim)   | ElimResult (done)          |
| Milestone 7 (public) | No new domain types        |
| Milestone 8 (polish) | No new domain types        |

All domain types are complete. Next phase: persistence
(PocketBase collections), then UI (admin pages, coach
pages, public pages). The types teach us the domain —
now that they're right, the rest is plumbing.
