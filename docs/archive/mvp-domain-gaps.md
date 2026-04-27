# MVP Domain Gaps

Pre-persistence domain logic that must be complete
before PocketBase collections and UI make sense.

Identified after completing the domain audit (26
modules, 445 tests) and conflict tracking (issue #39).
Refined through user story discussion (issue #49).

---

## 1. TrialState + RoundState

**Status:** User story complete, ready to implement

**Problem:** No domain type models the trial or round
lifecycle. `Round.elm` says *which* round, not *where
it is* in its workflow. `Trial.elm` is a fully-resolved
pairing, but has no state beyond "exists."

### Trial lifecycle (per-courtroom)

The trial is the unit of locking, not the round.
"GREEN = GO" is per trial.

```
type TrialState
    = AwaitingCheckIn
        -- Trial exists (Pairing promoted). Volunteers
        -- checking in. Check-in list is mutable.
    | InProgress
        -- Admin starts this trial. Check-in locked.
        -- Expected scorers = whoever checked in.
        -- Ballots arriving.
    | Complete
        -- All checked-in scorers submitted. (Or admin
        -- manually closed for no-shows.)
    | Verified
        -- Admin reviewed/corrected all ballots.
```

**Key design decisions:**
- **Lock is per-trial.** Starting a trial freezes its
  check-in list. Other trials in the same round can
  still accept check-ins.
- **Expected scorers come from check-in, not pre-
  assignment.** The Steering Committee assigns on paper.
  The app captures the result via check-in.
- **Presiding judges check in too.** Same flow as
  scorers. Useful for last-minute judge changes.
- **No minimum scorer invariant.** Admins manage this
  informally. The app shows counts, doesn't block.

### Round lifecycle (derived from trials)

A round's state is derived from its trials' states.
Not a separate state machine — a query over trials.

```
type RoundProgress
    = CheckInOpen
        -- At least one trial still AwaitingCheckIn.
    | AllTrialsStarted
        -- All trials InProgress or later.
    | AllTrialsComplete
        -- All trials Complete or later.
    | FullyVerified
        -- All trials Verified.

roundProgress : List TrialState -> RoundProgress
```

**Key design decisions:**
- **Round can't close until all trials complete.**
- **Admin can manually close a trial** (for no-shows
  or missing scorers).
- **Admin can reopen a trial** for corrections. This
  should be possible but auditable.
- **Publication is a separate step** (see gap #6).

---

## 2. CheckIn (replaces VolunteerAssignment)

**Status:** User story complete, ready to implement

**Problem:** Volunteer and Conflict types exist (issue
#39) but no type represents "this volunteer is in this
courtroom for this round."

### How assignment and check-in work

**Before tournament day:**
1. Volunteers register (email, availability, conflicts).
   Walk-ups register via QR at door.
2. Steering Committee plans assignments on paper.
3. Admin enters **tentative assignments** in app.
   These are the plan, not yet confirmed.

**Tournament day — two check-in events:**

4. **Report for duty (jury assembly room).** Attorney
   arrives and checks in — admin input or QR scan.
   Confirms "I'm here today." No courtroom yet.
   State: Tentative → Present (or new → Present for
   walk-ups with no tentative assignment).

5. Admin directs volunteers to courtrooms (orally).

6. **Courtroom check-in.** Volunteer scans courtroom
   QR or picks courtroom in app. OAuth confirms
   identity. State: Present → CheckedIn.
   - Judges may skip jury assembly and go straight
     to courtroom: Tentative → CheckedIn.
   - Courtroom check-in can skip Present state.

7. Dashboard updates in realtime. Shows per volunteer:
   - **Tentative** — planned, not here yet
   - **Present** — in the building, no courtroom yet
   - **CheckedIn** — in courtroom, ready to score

8. Re-scan at different courtroom overwrites previous
   courtroom check-in (reassignment). Must clear
   localStorage ballot data.

9. Admin starts trial → check-in locked for that
   courtroom. Only **CheckedIn** volunteers are in
   the expected scorers list. Tentative and Present
   volunteers for that courtroom are not expected.

**State transitions:**
```
Tentative → Present → CheckedIn  (normal attorney)
Tentative → CheckedIn            (judge, direct)
(new)     → Present              (walk-up at assembly)
(new)     → CheckedIn            (walk-up, direct)
Present   → CheckedIn            (after oral assignment)
```

### Domain type

```elm
type VolunteerStatus
    = Tentative Courtroom
        -- Admin pre-assigned to courtroom. Plan only.
    | Present
        -- Reported for duty at jury assembly.
        -- No courtroom yet (or courtroom TBD).
    | CheckedIn Courtroom
        -- Confirmed at courtroom. Ready to score.

type VolunteerSlot = VolunteerSlot
    { volunteer : Volunteer
    , round : Round
    , status : VolunteerStatus
    }

-- One slot per volunteer per round.
-- Transitions: Tentative → Present → CheckedIn
--              Tentative → CheckedIn (skip assembly)
--              (new) → Present (walk-up)
--              (new) → CheckedIn (walk-up, direct)
-- Courtroom re-scan overwrites previous CheckedIn.

-- Two courtroom check-in workflows:
-- 1. Courtroom-specific QR → auto-assigns courtroom
-- 2. General QR / app → volunteer picks from dropdown

-- Conflict check at tentative assignment or check-in
validateCheckIn :
    Volunteer
    -> Courtroom
    -> Round
    -> Trial          -- trial in that courtroom
    -> List HardConflict
    -> List ( Round, Team, Team )
    -> ( VolunteerSlot, List SoftConflict )
    -- Hard conflicts block. Soft conflicts warn
    -- but allow (admin sees warning on dashboard).
```

**Key design decisions:**
- **Three states: Tentative, Present, CheckedIn.**
  Tentative carries a courtroom (the plan). Present
  has no courtroom (in the building, awaiting
  assignment). CheckedIn carries a courtroom
  (confirmed, ready to score).
- **Courtroom check-in can skip Present.** Judges
  often go straight to the courtroom. Walk-ups who
  get a direct assignment can too.
- **Assignment is to a courtroom, not a trial.** The
  courtroom implies the trial (one trial per courtroom
  per round). Volunteers think "courtroom."
- **One slot per volunteer per round.** Each transition
  overwrites previous state. No accumulation.
- **Only CheckedIn matters for trial start.** When
  admin starts a trial, only CheckedIn volunteers for
  that courtroom are expected scorers. Tentative =
  no-show. Present without courtroom = unassigned.
- **Judges check in too.** Same flow. The `judge`
  field on Trial (from Pairing) is the pre-assignment;
  courtroom check-in confirms presence.

---

## 3. BallotTracking (per trial)

**Status:** Ready to implement

**Problem:** No domain type tracks which ballots are
in and which are missing per trial.

### Design

Expected scorers = volunteers with CheckedIn status
when the trial started (TrialState → InProgress).
Tentative-only volunteers are not expected.

```elm
type BallotTracking = BallotTracking
    { trial : Trial
    , expectedScorers : List VolunteerSlot
        -- Only CheckedIn slots at trial start time.
    , submitted : List ( Volunteer, SubmittedBallot )
    , verified : List ( Volunteer, VerifiedBallot )
    , presiderBallot : Maybe PresiderBallot
    }

missingScorers : BallotTracking -> List Volunteer
isFullySubmitted : BallotTracking -> Bool
isFullyVerified : BallotTracking -> Bool
```

**Key design decisions:**
- **Expected set comes from CheckedIn slots at lock
  time.** Tentative-only = no-show = not expected.
- **Presider tiebreaker ballot tracked here too.**
  Support both workflows: judge enters digitally, or
  admin enters from paper ballot.
- **Trial auto-completes when all checked-in scorers
  submit.** Admin can also manually close (missing
  scorer won't submit).

---

## 4. Publication

**Status:** Ready to implement

**Problem:** No domain type models what information
is visible, to whom, and when.

### Design

Publication is per-round, all-or-nothing for a given
level. Never per-trial — all trials in a round publish
simultaneously.

```elm
type PublicationLevel
    = ResultOnly
        -- W/L result and next pairing
    | ScoreSheet
        -- Subtotals by category, team totals
    | FullBallots
        -- Individual scorer ballots

type Audience
    = OwnTeamCoach
        -- Coach sees only their team's data
    | AllCoaches
        -- All coaches see all teams
    | Public
        -- Anyone can see

type Publication = Publication
    { round : Round
    , level : PublicationLevel
    , audience : Audience
    }
```

**Key design decisions:**
- **Progressive disclosure.** Admin controls what
  level is published to which audience. Current
  convention: ResultOnly to OwnTeamCoach first, then
  ScoreSheet to OwnTeamCoach next day. Future goal:
  more transparency.
- **Verification and publication are separate steps.**
  All ballots verified does NOT auto-publish.
- **Never publish one trial before others.** Per-round
  only.
- **Publication is additive.** Publishing ScoreSheet
  to AllCoaches doesn't retract a previous ResultOnly
  to OwnTeamCoach — it's a higher level.

---

## 5. Standings Aggregation

**Status:** Straightforward, ready to implement

**Problem:** `TeamRecord` type exists (wins, losses,
pointsFor, pointsAgainst) and `rank` function works,
but no function builds `TeamRecord` from actual trial
results + verified ballots.

### Design

```elm
-- From a single trial's verified ballots, derive
-- the result
type TrialResult = TrialResult
    { prosecution : Team
    , defense : Team
    , prosecutionPoints : Int
    , defensePoints : Int
    , winner : Side
    }

-- Build from verified ballots (already have
-- PrelimResult.courtTotal and prelimVerdict)
trialResult :
    Trial
    -> List VerifiedBallot
    -> Maybe PresiderBallot
    -> Result (List Error) TrialResult

-- Build cumulative standings
aggregate :
    List TrialResult
    -> List ( Team, TeamRecord )

-- Head-to-head for tiebreaker
headToHead :
    Team
    -> Team
    -> List TrialResult
    -> { wins : Int, losses : Int }
```

**Connections:**
- Required by PowerMatch for R2–R4 seeding
- Required by elimination bracket seeding (top 8)
- Required by publication (standings display)
- Depends on PrelimResult.courtTotal (already done)

---

## 6. Elimination Side Rules

**Status:** Straightforward, rules clear (5.5K)

**Problem:** PowerMatch handles prelim side constraints.
No module handles elimination side rules, which depend
on meeting history.

### Design

```elm
type MeetingHistory
    = FirstMeeting
    | Rematch { priorSide : Side }
    | ThirdMeeting

meetingHistory :
    Team -> Team -> List Trial -> MeetingHistory

elimSideAssignment :
    MeetingHistory
    -> Team   -- higher seed
    -> Side   -- higher seed's most recent side
    -> ( Side, Side )
    -- ( higher seed's side, lower seed's side )
```

**Rules (5.5K):**
- First meeting: higher-ranked flips from previous
- Rematch: reverse sides from that meeting
- Third meeting: coin flip

---

## 7. Round ↔ PocketBase Mapping

**Status:** Deferred to persistence phase

Glue code for `Round` variant ↔ PocketBase
`{ number, type }` mapping. Not pure domain logic.

---

## Implementation Order

1. **TrialState + CheckIn + BallotTracking** — the
   connected round-lifecycle story. Implement as
   separate modules but design together.
2. **Publication** — depends on TrialState (must be
   Verified before publishing).
3. **Standings Aggregation** — independent. Needed
   for power matching and publication.
4. **Elimination Side Rules** — independent. Needed
   for R5+.
5. **PocketBase Mapping** — deferred to persistence.

---

## Related Issues

- #38 — Realtime admin dashboard (blocked by #1, #2)
- #39 — Conflict tracking (done, PR #48)
- #40 — Round/pairing closure (blocked by #1)
- #33 — Offline-resilient ballot scoring (blocked by
  #3)
- #34 — Ballot scoring UI (blocked by #3)
- #35 — Admin ballot review (blocked by #3)
- #49 — This milestone issue
