# Reference Data

Reference materials from the 2026 Riverside County Mock
Trial competition. These are historical records of how
the competition was actually run — useful as reference
but not necessarily a source of truth for how the app
should work. We're building to improve on past practice.

All reference data lives in `reference/fixtures/`.

## Directory Structure

```
reference/fixtures/
├── 2026-preliminary-rounds.md         # Compiled summary
│                                        of all 4 rounds
├── 2026 Team Names ... - Team Numbers.csv
├── 2026 Team Names ... - Student Names.csv
├── 2025-2026 Mock Trial Score Sheet - Round *.csv (x4)
└── source-pdfs/
    ├── 2026-mock-trial-handbook.pdf    # Official rules
    ├── courtrooms.pdf                  # Judge assignments
    ├── 2026 Mock Trial Round * Pairing*.pdf (x4)
    ├── Round 1 Results/               # Score sheets
    ├── Round 2 Results/
    ├── Round 3 Results/
    └── Round 4 Results/
```

## Key Files

### Handbook
`source-pdfs/2026-mock-trial-handbook.pdf` — Official
competition rules, evaluation criteria, and scoring
guidelines. Scoring rules on pp. 16–22.

### Compiled Round Data
`2026-preliminary-rounds.md` — Human-readable summary of
all 4 preliminary rounds: pairings, scores, standings,
courtroom assignments, and scoring rules extracted from
the handbook. This is the most useful single file for
understanding the 2026 competition.

### CSVs
- **Team Numbers** — Maps team numbers to school names
- **Student Names** — Roster of students per team
- **Score Sheet CSVs (Rounds 1–4)** — Raw Google Form
  responses from scoring attorneys. These are the actual
  ballots. Known data issues documented in
  `2026-preliminary-rounds.md`.

### Source PDFs
- **Pairing PDFs** — Official round pairings with team
  numbers, courtroom assignments, and side assignments
- **Result PDFs (score sheets)** — Aggregated output of
  all ballots for each trial. Shows Court Totals per
  side. Note: bailiff/clerk shown at 5 points
  (incorrect — should be 10 per handbook).
- **Courtrooms PDF** — Judicial officer assignments to
  courtrooms for the competition

## Caveats

- Score sheet PDFs show bailiff/clerk at 5 points;
  handbook says 10. The CSVs have the raw ballot data.
- Round 4 result PDFs are partially named as
  `PDFMailer*.pdf` (auto-generated names).
- Two CSV entries diverge from official PDFs — see
  "Known CSV Data Issues" in `2026-preliminary-rounds.md`.
- These materials reflect how things were done, not how
  they should be done. The app aims to improve on past
  processes.
