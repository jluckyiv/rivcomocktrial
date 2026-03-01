# Competition Workflow

End-to-end workflow for a Riverside County Mock Trial
season, from registration through championship. This
document captures domain rules, sequencing, and design
decisions that drive the app's domain model.

Reference: 2026 Handbook Rule 5 (pp. 16–22).

---

## Phase 1: Registration

1. **Teams register** for the season. Teacher coaches
   handle registration.
2. **Teams submit eligible student lists.** These are
   students who may appear on rosters, not the rosters
   themselves.

---

## Phase 2: Preliminary Rounds (R1–R4)

### Round 1 (Random Drawing)

3. **R1 pairings are drawn physically** — names from a
   basket, not digital. Admin inputs results into the
   app. The drawing determines both opponents and sides
   (prosecution/defense). (Rule 5.5A)
4. **Teams submit rosters** for R1. Rosters are due X
   days before the round (configurable). Rosters can
   be changed up to Y minutes before the round
   (configurable, ~1 hour). Teams often change role
   assignments between rounds for competitive reasons.
5. **Pairings get judges and courtrooms assigned.**
   These are independently assignable — either can be
   set in any order, and either can change until the
   round starts. (Modeled as `Assignment a` on
   `Pairing`; promotion to `Trial` requires both.)
6. **Round takes place.** Scoring attorneys (2–5 per
   trial; 5 for Elite 8, Semi-Final, Final) submit
   ballots. The presiding judge does not score but
   casts a sealed tiebreaker ballot selecting a winner,
   used only if Court Totals tie. (Rules 5.2A, 5.2C,
   5.5F)
7. **Admin closes the round.** When all ballots are in,
   admin reviews, makes corrections if needed, and
   closes the round. The app determines winners per
   trial. (See Ballot Lifecycle below.)

### Round 2 (Power Matched)

8. **App assigns R2 pairings via power matching.**
   (Rule 5.5A)
   - **Side rule:** R1 prosecution → R2 defense and
     vice versa. (Rule 5.5B)
   - **No rematches:** Teams cannot face the same
     opponent as R1. (Rule 5.5B)
   - **Within-bracket ordering:** Highest cumulative
     percentage vs. lowest within each W-L bracket.
     (Rule 5.5E)
   - **Cross-bracket strategy:** Configurable —
     high-high or high-low. (See power-matching-
     analysis.md)
9. Repeat steps 4–7 for R2.

### Round 3 (Power Matched, Side Reset)

10. **App assigns R3 pairings via power matching.**
    (Rule 5.5C)
    - **Side rule:** The higher-ranked team (by
      cumulative percentage) switches sides from its
      previous round. This starts a new R3↔R4 side
      pair — no constraint carried from R1↔R2.
      (Rule 5.5C)
    - **No rematches:** Teams cannot face anyone they
      faced in R1 or R2. (Rule 5.5C)
    - Already tested in PowerMatch module.
11. Repeat steps 4–7 for R3.

### Round 4 (Power Matched)

12. **App assigns R4 pairings via power matching.**
    (Rule 5.5D)
    - **Side rule:** R3 prosecution → R4 defense and
      vice versa. (Rule 5.5D)
    - **No rematches:** Teams cannot face anyone from
      R1, R2, or R3. (Rule 5.5D)
13. Repeat steps 4–7 for R4.

---

## Phase 3: Preliminary Results

14. **App determines top 8 teams.** (Rule 5.5G, 5.5M)
    - Ranked first by most wins, then by highest
      cumulative percentage.
    - Strength of schedule is NOT a factor in
      determining the top 8. (Rule 5.5M)
    - **Tiebreakers are configurable** — rules may
      change year to year, so model different
      tiebreaker criteria and priority orderings.

15. **App determines individual awards** ("Blue Ribbon"
    awards). Always after R4 and presented countywide.
    - Based on ballot ranks and possibly other criteria.
    - Details are in flux — see Individual Awards
      section below.

---

## Phase 4: Elimination Rounds (R5–R7)

### Elite 8 / Quarterfinal (R5)

16. **Seeding:** 1 vs 8, 2 vs 7, 3 vs 6, 4 vs 5.
    (Rule 5.5H — "basketball tournament method")
17. **Side rule:** The higher-seeded team switches sides
    from R4. This rule applies to all elimination
    rounds: the higher-ranked team flips from its
    previous round's side. (Rule 5.5K — first meeting)
18. **Rosters submitted.** Same process as prelims
    (step 4).
19. **Courtroom/judge assignment.** Same process as
    prelims (step 5).
20. **Round takes place.** Scoring panels have 5 scorers
    for Elite 8, Semi-Final, and Final. (Rule 5.2A)
    - **Playoff scoring:** Based on a team winning,
      losing, or tying on each scorecard (not total
      points). The team that wins the majority of
      scorecards wins. (Rule 5.5L)
    - Ties (e.g., 2-2-1 or 1-1-3): presiding judge
      decides. (Rule 5.5L)
    - **Ballot format:** Attorney-only ranks (not full
      roster ranks like prelims). Details TBD.
21. **Admin closes the round.** App determines winners
    by ballot majority.

### Semifinal (R6)

22. **Top 4 teams.** Winners of R5 advance.
23. **Side rule:** If teams are meeting for the first
    time, higher-ranked team flips from previous round.
    If teams met before (in prelims), they reverse
    prosecution/defense from that meeting. If they've
    met twice, coin flip. (Rule 5.5K)
24. Repeat steps 18–21 for R6.

### Final (R7)

25. **Top 2 teams.** Winners of R6 advance.
26. **Side rule:** Same as R6 (Rule 5.5K).
27. Repeat steps 18–21 for R7.
28. **App determines champion** by ballot majority.
    Also determines top advocate for playoffs.
    (Rule 5.5J — winning team represents Riverside
    County at state competition.)

---

## Ballot Lifecycle

Ballots go through two stages to support corrections
and provide an audit trail:

1. **Submitted** — Scorer submits ballot via link/QR.
   Raw data as entered. May contain errors (e.g., the
   2026 R1 Dept 2G issue where "10" was captured as
   "1", or R2 Dept 52 duplicate submission).

2. **Verified** — Admin reviews and approves the ballot.
   Corrections are tracked: the original submitted data
   is preserved, and changes are recorded with who made
   them and when. A verified ballot is what counts for
   scoring.

**Design principles:**
- Original submission is immutable — never overwritten.
- Corrections create a new verified version linked to
  the original.
- Audit trail: who changed what, when, and why.
- Round cannot be closed until all ballots for all
  trials in the round are verified.

### Presider Tiebreaker Ballot

The presiding judge's ballot is a separate input — not
a scored ballot, just a side selection (prosecution or
defense). Used only when Court Totals tie. (Rule 5.5F
for prelims; Rule 5.5L for playoffs.)

Input method TBD: admin inputs from paper ballot, or
judge inputs directly. Either way, it's a simple
`Side` value per trial, not a full scored ballot.

---

## Side Assignment Summary

| Round | Rule | Side Determination |
|-------|------|--------------------|
| R1 | 5.5A | Random drawing |
| R2 | 5.5B | Flip from R1 (P→D, D→P) |
| R3 | 5.5C | Higher-ranked team flips from previous round |
| R4 | 5.5D | Flip from R3 (P→D, D→P) |
| R5+ | 5.5K | First meeting: higher-ranked flips from previous. Rematch: reverse from that meeting. Third meeting: coin flip. |

---

## Scoring Rules Summary

### Preliminary Rounds (R1–R4)

- **Scale:** 1–10 per category, 5 is baseline.
  (Rule 5.4A–B)
- **Weighted categories:** Pretrial motion (x2) and
  closing arguments (x2). (Rule 5.4D)
- **Court Total:** Sum of all scorers' weighted scores
  per side, plus clerk (to P) and bailiff (to D).
- **Winner:** Higher Court Total wins.
- **Ties:** Presiding judge's tiebreaker ballot decides.
  (Rule 5.5F)

### Elimination Rounds (R5–R7)

- **Winner:** Majority of scorecards, not total points.
  (Rule 5.5L)
- **Ties:** Presider decides. (Rule 5.5L)
- **Panel:** 5 scoring attorneys for Elite 8, Semi-
  Final, and Final. (Rule 5.2A)

---

## Individual Awards

**Status:** In flux. What we know:

- Always determined after R4 (preliminary rounds only).
- Presented countywide.
- Based on ballot ranks (scorers rank attorneys and
  non-attorneys separately, minimum 3, maximum 5 per
  category).
- May use AMTA-style criteria: ranks, raw scores,
  comparison to ballot median/mean.
- May also consider win-loss record.
- 14 award categories mentioned in domain roadmap.
  Witness categories carry character names.

**Open questions:**
- Exact ranking formula and tiebreaker criteria.
- Whether win-loss record factors into individual
  awards or is only for team standings.
- Whether different categories use different criteria.
- How to handle scorers who rank fewer than 5 (the
  minimum is 3).

**TODO:** Document the specific criteria when finalized.

---

## Team Ranking (Prelim Standings)

After each preliminary round: (Rule 5.5E, 5.5M)

1. **Wins** (most first)
2. **Cumulative percentage** — sum of team's Court
   Totals / sum of both sides' Court Totals across all
   rounds played. (Rule 5.5M)

Strength of schedule is NOT a factor. (Rule 5.5M)

Tiebreakers beyond cumulative percentage are
configurable — rules may change year to year.

---

## Invariants

Things the app must always enforce:

- **Even team count.** No byes. The tournament always
  has an even number of teams.
- **No rematches in prelims.** A team never faces the
  same opponent twice in R1–R4.
- **Side balance in prelims.** Each team plays P
  exactly twice and D exactly twice across R1–R4.
- **All ballots verified before round closes.**
- **All assignments filled before round starts.**
  (Pairing → Trial promotion via `fromPairing`.)

---

## Roster Rules

- Rosters are **per-round, per-team** — not per-
  tournament. Teams frequently change role assignments
  between rounds.
- Rosters are due X days before the round
  (configurable per tournament).
- Rosters can be changed up to Y minutes before the
  round (configurable, typically ~1 hour).
- Students must be on the team's eligible student list
  to appear on a roster.

---

## What This Document Does NOT Cover

- **Scorer recruitment/assignment** — Scorers are
  volunteer attorneys, no pre-registration. They scan
  a QR or tap a link. Assignment to courtrooms is
  handled separately.
- **Notification/publishing** — How and when results
  are released to coaches and the public.
- **Coach auth** — OAuth flow for teacher/attorney
  coaches.
- **Data export** — CSV/PDF for RCOE records.
