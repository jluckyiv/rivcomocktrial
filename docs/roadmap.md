# Roadmap

## Context

Riverside County Mock Trial currently runs on spreadsheets, Google Forms, and email — registration, pairing, ballot entry, scoring, and announcements are all manual. This is error-prone and labor-intensive for the small admin team (2–5 people). Teacher coaches currently have no direct system access.

This roadmap builds an admin-first competition management tool backed by PocketBase, progressively adding coach self-service and public-facing results. The system replaces the entire spreadsheet/email workflow.

### Key Domain Facts

- ~26 teams, 7 rounds (4 preliminary + 3 elimination)
- School ≠ Team (a school can field 1–2 teams per tournament)
- Schools have districts (tracked by RCOE)
- Two kinds of coaches: teacher coaches (submit rosters) and attorney coaches (currently view-only)
- Registration in December, random drawing in January, competition January–March
- Pairings for round 1 are drawn live (manual input); rounds 2+ are power-matched
- Scorers are volunteer attorneys — no pre-registration, they scan a QR or tap a link
- All results are admin-published per round (not visible until released)
- Blue Ribbon individual awards are based on preliminary rounds only (rounds 1–4), using AMTA-style ranking criteria (ranks, raw scores, comparison to median/mean — details developing)
- Power-matching rules are incomplete and will be revised (separate conversation)

---

## Milestone 0: Foundation ✅

**Status:** Done

- Elm Land + PocketBase + Docker + fly.io skeleton
- Bulma CSS, dev workflow (compose watch, npm scripts), CI/CD

## Milestone 1: Data Model & Admin Auth ✅

**Status:** Done (v0.1.0)

**Goal:** Core entities exist in PocketBase. Admins can log in and manage tournaments.

### Collections

| Collection   | Fields                                                                 | Relations             |
|-------------|------------------------------------------------------------------------|-----------------------|
| tournaments | name, year, num_preliminary_rounds, num_elimination_rounds, status     | —                     |
| schools     | name, district                                                         | —                     |
| courtrooms  | name, location                                                         | —                     |
| teams       | team_number, name                                                      | → tournament, → school |
| students    | name                                                                   | → school              |

### Pages

- Admin login (PocketBase superuser auth)
- Tournament create/edit/delete
- School list and editor (with district)
- Team list: assign schools to tournament, assign team numbers
- Student roster: per-school student list
- Courtroom list and editor

### Auth Model

| Role           | Access                          | Auth method                    |
|----------------|--------------------------------|--------------------------------|
| Admin          | Full access                    | PocketBase superuser (email/password) |
| Teacher coach  | Submit rosters, view published | OAuth (Google/MS), linked to school   |
| Attorney coach | View published results         | View-only                             |
| Scorer         | Enter ballots                  | No auth — anonymous via link          |
| Public         | View published results         | No auth                               |

**Note:** Milestone 1 implements admin auth only. Coach OAuth and other roles come later.

---

## Milestone 2: Round Pairing & Scheduling

**Status:** Not started

**Goal:** Admin can create rounds, input pairings (round 1 manual from live drawing), and assign courtrooms. System handles power matching for rounds 2+.

### Collections

| Collection | Fields                                              | Relations                          |
|-----------|----------------------------------------------------|------------------------------------|
| rounds    | number, date, type (preliminary/elimination), published | → tournament                    |
| trials    | —                                                   | → round, → prosecution_team, → defense_team, → courtroom |

### Features

- Round 1: Admin manually inputs pairings from the live drawing
- Rounds 2+: Power matching engine (details TBD — separate conversation)
- Side assignment tracking: ensure teams alternate prosecution/defense, avoid rematches
- Courtroom assignment UI
- Handle team drops (bye handling if odd count)
- Handle second-team additions (school fielding two teams)

### Pairing Constraints

- No rematches in preliminary rounds
- Balance side assignments (each team plays P and D roughly equally)
- Power match by record (same W-L face each other)

---

## Milestone 3: Round Rosters & Ballot Setup

**Status:** Not started

**Goal:** Teacher coaches submit per-round rosters with role assignments. Ballot forms auto-populate from rosters and courtroom assignments.

### Collections

| Collection       | Fields                              | Relations              |
|-----------------|-------------------------------------|------------------------|
| round_rosters   | submitted_at, locked                | → team, → round        |
| role_assignments| role, detail                        | → round_roster, → student |

### Roles on a Roster

- Pretrial attorney
- Trial attorneys (up to 3) — with assignment: opening, direct of witness N, cross of witness N, closing
- Witnesses (4) — with character name
- Clerk
- Bailiff

### Features

- Coach-facing roster submission form (OAuth login)
- Roster due X days before round, editable until Y minutes before (configurable per tournament)
- Admin can view/edit any roster
- Roster data feeds into ballot form (auto-populates student names for each scored category)

---

## Milestone 4: Ballot Entry & Scoring

**Status:** Not started

**Goal:** Scorers enter ballots via link; system computes round winners and stores results.

### Collections

| Collection | Fields                                                | Relations    |
|-----------|-------------------------------------------------------|-------------|
| ballots   | scorer_name, scorer_email, prosecution_total, defense_total, submitted_at | → trial |
| scores    | category, points, rank (nullable)                     | → ballot, → student |

### Ballot Entry Flow

1. Scorer taps link or scans QR code → general entry page
2. Scorer selects courtroom and round → ballot populates with teams, rosters, presiding judge
3. Scorer enters name/email
4. Scorer scores each individual (1–10, or 1–5 for clerk/bailiff)
5. Scorer enters ranks: up to 5 attorneys (including pretrial), up to 5 non-attorneys (witnesses, clerk, bailiff), best to worst. Minimum 3 ranks per category required.
6. Submit

### Scoring Rules

- Pretrial motion: ×2 weight
- Closing argument: ×2 weight
- All other categories: ×1
- Round winner: majority of ballots (not total points)
- Presiding judge casts tiebreaker ballot only if scorers split evenly

### Admin Controls

- View all submitted ballots for a round
- Edit/correct ballots before publishing
- Publish round results (makes scores visible to coaches/public)

---

## Milestone 5: Rankings, Standings & Blue Ribbon Awards

**Status:** Not started

**Goal:** System computes team rankings and individual awards from preliminary rounds.

### Team Rankings (after each preliminary round)

1. Win-loss record
2. Cumulative points (tiebreaker 1)
3. Point differential (tiebreaker 2)

### Blue Ribbon Individual Awards (rounds 1–4 only)

- Based on AMTA-style criteria: ranks, raw scores, comparison to ballot median/mean
- May also consider win-loss record
- Details developing — will be refined with PDFs and further conversation

### Features

- Standings page (updates after admin publishes each round)
- Individual performance tracking across rounds
- Blue Ribbon computation and display
- Coach score sheets: aggregate view per round (format TBD from PDF)

---

## Milestone 6: Elimination Bracket

**Status:** Not started

**Goal:** After preliminary rounds, generate and manage single-elimination bracket.

- Seed top 8 from preliminary rankings
- Bracket visualization
- Elimination round ballot entry and results (same scoring flow)
- Championship tracking

---

## Milestone 7: Public Site & Notifications

**Status:** Not started

**Goal:** Participants and spectators can see schedules, results, and standings without logging in.

- Public pages: schedule, pairings, standings, bracket, round results
- All gated by admin publish status (nothing visible until released)
- Mobile-friendly
- Notifications: replace email announcements (in-app or email via PocketBase)

---

## Milestone 8: Polish & Production

**Status:** Not started

**Goal:** Production-ready, multi-admin, data export.

- Role-based access enforcement across all pages
- Concurrent ballot entry by multiple scorers
- Data export (CSV/PDF for RCOE records)
- Configurable tournament settings (roster deadlines, rank requirements, etc.)
- Production deployment to fly.io
- Historical data: support multiple tournament years

---

## Open Questions

These are deferred to the relevant milestones:

- Power matching algorithm details (before Milestone 2)
- Blue Ribbon award exact formula / AMTA variation (Milestone 5)
- Score sheet format for coaches (pending PDF, Milestone 5)
- Whether attorney coaches need any write access
- Whether teacher coach must be different per team from same school (rule clarification)
- Ballot visibility policy: will coaches ever see full individual ballots, or always aggregates only?
