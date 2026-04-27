# Audit Skills — Implementation Brief

Build plan for five new audit skills that complement the existing
`/audit` (code quality), `/pr-review`, and `/security-review` skills.
Each skill is self-contained: own rubric, own scope resolver, own
fresh-Opus brief, own output. Reuse happens at the bash-helper level,
not via skill chaining.

The goal of this document is to be fully self-contained for a fresh
Claude Code session that has no memory of the conversation that
produced it. Read top to bottom, then build skill 1, ship the PR,
then skill 2, etc. Do not bundle.

## Build order

| #   | Skill            | Purpose                                                     |
| --- | ---------------- | ----------------------------------------------------------- |
| 1   | `/audit-schema`  | Every PB collection has rule lockdown; lockdown matches live |
| 2   | `/audit-docs`    | CLAUDE.md, README, ADRs, docs/* match code reality          |
| 3   | `/audit-domain`  | `web/src/lib/domain/` follows ADR-009 + ADR-012 patterns    |
| 4   | `/audit-a11y`    | Key flows meet WCAG 2.2 AA — semantics, keyboard, contrast  |
| 5   | `/audit-deps`    | npm audit + outdated + GHA / Docker pin compliance          |

## Why these five (context the implementer can skip)

`/audit` covers line-level code quality. `/pr-review` covers
pre-merge sanity for one PR. `/security-review` covers branch
security. Together they handle change-driven review.

These five fill survey-driven gaps: "is the schema lockdown still
complete," "do the docs still match," "is the domain layer drifting
from its codified principles," "is the public site usable to
keyboard / screen-reader users," "are dependencies and pins safe."
Each runs on demand and on a periodic cadence that is not
PR-triggered.

## Project context the implementer needs

- **Stack.** SvelteKit (Svelte 5 + TS) at `web/`. PocketBase
  v0.36.x at `backend/`. fly.io deploy. Caddy single-origin reverse
  proxy on port 8090 (PB at 8091, SvelteKit at 3000). See CLAUDE.md.
- **Scale.** ~100–400 users, four times a year. Performance and
  load are not concerns; data is precious. Never recommend caching,
  queueing, replicas, or anything justified by "scale."
- **Test container.** `docker-compose.test.yml` runs PB on port
  28090 with a wipeable named volume. `npm run pb:test:up` starts
  it, sourcing `.env.test`. All test layers use the test container,
  never the dev container on 8090.
- **No mocks.** Hook and schema tests hit the real test PB.
- **Branch discipline.** Every skill ships on a worktree at
  `.claude/worktrees/<skill-name>` on branch `feat/audit-<skill>`.
  Never commit to main.

## Common conventions across all five skills

These apply to every skill. Each per-skill section assumes them.

### Location

Each skill lives at:

```
.claude/skills/audit-<name>/
  SKILL.md           # frontmatter + steps + rubric
  <helper>.sh        # bash helper(s) for grep / api calls
```

### Frontmatter format

```markdown
---
name: audit-<name>
description: <one sentence — what + when to use>
---
```

Keep the description specific so the harness can match invocation
intent.

### Refusal guard

Match the existing `/audit` skill's safety check: refuse if the
working directory is outside `~/Code/github` or `~/Code/playground`.
Inline the same logic at the top of each new SKILL.md:

> Only run inside `~/Code/github` or `~/Code/playground`. Refuse
> if the working directory is outside those paths (e.g. Vault,
> dotfiles).

### Agent model

All five skills use the `general-purpose` Agent with
`model: "opus"`. The cost is real but periodic audits are exactly
the case for the strongest reasoner. The brief must be
self-contained — Opus has no memory of any prior conversation.

### Output format (every skill)

The agent must return:

```
## Findings

### Critical
### Warnings
### Suggestions
### Praise
```

Each finding: what, where (`file:line` where applicable), why it
matters. 2–3 lines max. Empty sections: "None."

Skills that produce tabular data (a11y violation counts, schema
coverage matrix) append the table after the four sections.

### Stay-in-lane discipline

Each SKILL.md ends with an explicit "Out of scope" section. The
agent prompt copies that section verbatim and instructs the agent
not to drift. This is the lesson from `feedback_audit_scope.md`.

### Workflow downstream of findings

The skill produces findings; it does not open issues. The user
triages the output and opens one issue per non-trivial finding.
One PR per issue. This matches `feedback_chat_is_for_planning.md`
and the 2026-04-26 plan's workflow rules.

--------------------------------------------------------------------

## Skill 1: `/audit-schema`

### Goal

Every collection in `web/src/lib/pocketbase-types.ts` has a current
rule lockdown in `web/src/lib/schema/*.spec.ts`. Every assertion
matches the live rule string on the test PB. Run on demand and
monthly. Pre-tag.

### Why this exists

The schema-rule sweep was a one-time effort (Task 9 of the
2026-04-26 audit). Without an ongoing check, a migration that
accidentally relaxes a rule slips through silently — the spec still
asserts the *old* string, and unless someone notices, the protection
erodes. This audit answers: "is the lockdown still complete and
accurate?" — not "what changed since last week."

### Scope

**In scope.**
- Every collection enumerated in `web/src/lib/pocketbase-types.ts`.
- Every spec file in `web/src/lib/schema/`.
- Live rule strings from the test PB on port 28090.

**Out of scope.**
- Recommending rule *changes* (this is a lockdown audit, not a
  hardening audit).
- Migrating collections.
- Writing missing specs (identify them; do not author).
- Hook behavior, even if a rule references a hook.
- Domain logic.

### Files to create

```
.claude/skills/audit-schema/SKILL.md
.claude/skills/audit-schema/schema-completeness.sh
```

### Reference material the implementer reads first

Before writing the skill, the implementer reads these. The skill's
agent brief later includes summarized excerpts.

- `web/src/lib/schema/coach-access.spec.ts` — canonical assertion
  pattern. New specs should match.
- `web/src/lib/schema/users.spec.ts`,
  `web/src/lib/schema/ballots.spec.ts`,
  `web/src/lib/schema/tournaments.spec.ts`,
  `web/src/lib/schema/schools-districts.spec.ts` — current corpus.
- `web/src/lib/test-helpers/pb-admin.ts` — `getCollection()` and
  related helpers.
- `web/src/lib/pocketbase-types.ts` — generated; the canonical
  enumeration of collection names.
- `backend/pb_migrations/` — last 5 files by timestamp; recent
  changes are most likely to have drifted from specs.

### Steps the skill performs

1. **Boot test PB.** Run `npm run pb:test:up` from repo root. Wait
   for health (`curl http://localhost:28090/api/health`).
2. **Enumerate collections.** Parse the `Collections` enum in
   `web/src/lib/pocketbase-types.ts`. The names there are the
   ground truth.
3. **Fetch live rules.** For each collection, call
   `GET /api/collections/<name>` with a superuser auth token from
   `.env.test`. Capture: `listRule`, `viewRule`, `createRule`,
   `updateRule`, `deleteRule`. `null` means "superusers only" and
   is a valid distinct value from `""` (everyone).
4. **Parse spec assertions.** For each `.spec.ts` file in
   `web/src/lib/schema/`, identify which collection it covers and
   which of the 5 rules it asserts. Capture the asserted string.
   Any `it.skip` is captured but flagged.
5. **Build coverage matrix.** Two-dimensional: collection × rule
   slot. Each cell is one of: `match`, `mismatch`, `unasserted`,
   `skipped`.
6. **Brief Opus.** Send the matrix, the live rule strings, the
   asserted strings, the rubric, and the canonical
   `coach-access.spec.ts` example. Ask for severity-ranked findings.
7. **Print output** in the standard Findings format plus the
   coverage matrix table.

### Rubric (passed to the agent)

- Every collection in `pocketbase-types.ts` has a spec file
  covering it (one spec file may cover several related
  collections — group by domain, e.g., `ballots.spec.ts` covers
  all ballot collections).
- Every spec asserts all 5 rule slots per collection (`listRule`,
  `viewRule`, `createRule`, `updateRule`, `deleteRule`).
- Every assertion is a strict-equality (`toBe()`) match against
  the live rule string. `null` rules use `toBeNull()`.
- Asymmetric coverage (e.g., `viewRule` asserted but `updateRule`
  unasserted) is a Warning even when the unasserted rule is `null`
  (superusers only) — explicit assertion is the lockdown.
- `it.skip` entries are flagged. Each must have a comment linking
  to a tracking issue. A skipped test without a comment is Critical.

### Severity rules

- **Critical.** A live rule does not match the asserted string
  (drift detected). A skipped test with no issue link.
- **Warning.** A collection has zero coverage. Asymmetric coverage.
- **Suggestion.** Spec organization (consolidating files,
  deduplicating helpers).
- **Praise.** Collections with full 5-rule lockdown matching live.

### Output format

Standard Findings sections, then:

```
### Coverage matrix

| collection | list | view | create | update | delete |
| ---------- | ---- | ---- | ------ | ------ | ------ |
| users      | ✓    | ✓    | ✓    | ✓     | ✓     |
| teams      | ✓    | ✓    | ✓    | ✗     | -     |
| ...        |      |      |      |       |       |

Legend: ✓ = matches live | ✗ = mismatch | - = unasserted | s = skipped
```

### Verify the skill works

1. Run `/audit-schema` on current state. Output names every
   collection in `pocketbase-types.ts`. Coverage matrix renders.
2. Temporarily edit one assertion in
   `web/src/lib/schema/users.spec.ts` to expect a wrong string.
   Re-run. Confirm Critical finding.
3. Revert.

### Out of scope (copy verbatim into SKILL.md)

- Do not propose rule *changes*.
- Do not author missing specs (only identify them).
- Do not migrate collections.
- Do not comment on hook behavior, domain logic, or UI.

--------------------------------------------------------------------

## Skill 2: `/audit-docs`

### Goal

Every load-bearing claim in `CLAUDE.md`, `README.md`,
`docs/decisions.md` (ADRs), and other `docs/*.md` matches code
reality. Run on demand and quarterly. Pre-tag.

### Why this exists

`CLAUDE.md` already drifted once (Task 1 of the 2026-04-26 audit).
ADRs in `docs/decisions.md` are 15 entries deep and at least two
are likely stale (initial recon flagged ADR-002 Bulma vs current
Tailwind; ADR-013 persistence freeze vs shipping refactor). Docs
that lie are worse than docs that are missing — they mislead
future sessions, including AI agents that take them as truth.

### Scope

**In scope.**
- `CLAUDE.md`
- `README.md`
- `docs/decisions.md` (every ADR, including those marked
  superseded — verify the supersession note exists and is correct)
- `docs/competition-workflow.md`
- `docs/backups.md`
- `docs/pocketbase-jsvm.md`
- `docs/power-matching-analysis.md`
- `docs/smoke-tests.md`
- Any future `docs/*.md` (auto-discovered)

**Out of scope.**
- `docs/archive/` (frozen historical artifacts).
- `frontend/` and any references to it (legacy Elm; per user
  policy, ignore entirely except in planning context).
- Prose quality, ADR format, file naming.
- New ADR proposals (the audit reports drift; the user decides
  what supersedes what).

### Files to create

```
.claude/skills/audit-docs/SKILL.md
.claude/skills/audit-docs/docs-claims.sh
```

The helper script extracts code-verifiable claims (file paths,
shell commands, port numbers, package names, hook file names,
architectural assertions) from each doc.

### Reference material the implementer reads first

- All of `docs/*.md` (excluding `archive/`)
- `CLAUDE.md`
- `README.md`
- Root `package.json` and `web/package.json` — to verify stack
  claims and script names
- `docker-compose.yml`, `docker-compose.test.yml`, `Caddyfile`,
  `backend/Dockerfile`, `backend/Dockerfile.dev` — to verify
  topology claims
- `backend/pb_hooks/` listing — to verify hook file name references

### Steps the skill performs

1. **Extract claims.** For each doc, identify candidate claims:
   - File path references (`backend/pb_hooks/auth_guard.pb.js`)
   - Shell command references (`npm run pb:test:up`)
   - Port number references (`8090`, `8091`, `28090`, `3000`)
   - Stack component references (`Bulma`, `Tailwind`, `Caddy`,
     `tini`, `adapter-node`)
   - ADR decision text (`We will use Bulma`)
   - Architectural assertions (`Caddy proxies /api/* to PB`)
2. **Verify against code.**
   - File paths: run `ls`/`fd` to confirm.
   - Shell commands: grep `package.json` `scripts` blocks.
   - Port numbers: cross-check with `Caddyfile`,
     `docker-compose*.yml`.
   - Stack components: cross-check with `package.json`
     dependencies.
   - ADR decisions: cross-check with current code (e.g., does the
     stack still use Bulma?).
3. **Read the change history of any flagged ADR.** `git log`
   `docs/decisions.md` to see when the decision was made and when
   the code that contradicts it landed.
4. **Brief Opus.** Send the claim list, verification results, and
   recent ADR / code history. Ask for severity-ranked drift list.
5. **Print output.**

### Rubric (passed to the agent)

- Every file path mentioned in a doc exists.
- Every shell command referenced exists in `package.json` scripts.
- Every port number matches `Caddyfile` and `docker-compose*.yml`.
- Every stack component named is present in `package.json`
  dependencies (or its replacement is, with the original removed).
- Every ADR's decision either:
  - Reflects current code reality, OR
  - Is marked `Superseded by ADR-N`, with N existing and being a
    valid supersession.
- Every hook file name referenced (`auth_guard.pb.js`, etc.)
  exists in `backend/pb_hooks/`.

### Severity rules

- **Critical.** ADR decision contradicts current code with no
  supersession note. Doc references a nonexistent file or command.
- **Warning.** Wrong port number. Outdated stack-component name
  (e.g., calling Tailwind "Bulma"). Architectural assertion that's
  half-true.
- **Suggestion.** Missing supersession reference even when both
  ADRs are otherwise consistent. Cross-references between docs
  that have rotted.
- **Praise.** ADRs that are demonstrably current.

### Output format

Standard Findings sections. Each finding cites
`<doc>:<line>` and the contradicting evidence at `<file>:<line>`
or in `<package.json#scripts>`.

### Verify the skill works

1. Run `/audit-docs` on current state.
2. Confirm it flags ADR-002 (Bulma) — current `web/package.json`
   has `tailwindcss`, no Bulma.
3. Confirm it flags ADR-013 (persistence layer freeze) — the
   refactor is no longer frozen; the SvelteKit app is shipping.
4. If neither is flagged, the rubric is too lenient.

### Out of scope (copy verbatim into SKILL.md)

- Do not rewrite docs.
- Do not propose new ADRs.
- Do not assess prose quality, formatting, or tone.
- Do not touch `docs/archive/`.
- Do not analyze `frontend/`.

--------------------------------------------------------------------

## Skill 3: `/audit-domain`

### Goal

The TS domain layer at `web/src/lib/domain/` and any domain logic
embedded in routes follows the patterns codified in ADR-009
(prefer types over booleans; parse at boundary) and ADR-012
("one module per domain concept; pages talk only to domain
modules"), plus the implicit patterns visible in the existing
canonical modules.

### Boundary clarifier (read first)

This audit enforces FP discipline **inside `web/src/lib/domain/`**.
Component-level reactive state in `.svelte` files uses Svelte's
`$state` rune, which is built on Proxies and *expects* mutation
(`array.push(item)` is the intended update path). Do not flag
mutation inside `$state` as a domain anti-pattern — that is
idiomatic Svelte. Domain modules in `lib/` should remain
immutable and pure; routes should be thin adapters.

The Result shape (`{ ok: true, value } | { ok: false, error }`)
applies *inside* domain modules. At SvelteKit route boundaries,
follow the framework contract: `fail(400, { ... })` for
validation errors, `error(500, ...)` for server errors,
`redirect(303, ...)` for redirects. Do not return Result-shaped
unions from form actions.

### Why this exists

`/audit` covers line-level code quality. This skill covers
domain-modeling discipline: discriminated unions over boolean
flags, exhaustive switches, parse-once-at-boundary instead of
scattered validation, domain logic in `web/src/lib/domain/` rather
than in routes.

### Scope

**In scope.**
- `web/src/lib/domain/**/*.ts`
- `web/src/routes/**/+page.server.ts` and `+layout.server.ts` —
  audited for domain logic that should be extracted to
  `web/src/lib/domain/`.
- Validation logic anywhere in `web/src/`.

**Out of scope.**
- Schema, hooks, infrastructure (covered by other audits).
- Component styling.
- Branded types — this codebase chose not to use them. Do not
  recommend introducing them.
- Refactoring — the audit reports findings; the user opens issues.
- Style choices handled by Prettier.
- Algorithm correctness in PowerMatch / ElimBracket / etc. — that
  is the existing `/audit` skill's territory and is already
  covered by the algorithm-correctness rubric there. This audit
  focuses on *modeling*, not algorithmic logic.

### Files to create

```
.claude/skills/audit-domain/SKILL.md
.claude/skills/audit-domain/domain-checks.sh
```

### Reference material the implementer reads first

- `docs/decisions.md` — ADR-009 and ADR-012 in full. ADR-006
  ("flat module-per-concept") and ADR-010 ("PocketBase JS SDK as
  sole PB client") are also relevant.
- `web/src/lib/domain/standings.ts` — **canonical example** of
  the discriminated-union + exhaustive-switch pattern. Lines 38–88.
- `web/src/lib/domain/registration.ts` — **canonical example** of
  `as const` enum + Result-shaped union. Lines 5–55.
- `web/src/lib/domain/eligibleStudents.ts`,
  `web/src/lib/domain/trialClosure.ts`,
  `web/src/lib/domain/roundProgress.ts` — additional patterns.
- The full `web/src/lib/domain/` corpus.
- `web/src/routes/**/+page.server.ts` for any embedded domain
  logic.

### Steps the skill performs

1. **Run anti-pattern grep.** `domain-checks.sh` runs the rubric's
   greppable items across `web/src/lib/domain/` and
   `web/src/routes/`.
2. **Read ADRs and canonical examples.** Capture the patterns
   verbatim for the agent brief.
3. **List candidate files.** Every `.ts` in `web/src/lib/domain/`
   plus every `+page.server.ts` and `+layout.server.ts` in
   `web/src/routes/`.
4. **Brief Opus.** Send the grep output, the canonical examples,
   the ADR text, the candidate-file list (paths only, not full
   content — too much context for codebase-wide), and the rubric.
   Opus reads files as needed via its own tools.
5. **Print output.**

### Rubric (the anti-patterns to flag)

The agent looks for these. Each finding cites `file:line` and
quotes the anti-pattern.

1. **Boolean flags encoding state.** `isApproved: boolean`,
   `pending: boolean`, `wasReviewed: boolean` in domain types.
   Per ADR-009, replace with a discriminated union or `as const`
   enum (`status: 'pending' | 'approved' | 'rejected'`). Caveat:
   booleans for *true binary* concepts (`hasError`, `dirty`) are
   fine — flag only state-machine booleans.
2. **Non-exhaustive `switch` over a discriminated union or `as
   const` enum.** Every such switch should let TS prove
   exhaustiveness by covering every case. If a `default` exists,
   it must be a `never`-check. Either form is acceptable:
   ```ts
   // Inline
   default: {
     const _exhaustive: never = x;
     return _exhaustive;
   }

   // Or a shared helper (preferred for repeated use):
   // function assertNever(x: never): never {
   //   throw new Error(`Unhandled case: ${JSON.stringify(x)}`);
   // }
   default:
     return assertNever(x);
   ```
   Flag any default that is just `return null`, `return 0`, or
   `throw new Error("unreachable")` without the `never`
   parameter that gives TS the proof.
3. **Validation not parsed at boundary.** A function that takes
   raw shape and does `if (!x.foo) return {ok: false, ...}`
   followed by `if (!x.bar) ...` followed by `if (!x.baz) ...`
   should parse once at the boundary (typically Zod
   `safeParse` in a form action or at a domain-module entry
   point) into a refined type, then operate on the refined type.
   Once parsed, the type system carries the guarantee — no
   defensive re-checks downstream. Flag long validation cascades
   in domain modules. Flag any domain function that accepts
   `unknown` or a loose shape and does scattered field checks
   instead of parsing once at entry.
4. **Domain logic embedded in routes.** Any `+page.server.ts` or
   `+layout.server.ts` containing more than ~10 lines of
   business logic (state transitions, eligibility checks,
   computed status) that belongs in `web/src/lib/domain/`. Per
   ADR-012, pages talk only to domain modules.
5. **Mutation paths in `load()`.** SvelteKit's `load()` is
   read-only; mutations belong in form actions. Flag any `load()`
   that calls `pb.collection(...).create/update/delete`.
6. **Mutations via `+server.ts` when a form action would do.**
   SvelteKit's idiomatic mutation path is form actions
   (preserves progressive enhancement, framework contract for
   `fail` / `redirect` / `error`). `+server.ts` is for genuine
   APIs and non-form clients (webhook receivers, JS-only
   fetches). Flag any `+server.ts` route that handles a form
   POST that could be a form action.
7. **Result-shape inconsistency within a module's public API.**
   If two exports inside `web/src/lib/domain/` return Result-like
   unions, the shape should match. `{ ok: true, value: T } | {
   ok: false, error: string }` is the canonical shape. Mixing it
   with `{ ok: true, ...fields } | { ok: false, reason: string }`
   in the same module is a Warning. (Route boundaries are
   exempt — they use `fail` / `error` / `redirect`, not
   Result-shaped unions.)
8. **`enum` keyword.** Idiomatic TS prefers `as const` + derived
   type union (the pattern in `registration.ts`). `enum` has
   runtime baggage, doesn't tree-shake well, uses nominal typing
   that prevents substitution of structurally identical enums,
   and creates reverse mappings on numeric variants. Flag every
   `enum` in `web/src/lib/`.
9. **`any` or unjustified `as` casts inside
   `web/src/lib/domain/`.** The existing `/audit` flags these
   codebase-wide; this audit re-flags them here as Critical
   because the domain layer should be the cleanest tier.
10. **Return type `boolean` for state queries.** `isApproved(t)`
    that returns `boolean` is fine. `getStatus(t)` that returns
    `boolean` is wrong. Flag functions whose names imply
    multi-state but whose return type is `boolean`.
11. **Optional fields used as state markers.** A field `error?:
    string` where the presence of `error` indicates a failure
    state is a discriminated-union-in-disguise. Flag these — a
    proper union makes the states explicit.
12. **`$effect` writing derivable state.** Svelte's official docs
    name `$effect` an "escape hatch" for DOM, network, and
    analytics — not a routine reactivity tool. Any `$effect` that
    assigns to `$state` based on other reactive values should be
    `$derived`. Any `$effect` that runs once on mount should be
    `onMount`. Flag both. (This is a domain concern because
    `$effect`-as-state-machine is how state machines get modeled
    incorrectly in Svelte.)
13. **Top-level mutable `let` in server route files.** A `let` at
    module scope in `+page.server.ts`, `+layout.server.ts`, or
    `+server.ts` is per-process server state — leaks across
    users. Per-request state belongs in `event.locals`. Flag as
    Critical.

### Severity rules

- **Critical.** Any `any` / unjustified cast inside
  `web/src/lib/domain/`. Mutation in `load()`. State-machine
  boolean in a domain type that flows through more than one
  module. Top-level mutable `let` in `+page.server.ts` /
  `+layout.server.ts` / `+server.ts`.
- **Warning.** Non-exhaustive switch with non-`never` default.
  Domain logic in routes (>10 lines of business logic).
  Validation cascades not parsed at boundary. Result-shape
  inconsistency inside a domain module. `enum` keyword. `+server.ts`
  handling form POSTs that should be a form action. `$effect`
  writing derivable state. `$effect` for one-shot mount logic.
- **Suggestion.** Optional-field-as-state-marker. Single-module
  state-machine boolean. Local validation cascades that could be
  factored to a parse step.
- **Praise.** Modules that exemplify the canonical patterns
  (already true of `standings.ts` and `registration.ts`).

### Output format

Standard Findings sections.

### Verify the skill works

1. Run `/audit-domain` on current state. Confirm `standings.ts`
   and `registration.ts` appear in **Praise** (or at minimum, do
   not appear in Critical / Warning). Confirm mutation inside
   `$state` in any `.svelte` file is NOT flagged.
2. Temporarily insert into a domain type:
   `isApproved: boolean;` in a state-machine context. Re-run.
   Confirm it's flagged.
3. Temporarily change a `switch` to have a `default: return
   null;` instead of `never`-check. Re-run. Confirm flagged.
4. Temporarily add `let counter = 0;` at the top of a
   `+page.server.ts`. Re-run. Confirm flagged Critical.
5. Revert all temporary changes.

### Out of scope (copy verbatim into SKILL.md)

- Do not refactor.
- Do not propose major architectural changes.
- Do not flag style choices (Prettier handles formatting).
- Do not flag schema or PB-layer issues.
- Do not enforce branded types — this codebase chose not to use
  them.
- Do not flag algorithmic correctness in PowerMatch /
  ElimBracket / Standings — that is the existing `/audit` skill's
  job.

--------------------------------------------------------------------

## Skill 4: `/audit-a11y`

### Goal

Critical user flows (`/login`, `/register`, `/team`, `/admin`)
meet WCAG 2.2 AA — semantic HTML, keyboard navigation, contrast,
screen-reader labels. First run produces a baseline. Subsequent
runs detect regressions.

### Why this exists

The site is public-facing. Coaches, students, and the public use
it; some will use screen readers, keyboard-only navigation, or
high-contrast mode. Retrofitting accessibility across all routes
once the SvelteKit port stabilizes will cost more than fixing it
per-route now. This audit pins the floor.

### Scope

**In scope.**
- `web/src/routes/login/**`
- `web/src/routes/register/**` (including
  `register/teacher-coach`, `register/pending`)
- `web/src/routes/team/**`
- `web/src/routes/admin/**` (including
  `admin/{districts,registrations,schools,superusers,teams,tournaments}`)
- Components reused across these routes (in
  `web/src/lib/components/`)
- shadcn-svelte components as integrated (do not audit upstream
  shadcn itself)

**Out of scope.**
- Visual design choices (colors, layouts, typography) beyond
  contrast.
- Route prose / content choices.
- Marketing site content (if any exists outside the listed routes).
- WCAG AAA — AA is the bar.
- `/demo` route (test fixture, not user-facing).

### Files to create

```
.claude/skills/audit-a11y/SKILL.md
.claude/skills/audit-a11y/a11y-grep.sh
web/playwright.a11y.config.ts
web/e2e/a11y-flows.e2e.ts
```

The Playwright config and spec are part of the skill's required
toolkit. The skill drives them; they don't run on every PR (yet —
that's a future CI decision).

### Required tooling install (one-time, the implementer does this)

```bash
cd web && npm install --save-dev @axe-core/playwright axe-core
```

Note in the SKILL.md that the install is required and recorded
in `web/package.json` after the skill ships.

### Reference material the implementer reads first

- Svelte a11y warnings reference:
  https://svelte.dev/docs/svelte/accessibility-warnings
- `@axe-core/playwright` README:
  https://www.npmjs.com/package/@axe-core/playwright
- WCAG 2.2 AA quick reference:
  https://www.w3.org/WAI/WCAG22/quickref/?versions=2.2&levels=aa
- The four target route trees end-to-end.
- `web/src/lib/components/` — every reused component.
- `web/playwright.config.ts` and `web/playwright.deploy.config.ts`
  — existing patterns to mirror.

### Steps the skill performs

1. **Run grep checks** (`a11y-grep.sh`) for the static
   anti-patterns listed below.
2. **Run `cd web && npm run check`** — capture svelte-check's
   built-in a11y warnings.
3. **Run axe via Playwright over the four flows.** The spec
   navigates through:
   - `/login` (logged out)
   - `/register`
   - `/register/teacher-coach`
   - `/register/pending`
   - `/team` (as approved coach — use the staging seed account
     via env vars, same pattern as `test:smoke:staging`)
   - `/admin`, `/admin/teams`, `/admin/tournaments` (as
     superuser)
   For each page, run `AxeBuilder().analyze()` and capture
   violations.
4. **Read svelte-check output and axe results.**
5. **Brief Opus** with the grep output, svelte-check warnings,
   axe violations, and the rubric. Ask for severity-ranked
   findings plus a per-route violation table.
6. **Print output.**

### Anti-pattern grep rubric (`a11y-grep.sh`)

- `<div onclick=` or `<span onclick=` in `.svelte` files — use
  `<button>`.
- `<a href="javascript:` — broken; use `<button>`.
- `<a>` without `href` attribute.
- `<img>` without `alt` attribute.
- `<img alt="">` — flag for review (only valid if truly
  decorative; usually a missed alt).
- `<input>` without an associated `<label>` (no `for` matching
  `id`, no wrapping label).
- Form `<input>` without a `name` attribute.
- Custom interactive elements (`role="button"` on a div) without
  both `tabindex="0"` and a keyboard handler (`onkeydown` /
  `onkeypress`).

Header-level skipping (h1 → h3 with no h2) is harder to grep
reliably; let Opus catch it from the file content.

### Color / contrast / dynamic checks (delegated to axe)

Axe handles:
- Color contrast against WCAG 2.2 AA thresholds.
- ARIA validity.
- Focus management.
- Landmark structure.

Do not duplicate these in grep — axe is more accurate.

### Severity rules

- **Critical.** Axe `critical` or `serious` violations. Form
  inputs with no labels at all. Missing `<main>` landmark.
  Keyboard traps.
- **Warning.** Axe `moderate` violations. Skipped heading levels.
  Missing `alt` on `<img>`. `role="button"` on a div without
  keyboard handler.
- **Suggestion.** Axe `minor` violations. `<img alt="">` that
  may be intentional but warrants review. Use of `title`
  attribute as the only label.
- **Praise.** Routes that pass axe with zero violations.

### Output format

Standard Findings sections, then:

```
### Per-route violation counts

| route                        | critical | serious | moderate | minor |
| ---------------------------- | -------- | ------- | -------- | ----- |
| /login                       | 0        | 1       | 2        | 0     |
| /register                    | ...      | ...     | ...      | ...   |
| /register/teacher-coach      | ...      |         |          |       |
| /register/pending            | ...      |         |          |       |
| /team                        | ...      |         |          |       |
| /admin                       | ...      |         |          |       |
| /admin/teams                 | ...      |         |          |       |
| /admin/tournaments           | ...      |         |          |       |
```

### Baseline behavior

The first run produces a wall of findings. That is expected.
Save the run output as `docs/a11y-baseline-YYYY-MM-DD.md`
(manual step the implementer notes in the SKILL.md). Future
runs compare against the latest baseline and highlight any
*increase* in violation counts as additional Warnings, even
when the underlying issue existed before.

### Verify the skill works

1. Run `/audit-a11y` on current state. Confirm output renders
   the per-route table and that axe ran successfully.
2. Insert a deliberate violation: `<img>` without `alt` in a
   target route. Re-run. Confirm flagged.
3. Revert.

### Out of scope (copy verbatim into SKILL.md)

- Do not redesign the UI.
- Do not change visual styling, colors, or layout choices.
- Do not flag prose tone or content.
- Do not enforce WCAG AAA.
- Do not audit the `/demo` route.
- Do not audit `frontend/` (legacy Elm).

--------------------------------------------------------------------

## Skill 5: `/audit-deps`

### Goal

Surface security-relevant dependency state and pin compliance.
`npm audit` findings, major-version drift, unpinned GHA actions,
unpinned Docker base images, unverified binary downloads.

### Why this exists

Hardening compounds. A floating `actions/checkout@v4` works until
the maintainer is compromised; a floating `FROM node:20` works
until a tag gets republished. The existing audit (Task 6 of
2026-04-26) pinned the PocketBase binary; nothing checks that the
pin is still in place or that other binaries have followed suit.

### Scope

**In scope.**
- Root `package.json`.
- `web/package.json`.
- `.github/workflows/*.yml` — GHA action pin compliance.
- `backend/Dockerfile`, `backend/Dockerfile.dev` — base image
  pins, binary download verification.
- Any `Dockerfile*` elsewhere in the repo.

**Out of scope.**
- Recommending swapping libraries (e.g., "use Effect-TS instead
  of native promises").
- Bundle size analysis.
- Performance.
- License auditing (separate concern; out of scope for this
  audit).
- Running `npm update` or making any change.

### Files to create

```
.claude/skills/audit-deps/SKILL.md
.claude/skills/audit-deps/deps-checks.sh
```

### Reference material the implementer reads first

- Root `package.json` and `web/package.json`.
- `.github/workflows/*.yml`.
- `backend/Dockerfile`, `backend/Dockerfile.dev`.
- The 2026-04-26 plan's Task 6 — pattern for SHA-pinned binary
  download with `sha256sum -c`.

### Steps the skill performs

1. **`npm audit --json`** at root and at `web/`. Capture all
   findings at moderate or higher.
2. **`npm outdated --json`** at root and at `web/`. Capture
   major-version drift.
3. **GHA action pin scan.** Grep `.github/workflows/*.yml` for
   `uses:` lines. Flag any without a version specifier.
   Distinguish:
   - `uses: actions/checkout` (no version) → Critical
   - `uses: actions/checkout@master` or `@main` → Critical
   - `uses: actions/checkout@v4` (floating major) → Warning
   - `uses: actions/checkout@v4.1.7` (specific minor) → OK
   - `uses: actions/checkout@<40-char-sha>` → Best
4. **Dockerfile base image scan.** Grep `FROM` lines. Flag:
   - `FROM image:latest` → Critical
   - `FROM image` (no tag) → Critical
   - `FROM image:20` (floating major) → Warning
   - `FROM image:20.11.0` → OK
   - `FROM image:20.11.0@sha256:...` → Best
5. **Binary download scan.** Grep `curl`, `wget`, `RUN sh -c`
   in Dockerfiles. Flag any download that is not followed by a
   `sha256sum -c` verification. Confirm Task 6's PocketBase pin
   is still in place.
6. **Brief Opus** with all findings.
7. **Print output.**

### Severity rules

- **Critical.** Any `npm audit` finding at high or critical.
  Unpinned or `latest`-tagged Dockerfile base image. Binary
  download without checksum. GHA action with no version, `@master`,
  or `@main`.
- **Warning.** Any `npm audit` finding at moderate. Major-version
  drift on a production dependency. Floating major (`@v4`) on GHA.
  Floating major on Dockerfile (`FROM node:20`).
- **Suggestion.** Minor / patch drift. SHA-pinning GHA actions
  beyond version tags (best practice but not always practical).
- **Praise.** Workflows fully SHA-pinned. Dockerfiles with
  pinned base + verified downloads.

### Output format

Standard Findings sections, then:

```
### Outdated packages

| location | package | current | wanted | latest | severity |
| -------- | ------- | ------- | ------ | ------ | -------- |
| root     | ...     | 1.2.3   | 1.2.4  | 2.0.0  | warning  |

### npm audit summary

| location | critical | high | moderate | low |
| -------- | -------- | ---- | -------- | --- |
| root     | 0        | 0    | 0        | 1   |
| web/     | 0        | 0    | 1        | 3   |
```

### Verify the skill works

1. Run `/audit-deps` on current state. Confirm tables render and
   the PocketBase SHA pin is still in `backend/Dockerfile`.
2. Temporarily change a GHA action to `actions/checkout@master`
   in a workflow. Re-run. Confirm flagged Critical.
3. Revert.

### Out of scope (copy verbatim into SKILL.md)

- Do not run `npm update`, `npm audit fix`, or modify any
  `package.json`.
- Do not recommend swapping libraries.
- Do not opine on bundle size, build time, or performance.
- Do not audit licenses.
- Do not modify Dockerfiles or workflows — only report.

--------------------------------------------------------------------

## After all five skills are built

1. Update `CLAUDE.md` with a short "Audits" subsection listing
   the new skills and what each covers.
2. Bump `CHANGELOG.md` for each PR (one PR per skill, per
   the project's tagging policy).
3. Open follow-up issues for each Critical / Warning finding the
   first runs surface. One issue per finding. One PR per issue.
4. Optionally: schedule periodic runs via the `/schedule` or
   `/loop` skills (e.g., `/audit-schema` monthly, `/audit-docs`
   quarterly, `/audit-deps` monthly). Decide cadence after the
   first runs surface real signal-to-noise.

## Follow-up: update existing `/audit` for Svelte 5

The existing `.claude/skills/audit/` skill was written when Svelte
5 was newer. Its rubric should absorb a few patterns that current
research identifies as common AI-generated mistakes. Open as a
separate PR after the five new skills ship. Add to
`audit-checks.sh` and to the SKILL.md rubric:

- **Stores in Svelte 5 components.** Flag `writable` / `readable`
  imports inside `.svelte` files. In Svelte 5, stores are reserved
  for async streams; component state belongs in `$state`. Allowed
  inside `.svelte.ts` modules.
- **`.svelte.ts` shared state without getter object.** Svelte
  forbids exporting a re-assignable `$state` variable from a
  module. The idiom is to export an object literal with a getter
  (`{ get count() { ... }, increment() { ... } }`). Flag exports
  of bare `$state` variables in `.svelte.ts` files.
- **`$effect` writing derivable state.** Same anti-pattern listed
  in `/audit-domain` rubric item 12 — also worth flagging at the
  line-quality level. (Safe to flag in both audits; signal is
  reinforced.)
- **Svelte 4 legacy syntax bans.** The existing rubric covers
  `let foo = ...` and `$:`. Add `export let`, `<slot>`,
  `<svelte:fragment>`, `<svelte:component>`, `<svelte:self>`,
  `$$props`, `$$restProps`, `on:click=`, and event modifiers
  (`|preventDefault`, `|stopPropagation`, etc.). All have rune-era
  replacements.
- **`+server.ts` for form POSTs.** Flag `+server.ts` handlers that
  accept `application/x-www-form-urlencoded` or
  `multipart/form-data` and don't have a corresponding API
  consumer. Form actions are the SvelteKit idiom.

Keep this section in this doc rather than splitting it out — the
existing `/audit` already exists, the brief is for the new skills,
and the implementer of the side PR can read this once at the end.

## Notes for the implementer

- This brief assumes the workflow rules from the 2026-04-26 audit:
  worktree per skill, branch `feat/audit-<name>`, TDD where it
  applies (e.g., the schema-completeness helper has testable
  parsing logic), one PR per skill.
- If a step feels wrong when you reach it, **stop and ask** the
  user rather than improvise. The user has explicitly traded
  speed for correctness.
- Read the live code before writing the agent brief for each
  skill. State will have drifted between this document being
  written and the skill being built.
- The agent prompts must be self-contained — no references to
  this brief or to any prior conversation.
- Each skill ends with a verification step that demonstrably
  fails on a deliberate violation and passes when reverted. Run
  it before opening the PR; paste the output in the PR body.
