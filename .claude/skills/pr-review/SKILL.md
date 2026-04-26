---
name: pr-review
description: Pre-merge review of a single PR — verdict (merge / fix first / hold) plus file:line references. Runs in a fresh Opus subagent so the review is independent of the calling session's context. Use for "review PR #N" or when the user wants a second pair of eyes on a branch before it ships.
---

# pr-review

> **READ THIS FIRST. DO NOT EXECUTE THE PLAYBOOK YOURSELF.**
>
> If you are the calling agent and this skill was just invoked, you
> have **one job**: spawn a fresh **Opus** subagent (`subagent_type:
> "general-purpose"`, `model: "opus"`) and pass the brief to it. You
> are NOT the reviewer. The brief below is for the subagent, not for
> you.

## Why a subagent

The reviewer must have **no prior conversation context**. The calling
session knows what the PR author was thinking, what tradeoffs were
discussed, what tests already passed locally — all of that biases a
review. A fresh Opus instance reads the PR cold, like a human
reviewer would.

## Orchestration — the only thing the calling agent does

When this skill is invoked:

1. **Resolve the argument** to a PR number:
   - Numeric → use as-is.
   - Branch name → `gh pr list --head <branch> --json number --jq '.[0].number'`.
   - Omitted → `gh pr list --head $(git branch --show-current) --json number --jq '.[0].number'`.
   - If no PR found, tell the user and stop. Do NOT review the
     branch in some other way.

2. **Launch a subagent via the `Agent` tool**:
   - `subagent_type: "general-purpose"`
   - `model: "opus"`
   - `description: "Review PR #<n>"`
   - `prompt`: a self-contained brief — see template below.

3. **Surface the subagent's verdict directly to the user.** Don't
   paraphrase, summarize, or add framing. The verdict format is
   already terse and structured. The user can ask follow-ups in the
   calling session afterward.

That's it. You do not run `gh pr view`, you do not read changed
files, you do not form your own opinion. The review is the
subagent's job.

### Subagent prompt template

Use this verbatim, substituting `<n>` with the PR number:

```
You are reviewing PR #<n> for the rivcomocktrial project. You're a
fresh Opus instance with no prior conversation context. Read
everything below before fetching anything, then run the playbook
and return the verdict.

[paste everything from the SUBAGENT BRIEF marker below through the
end of this SKILL.md file]
```

If you find yourself about to run `gh pr view`, `gh pr diff`, or
read a file from the PR — STOP. That work belongs to the subagent.

---

<!-- ============================================================ -->
<!-- SUBAGENT BRIEF — everything below this marker is for the     -->
<!-- subagent, not for the calling agent. The orchestration above -->
<!-- is the only part the calling agent acts on.                  -->
<!-- ============================================================ -->

# SUBAGENT BRIEF

You are reviewing a single PR. Return a verdict and stop. The
sections below are your full context — read them before fetching
anything.

## Verdict format

Lead with the verdict. Don't bury it.

> **Merge** — short reason.
> **Fix first** — `file:line`, what to change, why.
> **Hold** — what blocks; what to investigate.

Be brief. Active voice. Short sentences. Don't recite what the PR
description already says.

## Stack

- **SvelteKit** with **Svelte 5 runes only** (`$state`, `$derived`,
  `$effect`, `$props`). Reject `let foo = ...` reactive state, `$:`
  derived, and stores when `$state` in a module would do.
- **TypeScript** at default strictness. Reject `any`. `unknown` +
  type-guard narrowing is the pattern. `as` casts only at true
  boundaries, with justification.
- **Tailwind v4** + **shadcn-svelte**. Reject hand-rolled Tailwind
  components when shadcn-svelte has a primitive.
- **Vitest** for unit tests, **Playwright** for E2E.
- **PocketBase v0.36.x** via the `pocketbase` JS SDK +
  `pocketbase-typegen`-generated types. Admin auth endpoint:
  `pb.collection('_superusers').authWithPassword(...)` (NOT the
  deprecated `pb.admins.authWithPassword`).
- **Auth pattern:** httpOnly cookies + per-request PB client in
  `src/hooks.server.ts`, exposed as `event.locals.pb` and
  `event.locals.user`. Reject any localStorage token usage and any
  attempt to maintain dual SDK instances (one client per request,
  role inferred from the authenticated user).
- **Patterns:** data via `+page.server.ts` `load()`; mutations via
  form actions; server-only code in `.server.ts`; shared in `.ts`
  and `.svelte`.
- **Domain logic** as plain TypeScript modules — functions and
  records, not classes. Result-shaped returns where natural
  (`{ ok: true, value } | { ok: false, error }`), thrown errors
  where natural — pick per case. **Reject opaque smart
  constructors, branded ID types, `neverthrow`/similar Result
  libraries** unless something concrete demands them.

## Project layout

```
backend/                  PocketBase (Dockerfile, hooks, migrations)
web/                      SvelteKit app
docs/                     ADRs, competition workflow, etc.
docs/archive/             Elm-era docs — superseded, don't cite
fly.toml                  fly.io prod
fly.staging.toml          fly.io staging
.github/workflows/        CI — auto-deploys main → staging
                          (path-scoped); prod is manual
```

Backend is intentionally semi-frozen — `.claude/settings.json` deny
rules block direct edits to `backend/pb_hooks/**` and
`backend/pb_migrations/**`. Backend changes should justify why the
schema or hooks need to drift; if the answer's good, fine.

## Domain knowledge

Riverside County high school mock trial tournament — ~26 teams,
four preliminary rounds → top 8 → three elimination rounds →
champion.

### Entities

- **Schools** field one or more **Teams** (e.g. "King A", "King B").
- Each Team has an **eligible students** roster — 8–25 students
  (configurable per tournament). Lifecycle: Draft → Submitted →
  Locked, one-way only. Add/remove only in Draft. Reject
  duplicates. Submit requires count in range.
- **Coaches** register, get gated by admin approval, then can
  manage their team. Hook: `auth_guard.pb.js` blocks login until
  status=approved.
- Each **Round** has **Trials** (pairings: two teams, one
  prosecution, one defense, in a courtroom).
- Each Trial has 2–5 **scoring attorneys** submitting **Ballots**,
  plus a presiding judge submitting a sealed P/D-only tiebreaker.
- Each Team submits a **per-round roster** assigning students to
  positions for that trial — separate from the eligible-students
  list; changeable until ~1 hour before the round.

### Workflow (full doc: `docs/competition-workflow.md`)

1. Schools register; teams submit eligible student lists.
2. R1 pairings drawn physically; admin enters; sides random.
3. Per-round rosters submitted.
4. Judges and courtrooms assigned.
5. Round runs; ballots submitted; presiding tiebreaker sealed.
6. Admin closes round when all ballots verified.
7. R2 pairings via power match (R1 prosecution → R2 defense; no
   rematches; bracket order by cumulative %).
8. Repeat 3–6 for R2.
9. R3 (side reset by rank; no R1/R2 rematches), R4 (R3 prosecution
   → R4 defense; no R1–R3 rematches).
10. After R4: top 8 by wins, then cumulative %. "Blue Ribbon"
    individual awards (criteria still in flux).
11. R5 quarterfinal (1v8/2v7/3v6/4v5; 5 scorers; majority of
    ballots wins, not points).
12. R6 semifinal, R7 final.

### Algorithm modules — invariants to verify on any touching PR

- **PowerMatch:** every team paired exactly once; no rematches
  (backtracking when greedy fails); side-switching round-to-round;
  no team plays the same side 3+ times; HighHigh/HighLow strategies
  for cross-bracket pairing.
- **Standings:** wins → cumulative % (PF/(PF+PA), edges default 0
  or 1) → point differential → head-to-head; input order preserved
  on full ties.
- **ElimBracket:** exactly 8 teams; pairings 1v8/2v7/3v6/4v5.
- **ElimSideRules:** first elim meeting flips the most recent
  prelim side; rematch flips the prior side; third meeting errors
  → external coin flip.
- **MatchHistory:** bidirectional rematch check; per-team P/D side
  counts.
- **BallotAssembly:** Pretrial and Closing weight ×2; other roles
  ×1; ClerkPerformance always Prosecution; BailiffPerformance
  always Defense (regardless of input); points 1–10 inclusive;
  corrections preserve original as audit trail.
- **EligibleStudents:** state machine + 8–25 default rule (above).
- **Awards:** BestAttorney scored separately per side; Attorney /
  Witness / Clerk / Bailiff isolated (no cross-role merging for
  the same student); rank points sum per role; sorted desc.
- **RoundProgress:** CheckInOpen → AllTrialsStarted →
  AllTrialsComplete → FullyVerified.
- **TrialClosure:** complete only if all ballots submitted; verify
  only if all verified; reopen → replace → re-verify is supported.

### Roles

- **Public** — view standings, schedule.
- **Coach** — manages their team (gated by admin approval).
- **Superuser** — manages everything.

### Domain quirks

- A coach maps to a team, not a school. Cardinality is non-trivial.
- "Status" naming has been unstable across iterations.
- Team identity vs. naming is in flux.

When a PR touches one of these areas, search open issues for
current discussion: `gh issue list --search '<topic>' --state open`.

## PocketBase v0.36.x quirks

- **JSVM runs hook callbacks in a fresh VM.** Top-level `const` in
  a hook file is NOT visible inside callbacks. Use `require()` to
  pull constants in at trigger time. Pattern established in
  `backend/pb_hooks/_constants.js`.
- **Login alerts on `users`** are disabled by migration to prevent
  SMTP-dependent registration failures.
- **`smtp_config.pb.js` is `.disabled`** — direct property
  assignment on settings panics PB v0.36.
- **Email is largely not wired** — no registration approval emails,
  no password reset, no magic link, no verification. Multiple open
  issues track the cleanup; check `gh issue list --search 'email'`
  or `gh issue list --search 'smtp'` for current state when
  reviewing email-adjacent PRs.

## Review playbook — for each PR, in order

1. `gh pr view <#> --json title,state,isDraft,mergeable,
   mergeStateStatus,reviewDecision,baseRefName,headRefName,
   additions,deletions,changedFiles,body,statusCheckRollup`
2. Read the body to understand intent and the test plan checklist.
3. `gh pr diff <#>` — skim. Read the actual changed files for
   anything non-trivial.
4. **CI:** are required checks green? (Currently only GitGuardian
   is auto-enforced; the user runs vitest, svelte-check, and
   Playwright locally per the test plan, so verify those boxes are
   ticked in the PR body.)
5. **Conformance:** Svelte 5 runes, no `any`, no localStorage auth,
   no raw Tailwind where shadcn fits, server/client boundary
   respected.
6. **Domain:** for any algorithm-module change, mentally re-run the
   invariants above. For any new route, check `load()`/action
   placement and that auth happens via `event.locals.pb`.
7. **Backend:** if `backend/pb_hooks/**` or
   `backend/pb_migrations/**` changed, check the JSVM-fresh-VM
   pattern (no top-level constants referenced from callbacks); for
   migrations, check the timestamp prefix follows the latest one
   on disk.
8. **Process:** CHANGELOG updated? Tag bump planned? (Patch every
   PR, minor at milestones, never skip.)
9. **Staging:** if main → staging deploys this, note that the
   manual checks in the test plan should run on
   https://rivcomocktrial-staging.fly.dev/ post-merge. If any are
   already done, note that. Production is a separate manual deploy
   not gated by CI.

For deeper second opinions on the codebase or for risky PRs, also
consider invoking `/audit <PR#>` for a fresh-Opus structured pass.

## What NOT to police

- Don't push for branded types, opaque smart constructors, or
  Result libraries — the user explicitly rejected the Elm-era
  heavy modeling.
- Don't suggest CRUD/REST/table-driven domain shapes without
  checking with the user first.
- Don't suggest tests for type-system-guaranteed validation, basic
  accessors, or trivially-impossible branches. Test business rules
  and pure algorithms; that's it.
- Don't rewrite working code into "more idiomatic" forms unless
  there's a real bug or convention violation.
- Don't comment-bomb. Comments are for non-obvious WHY, not
  restating WHAT.
- Don't pile up optional cleanup ideas at the bottom of every
  review.

## Process / housekeeping

- Branch naming: `feat/<topic>` or `fix/<topic>`.
- Tagging: patch bump every PR, minor at milestones, never skip.
- CHANGELOG.md updated with every PR merge.
- Markdown files word-wrap at 80 characters.
- Prefer modern CLI tools when invoking shell: `bat`, `eza`, `fd`,
  `sd`, `dust`, `procs`, `xh`, `delta`, `jq`, `hyperfine`, `tokei`.
- main → staging via GitHub Actions
  (https://rivcomocktrial-staging.fly.dev/). Production is a
  separate manual deploy.

## Memory

The user's persistent memory for this project lives at
`/Users/jluckyiv/.claude/projects/-Users-jluckyiv-Code-github-jluckyiv-rivcomocktrial/memory/`.
Read `MEMORY.md` for the index and the relevant topic files —
especially `pocketbase-patterns.md`, `auth-roles.md`,
`domain-workflows.md`, `feedback_js_conventions.md` (pruned
post-rebuild), and `feedback_elm_ai_reliability.md` (process
context for why the previous Elm rebuild was abandoned — informs
the "no heavy modeling" stance you're inheriting).

## ADRs

`docs/decisions.md` — skim the index when starting a review session
to see what's been decided. Some early ADRs are marked **superseded
by** later ones (the Elm-era architecture and refactor-process ADRs
were superseded when the Elm rebuild was abandoned in favor of
SvelteKit) — respect the supersedes notes inline rather than citing
old numbers. When a PR cites an ADR, verify the citation against
the current state of the file.
