---
name: audit
description: Codebase audit for the rivcomocktrial SvelteKit + PocketBase stack. PR-scoped or codebase-wide. Runs lint + targeted grep checks, then briefs a fresh Opus subagent for a clean second opinion. Use for "audit the codebase", "audit PR #N", or before milestone tags.
---

# audit

Audit `web/` (SvelteKit + TypeScript) and `backend/pb_hooks/`
(PocketBase JS hooks) against project conventions. Run lint, grep
for known anti-patterns, then brief a fresh Opus subagent — no
conversation context, clean second opinion.

Different from `/pr-review`: that one is interactive and produces
a verdict in the chat. `/audit` produces a structured findings
report from a fresh agent. Use both when a PR is risky.

Only run inside `~/Code/github` or `~/Code/playground`. Refuse if
the working directory is outside those paths (e.g. Vault,
dotfiles).

## Argument

Optional: PR number, branch, file path, or omitted.

- PR number → `gh pr diff <N> --name-only`
- Branch → `git diff main...<branch> --name-only`
- File path → audit that file directly
- Omitted → codebase-wide pass

## Steps

### 1. Collect scope

Resolve the argument to a list of files. For codebase-wide,
target everything under `web/src/` and `backend/pb_hooks/`.

### 2. Run lint and type checks

From the repo root (or `cd web` if needed):

```bash
cd web && npm run check 2>&1   # svelte-check + tsc --noEmit
cd web && npm run lint 2>&1    # ESLint
```

Collect output for the agent brief. If a script is missing, note
"not configured" and continue.

### 3. Run targeted grep checks

```bash
.claude/skills/audit/audit-checks.sh
```

The script auto-detects scope from `package.json`. Collect output
for the agent brief.

What each section flags (for agent context):

**SvelteKit / TS**
- **Svelte 4 reactive state** — `let foo = ...` declarations in
  `.svelte` files reassigned later; should be `$state(...)`
- **Svelte 4 derived** — `$:` blocks; should be `$derived(...)`
- **`any` annotations** — `: any` and `as any`; the codebase
  rejects `any` in favor of `unknown` + narrowing
- **Unjustified `as` casts** — `as <Type>` without a nearby
  comment explaining why
- **Client-side localStorage with auth-shaped keys** — auth
  belongs in httpOnly cookies via `hooks.server.ts`, not
  localStorage
- **Direct `new PocketBase(`** — outside `hooks.server.ts` and
  test code, instances should be obtained from `event.locals.pb`

**PocketBase pb_hooks**
- **Filter string concatenation** — injection risk; use `{:param}`
  syntax with `findRecordsByFilter` / `findFirstRecordByFilter`
- **PK lookups via filter** — use `findRecordById` instead
- **`$app.save` calls** — each post-commit side effect needs
  try/catch
- **Top-level `const` referenced from callbacks** — PB v0.36 JSVM
  runs callbacks in a fresh VM; constants must be loaded via
  `require()` at trigger time (pattern in
  `backend/pb_hooks/_constants.js`)
- **switch/case without default** — every switch needs a default
  branch

**General**
- `console.log` left as permanent debugging
- Silent `catch {}` blocks that swallow errors

### 4. Read reference material

Before briefing the agent, read:

- `docs/decisions.md` — skim active ADRs (respect "superseded by"
  notes; don't cite old numbers)
- `docs/competition-workflow.md` — workflow context for any
  domain-touching change
- Project memory at
  `/Users/jluckyiv/.claude/projects/-Users-jluckyiv-Code-github-jluckyiv-rivcomocktrial/memory/`
  — `MEMORY.md` for the index, then `pocketbase-patterns.md`,
  `feedback_js_conventions.md` (pruned post-rebuild), and
  `auth-roles.md` for relevant context.

### 5. Launch Opus audit agent

Call `Agent` with `subagent_type: "general-purpose"` and
`model: "opus"`.

The prompt must be self-contained. Include:

- For PR/branch: the full content of every changed file in scope
  (Svelte, TS, JS hooks, migrations).
- For codebase-wide: the grep output only — do NOT pass all source
  files (too much context).
- Full content of the reference material from step 4.
- The lint output from step 2.
- The grep findings from step 3.
- What changed and why (commit message, PR title, or "codebase
  audit").

### 6. Review criteria to pass to the agent

**SvelteKit / TS**
- Svelte 5 runes only — no `let foo = ...` reactive state, no
  `$:`, no stores when `$state` in a module would work?
- `any` rejected — `unknown` + type guards used to narrow?
- `as` casts only at true boundaries with justification?
- Server vs client boundaries respected — `.server.ts` for
  server-only, shared in `.ts` and `.svelte`?
- Data via `+page.server.ts` `load()`; mutations via form actions?
- Auth via `event.locals.pb` (cookie-restored) — NOT
  `localStorage` tokens, NOT dual SDK instances?
- shadcn-svelte primitives used where they fit, instead of raw
  Tailwind components?

**Domain modeling (the "no heavy modeling" stance)**
- Plain functions and records — NOT opaque smart constructors,
  branded ID types, `neverthrow`/Result libraries (unless
  something concrete demands it)?
- Result-shaped returns (`{ ok: true, value } | { ok: false,
  error }`), thrown errors, or `null`/`undefined` returns —
  whichever is idiomatic for the case?

**Algorithm correctness** (only flag if the relevant module is in
scope)
- **PowerMatch:** every team paired exactly once; no rematches
  (backtracking when greedy fails); side-switching round-to-round;
  no team plays the same side 3+ times.
- **Standings:** wins → cumulative % → point differential →
  head-to-head; input order preserved on full ties.
- **ElimBracket:** exactly 8 teams; pairings 1v8/2v7/3v6/4v5.
- **ElimSideRules:** first elim meeting flips most recent prelim
  side; rematch flips prior side; third meeting → error.
- **BallotAssembly:** Pretrial/Closing weight ×2; ClerkPerformance
  always Prosecution; BailiffPerformance always Defense; points
  1–10; corrections preserve original.
- **EligibleStudents:** Draft → Submitted → Locked one-way; 8–25
  default; reject duplicates.
- **RoundProgress / TrialClosure:** state machines respected.

**pb_hooks (PocketBase v0.36.x)**
- Parameterized filters (`{:param}`) — no string concatenation?
- `findRecordById` for PK lookups (not `findRecordsByFilter`)?
- Every `$app.save` post-commit side effect wrapped in try/catch
  with log?
- Hooks scoped correctly (right collections / events)?
- No top-level `const` referenced from callbacks (use `require()`
  of `_constants.js` at trigger time)?
- Migrations have correct timestamp prefix sequence?

**General**
- No `console.log` left as permanent debugging?
- No silent `catch {}` blocks?
- CHANGELOG updated for the change?

### 7. Output format

Ask the agent to return:

```
## Findings

### Critical
### Warnings
### Suggestions
### Praise
```

Each finding: what, where (`file:line`), why it matters. 2–3
lines max. Empty sections: "None."
