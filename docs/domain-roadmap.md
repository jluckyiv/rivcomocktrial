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
| Coach.elm      | TeacherCoach, AttorneyCoach      |
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

**Tests:** 76 total.

---

## Layer 2: Competition Structure — IN PROGRESS

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

### Roster.elm — NOT STARTED

A roster assigns students to roles for a specific
round and team. The most complex module in this layer.

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
students.

### Summary

| Module         | Status      | Key Pattern              |
| -------------- | ----------- | ------------------------ |
| Tournament.elm | Done        | Status as sum type       |
| Round.elm      | Done        | Variants over Int        |
| Courtroom.elm  | Done        | Opaque wrapper           |
| Judge.elm      | Done        | Placeholder              |
| Assignment.elm | Done        | Domain language          |
| Pairing.elm    | Done        | Pre-resolved state       |
| Trial.elm      | Done        | Fully-resolved state     |
| Roster.elm     | Not started | Sum type per role        |

**Tests:** 103 total (76 Layer 1 + 27 Layer 2).

---

## Layer 3: Scoring

How individual presentations are evaluated. Scoring
is per **presentation**, not per role — an attorney
who does opening and closing gets two separate scores.

### SubmittedBallot → VerifiedBallot

**States are types, not fields.** A submitted ballot
and a verified ballot are different types because they
carry different data and participate in different
workflows.

```elm
-- What the scorer enters. Immutable after submission.
type alias SubmittedBallot =
    { scorer : ScorerInfo
    , presentations : List ScoredPresentation
    , ranks : Ranks
    , submittedAt : Time.Posix
    }

-- Admin-reviewed. Links to original for audit trail.
type alias VerifiedBallot =
    { original : SubmittedBallot
    , presentations : List ScoredPresentation
    , ranks : Ranks
    , verifiedBy : AdminId
    , verifiedAt : Time.Posix
    }
```

**Why two types instead of a status field:**
- `SubmittedBallot` is immutable — never overwritten.
  The raw data as entered is always preserved.
- `VerifiedBallot` may have corrections. It links to
  the original for audit trail.
- Functions that compute results accept only
  `VerifiedBallot`. It's a compile error to compute
  standings from unverified data.
- A round can't close until all ballots are verified —
  enforced by requiring `List VerifiedBallot`.

Motivated by real 2026 data issues: R1 Dept 2G score
entry errors ("10" captured as "1"), R2 Dept 52
duplicate submission.

```elm
type ScoredPresentation
    = Pretrial Side Student Points
    | Opening Side Student Points
    | DirectExamination Side Student Points
    | CrossExamination Side Student Points
    | Closing Side Student Points
    | WitnessExamination Side Student Points
    | ClerkPerformance Student Points
    | BailiffPerformance Student Points

type Weight = Single | Double
```

**Weighting:** Pretrial x2, Closing x2, all others x1.

### PresiderBallot

Separate type — not a scored ballot. The presiding
judge selects a side, used only on ties.

```elm
type alias PresiderBallot =
    { winner : Side }
```

### Rank

Scorers rank participants by category. Separate from
point scoring.

```elm
type RankCategory
    = AttorneyRanking      -- up to 5, minimum 3
    | NonAttorneyRanking   -- up to 5, minimum 3
```

**Playoff note:** Playoff ballots use attorney-only
ranks. This may mean rank categories vary by phase,
or playoffs use a different ballot type entirely.
The types will tell us when we implement.

### Summary

| Type              | Role                           |
| ----------------- | ------------------------------ |
| SubmittedBallot   | Immutable scorer input         |
| VerifiedBallot    | Admin-reviewed, audit-linked   |
| PresiderBallot    | Tiebreaker side selection      |
| ScoredPresentation | One score for one performance |
| Rank              | Participant ranking per ballot |

---

## Layer 4: Results (Computed)

Pure functions over Layer 3 data. No new persistent
state — everything here is derived from verified
ballots.

### PrelimResult

Prelim winner is determined by aggregate Court Totals
across all scorers. Different type from ElimResult
because the inputs, computation, and meaning are all
different.

```elm
type PrelimVerdict
    = ProsecutionWins   -- higher Court Total
    | DefenseWins       -- higher Court Total
    | CourtTotalTied    -- presider decides

prelimVerdict :
    List VerifiedBallot -> PrelimVerdict

prelimVerdictWithPresider :
    PresiderBallot
    -> List VerifiedBallot
    -> Side
```

Only accepts `VerifiedBallot` — compile-time guarantee
that unverified data can't produce results.

### ElimResult

Elim winner is determined by scorecard majority —
each scorer's ballot is independently a win, loss, or
tie. (Rule 5.5L)

```elm
type ElimVerdict
    = ProsecutionAdvances   -- majority of scorecards
    | DefenseAdvances       -- majority of scorecards
    | ScorecardsTied        -- presider decides

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

### Standings

Team rankings across rounds. Tiebreakers are modeled
as types, not hardcoded.

```elm
type Tiebreaker
    = CumulativePercentage
    | PointDifferential
    | HeadToHead
    -- extensible as rules change

type alias RankingStrategy =
    List Tiebreaker  -- priority order

type alias TeamRecord =
    { wins : Int
    , losses : Int
    , cumulativePointsFor : Int
    , cumulativePointsAgainst : Int
    }
```

**Ranking order** (current rules, 5.5E/5.5M):
1. Wins (most first)
2. Cumulative percentage

Strength of schedule is NOT a factor. (Rule 5.5M)

The `RankingStrategy` type makes tiebreaker priority
explicit and configurable. Adding a new tiebreaker
means adding a variant — the compiler forces you to
handle it everywhere.

```elm
cumulativePercentage : TeamRecord -> Float

rank :
    RankingStrategy
    -> List ( Team, TeamRecord )
    -> List ( Team, TeamRecord )
```

### Awards

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
    = ByRank          -- rank position across ballots
    | ByRawScore      -- raw point totals
    | ByMedianDelta   -- distance from ballot median
    -- extensible as criteria are finalized
```

Same pattern as team tiebreakers — criteria as types,
strategy as an ordered list. The compiler enforces
exhaustive handling.

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

| Type            | Accepts              | Computes           |
| --------------- | -------------------- | ------------------ |
| PrelimResult    | List VerifiedBallot  | Court Total winner |
| ElimResult      | List VerifiedBallot  | Scorecard majority |
| Standings       | List PrelimResult    | Team rankings      |
| Awards          | List VerifiedBallot  | Individual awards  |

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

### Done (103 tests)
1. District, School, Student, Coach, Email, Team,
   Side, Role — Layer 1 organizational types
2. Assignment — generic reusable type
3. Tournament — Status, Config
4. Round — variants, Phase derivation
5. Courtroom — opaque Name wrapper
6. Judge — placeholder
7. Pairing, Trial — state promotion via fromPairing

### Next
8. Roster — RoleAssignment, AttorneyDuty, validation
   (witness as list position, not number)
9. SubmittedBallot — ScoredPresentation, weight,
   totals, immutable scorer input
10. VerifiedBallot — promotion from Submitted,
    audit trail, corrections
11. PresiderBallot — tiebreaker side selection
12. Rank — validation, category types
13. PrelimResult — Court Total verdict from
    List VerifiedBallot
14. ElimResult — scorecard majority from
    List VerifiedBallot
15. Standings — TeamRecord, RankingStrategy,
    configurable tiebreakers as types
16. Awards — AwardCategory, AwardCriteria,
    tiebreakers as types (when criteria finalized)

### After domain types are stable
17. PocketBase collections — persistence mapping
18. Admin UI — pages for each workflow step
19. Coach UI — roster submission, score viewing
20. Public UI — standings, bracket, results
21. PowerMatch refactor — use domain types

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
| Milestone 3 (roster) | Layer 2 (Roster)           |
| Milestone 4 (ballot) | Layer 3 (all)              |
| Milestone 5 (awards) | Layer 4 (all)              |
| Milestone 6 (elim)   | ElimResult                 |
| Milestone 7 (public) | No new domain types        |
| Milestone 8 (polish) | No new domain types        |

Domain types are built before their corresponding
persistence and UI milestones. Types first, then
collections, then pages. The types teach us the
domain — once they're right, the rest is plumbing.
