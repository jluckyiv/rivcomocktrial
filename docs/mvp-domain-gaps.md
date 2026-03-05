# MVP Domain Gaps

Pre-persistence domain logic that must be complete
before PocketBase collections and UI make sense.

Identified after completing the domain audit (24
modules, 445 tests) and conflict tracking (issue #39).

---

## 1. RoundState Machine

**Status:** Needs user story discussion

**Problem:** No domain type models the round lifecycle.
Round.elm is a closed enum of round identifiers
(Preliminary1, Quarterfinal, etc.) — it says *which*
round, not *where the round is* in its workflow.

**What the admin needs to know:**
- "Are all pairings complete for this round?"
- "Are all volunteers assigned?"
- "Has the round started?"
- "Which ballots are still missing?"
- "Can I close this round?"
- "Are results ready to publish?"

**Rough states (needs user story refinement):**

```
PairingIncomplete
  → all Pairings promoted to Trials
ReadyToStaff
  → all Trials have volunteers assigned
ReadyToStart
  → admin starts the round
InProgress
  → ballots arriving from scorers
AwaitingVerification
  → all expected ballots submitted
Closed
  → all ballots verified, results computed
```

**Key questions for user story:**
- What does the admin actually *do* at each stage?
- Is "ReadyToStaff" a real state, or does volunteer
  assignment happen during pairing?
- When does the admin "start" a round — is it an
  explicit action, or implied when the first ballot
  arrives?
- Can a closed round be reopened? Under what
  circumstances?
- Does closing automatically compute results, or is
  that a separate admin action?
- Is "publish results" part of round closure or a
  separate workflow step?

**Connections:**
- Drives BallotCollection (gap #2) — the round must
  know how many ballots to expect
- Drives Volunteer assignment (gap #5) — assignment
  happens during round setup
- Blocks issue #40 (round/pairing closure workflow)
- Blocks issue #38 (realtime dashboard — shows round
  progress)

---

## 2. BallotCollection

**Status:** Needs design, connected to RoundState

**Problem:** No domain type tracks which ballots are
in and which are missing per trial. Can't determine
if a round is ready to close.

**Insight:** When the round starts, the RoundState
should have all scorer identities (from volunteer
assignment). So we know exactly which ballots to
expect — it's not "at least N ballots" but "these
specific scorers must submit."

**What the admin needs to know:**
- "Which scorers have submitted for this trial?"
- "Which scorers are still missing?"
- "Are all submitted ballots verified?"
- "Is this trial complete?"

**Design direction:**

```elm
type BallotCollection = BallotCollection
    { trial : Trial
    , expectedScorers : List Volunteer
    , submitted : List ( Volunteer, SubmittedBallot )
    , verified : List ( Volunteer, VerifiedBallot )
    }

-- Pure queries
missingScorers : BallotCollection -> List Volunteer
isFullySubmitted : BallotCollection -> Bool
isFullyVerified : BallotCollection -> Bool
```

**Key insight:** The scorer-to-ballot link comes from
volunteer assignment. Without knowing *who* is scoring
*which* trial, we can only count ballots, not track
specific missing ones. This is why RoundState (gap #1)
and Volunteer assignment (gap #5) must be designed
together.

**Connections:**
- Depends on RoundState (gap #1) — round must know
  its expected scorers
- Depends on Volunteer assignment (gap #5) — scorers
  are assigned to trials
- Required by PrelimResult/ElimResult — can't compute
  results without all verified ballots
- Required by issue #35 (admin ballot review)

---

## 3. Standings Aggregation

**Status:** Straightforward to implement

**Problem:** `TeamRecord` type exists (wins, losses,
pointsFor, pointsAgainst) and `rank` function works,
but no function builds `TeamRecord` from actual trial
results + verified ballots.

**What's needed:**

```elm
-- From a single trial's verified ballots, who won?
type TrialResult
    = ProsecutionWon
        { prosecution : Team
        , defense : Team
        , prosPoints : Int
        , defPoints : Int
        }
    | DefenseWon { ... }
    | Tied { ... }  -- presider decides

-- Build cumulative standings from all completed trials
aggregate :
    List TrialResult
    -> List ( Team, TeamRecord )

-- Incremental: update standings after one round
updateStandings :
    List ( Team, TeamRecord )
    -> List TrialResult
    -> List ( Team, TeamRecord )
```

**Also needed:** Head-to-head lookup for tiebreaker
(currently returns EQ as placeholder).

```elm
headToHead :
    Team
    -> Team
    -> List TrialResult
    -> { wins : Int, losses : Int }
```

**Connections:**
- Required by PowerMatch for R2–R4 seeding
- Required by elimination bracket seeding (top 8)
- Required by public standings display
- Depends on PrelimResult.courtTotal (already done)

---

## 4. Elimination Side Rules

**Status:** Straightforward, rules are clear (5.5K)

**Problem:** PowerMatch handles prelim side constraints
(R1 random, R2 flip, R3 higher-ranked flips, R4 flip).
No module handles elimination side rules, which depend
on meeting history.

**Rules (5.5K):**
- First meeting: higher-ranked team flips from their
  most recent round
- Rematch: reverse sides from that prior meeting
- Third meeting: coin flip

**What's needed:**

```elm
type MeetingHistory
    = FirstMeeting
    | Rematch { priorSide : Side }
    | ThirdMeeting

meetingHistory :
    Team -> Team -> List Trial -> MeetingHistory

elimSideAssignment :
    MeetingHistory
    -> Team  -- higher seed
    -> Team  -- lower seed
    -> Side  -- higher seed's most recent side
    -> ( Team, Team )  -- ( prosecution, defense )
```

**Connections:**
- Required by elimination bracket (Milestone 6)
- Depends on trial/pairing history across all rounds
- Could live in PowerMatch or a new ElimPairing module

---

## 5. Volunteer Assignment

**Status:** Needs discussion with RoundState

**Problem:** Volunteer and Conflict types exist (issue
#39), but no type represents "this volunteer is
assigned to this trial for this round." Without it,
we can't:
- Track who's scoring which trial
- Check conflicts at assignment time
- Know which ballots to expect (gap #2)

**What's needed:**

```elm
type VolunteerAssignment = VolunteerAssignment
    { volunteer : Volunteer
    , trial : Trial
    , round : Round
    }

-- Check conflicts before assigning
validateAssignment :
    Volunteer
    -> Trial
    -> List HardConflict
    -> List ( Round, Team, Team )  -- history
    -> Result (List Conflict) VolunteerAssignment

-- All assignments for a round
type RoundStaffing = RoundStaffing
    { round : Round
    , assignments : List VolunteerAssignment
    , unassignedTrials : List Trial
    }
```

**User story questions (same as RoundState):**
- Does the admin assign volunteers to courtrooms
  (which persist across rounds) or to specific trials
  (which change each round)?
- Do volunteers self-assign (scan QR → pick courtroom)
  or does admin assign them?
- Is there a minimum scorer count per trial? Is it
  configurable?
- Can a volunteer be reassigned mid-round if someone
  doesn't show up?

**Connections:**
- Feeds into RoundState (gap #1) — "all trials
  staffed" is a state transition
- Feeds into BallotCollection (gap #2) — expected
  scorers come from assignments
- Uses Conflict module (issue #39) for validation
- Required by issue #38 (realtime dashboard — shows
  who's where)

---

## 6. Round ↔ PocketBase Mapping

**Status:** Deferred to persistence phase

**Problem:** PocketBase rounds table has `number` (Int)
and `type` ("preliminary" | "elimination"), but no
strong link to domain `Round` enum variants.

**What's needed:**

```elm
roundFromPersistence :
    Int -> String -> Result Error Round
roundToPersistence :
    Round -> { number : Int, roundType : String }
```

**Not urgent:** This is glue code that belongs with
the persistence layer, not pure domain logic.

---

## Implementation Order

Gaps #1, #2, and #5 are deeply connected — the round
lifecycle, ballot tracking, and volunteer assignment
form a single user story about "running a round."
Design these together.

1. **RoundState + Volunteer Assignment + Ballot
   Collection** — design as one user story, implement
   as separate modules
2. **Standings Aggregation** — independent, needed for
   power matching
3. **Elimination Side Rules** — independent, needed
   for R5+
4. **PocketBase Mapping** — deferred to persistence

---

## Related Issues

- #38 — Realtime admin dashboard (blocked by #1, #5)
- #39 — Conflict tracking (done, PR #48)
- #40 — Round/pairing closure workflow (blocked by #1)
- #33 — Offline-resilient ballot scoring (blocked by
  #2)
- #34 — Ballot scoring UI (blocked by #2)
- #35 — Admin ballot review (blocked by #2)
