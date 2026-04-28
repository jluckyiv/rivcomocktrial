---
name: audit-domain
description: Domain modeling audit — verifies web/src/lib/domain/ and routes follow ADR-009 (discriminated unions, parse-at-boundary) and ADR-012 (pages talk only to domain modules). Run on demand and before milestone tags.
---

# audit-domain

Audit the TypeScript domain layer at `web/src/lib/domain/` and the
route server files at `web/src/routes/` for domain-modeling discipline:
discriminated unions over boolean flags, exhaustive switches,
parse-once-at-boundary, and domain logic in `lib/domain/` rather than
in routes.

Different from `/audit` (code quality) and `/pr-review` (pre-merge
sanity). This skill answers: "is the domain layer drifting from its
codified patterns?"

Only run inside `~/Code/github` or `~/Code/playground`. Refuse if the
working directory is outside those paths (e.g. Vault, dotfiles).

## Boundary note

This audit enforces FP discipline **inside `web/src/lib/domain/`**.
Mutation inside `$state` in `.svelte` files is idiomatic Svelte —
**do not flag it**. The `$state` rune is built on Proxies and expects
`array.push(item)` as the update path. Domain modules in `lib/` should
remain immutable and pure; routes should be thin adapters.

The Result shape (`{ ok: true, value } | { ok: false, error }`) applies
inside domain modules. At SvelteKit route boundaries, `fail()` /
`error()` / `redirect()` are the framework contract — do not return
Result-shaped unions from form actions.

## Steps

### 1. Run the domain checks script

```bash
.claude/skills/audit-domain/domain-checks.sh
```

Capture the full output. It greps `web/src/lib/domain/` and
`web/src/routes/` for the anti-patterns from the rubric.

### 2. Read ADRs and canonical examples

Read the following verbatim:

- `docs/decisions.md` — ADR-009 ("Parse, don't validate") and ADR-012
  ("one module per domain concept; pages talk only to domain modules")
  in full. Skim ADR-006 and ADR-010 for supplementary context.
- `web/src/lib/domain/standings.ts` (lines 38–88) — canonical
  discriminated-union + exhaustive-switch pattern.
- `web/src/lib/domain/registration.ts` (lines 1–80) — canonical
  `as const` enum + Result-shaped union.

### 3. List candidate files

Run:

```bash
# Domain modules
find web/src/lib/domain -name '*.ts' -not -name '*.test.ts' | sort

# Route server files
find web/src/routes -name '+page.server.ts' -o -name '+layout.server.ts' \
  -o -name '+server.ts' | sort
```

These are the candidate files for the agent. Pass paths only — do not
pass full content (too much context). The agent reads files as needed.

### 4. Brief Opus

Call `Agent` with `subagent_type: "general-purpose"` and
`model: "opus"`.

The prompt must be self-contained. Include:

- The full output from `domain-checks.sh` (step 1)
- The full content of `standings.ts` (the canonical example)
- The full content of `registration.ts` (the canonical example)
- The full ADR-009 and ADR-012 text from `docs/decisions.md`
- The candidate file list (paths only — step 3)
- The rubric below (verbatim)
- The severity rules (verbatim)
- The boundary note (verbatim, especially the `$state` and route-boundary
  exemptions)
- The out-of-scope list (verbatim)

Instruct the agent to:

1. Read each candidate domain module and route server file using its
   tools.
2. For each file, apply the rubric. Cite `file:line` for every finding.
3. Return severity-ranked Findings in the standard format.

### 5. Print output

Relay the agent's output verbatim.

---

## Rubric (pass verbatim to agent)

Check each candidate file for these anti-patterns. Each finding cites
`file:line` and quotes the anti-pattern.

1. **Boolean flags encoding state.** `: boolean` in domain type
   definitions for state-machine fields (`isApproved`, `pending`,
   `wasReviewed`). Per ADR-009, use a discriminated union or `as const`
   enum. Exception: true-binary booleans (`hasError`, `dirty`) are fine.

2. **Non-exhaustive `switch` over a discriminated union or `as const`
   enum.** A `default:` that does not narrow to `never` is the
   anti-pattern. Both of these forms are acceptable:
   ```ts
   // Inline never-check
   default: {
     const _exhaustive: never = x;
     return _exhaustive;
   }
   // Named helper
   default:
     return assertNever(x);
   ```
   Flag any `default:` in a domain switch that is just `return null`,
   `return 0`, `break`, or `throw new Error("unreachable")` without the
   `never` parameter.

3. **Validation not parsed at boundary.** A function that accepts a raw
   shape and runs multiple sequential `if (!x.foo)` / `if (!x.bar)`
   checks should instead parse once at the entry point into a refined
   type. Flag long validation cascades (4+ sequential field checks) in
   domain modules. Flag any domain function accepting `unknown` or a
   loose shape with scattered checks instead of a single parse step.

4. **Domain logic embedded in routes.** Any `+page.server.ts` or
   `+layout.server.ts` containing more than ~10 lines of business logic
   (state transitions, eligibility checks, computed status) that belongs
   in `web/src/lib/domain/`. Per ADR-012, pages talk only to domain
   modules.

5. **Mutation in `load()`.** SvelteKit's `load()` is read-only;
   mutations belong in form actions. Flag any `load()` that calls
   `pb.collection(...).create(`, `.update(`, or `.delete(`.

6. **`+server.ts` for form POSTs.** Any `+server.ts` route that handles
   a form POST that could be a form action. (No `+server.ts` files
   currently exist — flag any that are added.)

7. **Result-shape inconsistency within a module.** If a module exports
   multiple Result-like functions, they must share the same shape:
   `{ ok: true; value: T } | { ok: false; error: string }`. Mixing
   `error` with `reason` or `message` within the same module is a
   Warning. (Route boundaries exempt — `fail` / `error` / `redirect`
   there, not Result unions.)

8. **`enum` keyword.** The codebase uses `as const` + derived type
   union (see `registration.ts`). The `enum` keyword has runtime
   baggage, doesn't tree-shake, uses nominal typing, and creates reverse
   mappings on numeric variants. Flag every `enum` in `web/src/lib/`.

9. **`any` or unjustified `as` casts inside `web/src/lib/domain/`.**
   The domain layer must be the cleanest tier. `: any`, `as any`, and
   unexplained `as <Type>` casts are Critical here.

10. **Return type `boolean` for state queries.** A function whose name
    implies multi-state (`getStatus`, `computeResult`, `resolveKind`)
    but returns `boolean` should return a discriminated union. Functions
    clearly named `isX` returning `boolean` are fine.

11. **Optional fields used as state markers.** `error?: string` in a
    type where the presence of `error` signals a failure state is a
    discriminated-union-in-disguise. A proper discriminated union makes
    the states explicit and prevents accessing `error` in the happy path.

12. **`$effect` writing derivable state.** Any `$effect` in a route
    component (`.svelte` file) that assigns to `$state` based on other
    reactive values should be `$derived`. Any `$effect` that runs once
    on mount should be `onMount`. Flag both. (Do NOT flag `$state`
    mutation inside `$state` callbacks — that is idiomatic Svelte.)

13. **Top-level mutable `let` in server route files.** A `let` at
    module scope in `+page.server.ts`, `+layout.server.ts`, or
    `+server.ts` is per-process state that leaks across users. Per-
    request state belongs in `event.locals`. Flag as Critical.

## Severity rules (pass verbatim to agent)

- **Critical.** `any` or unjustified cast inside `web/src/lib/domain/`.
  Mutation in `load()`. State-machine boolean in a domain type that
  flows through more than one module. Top-level mutable `let` in
  `+page.server.ts` / `+layout.server.ts` / `+server.ts`.
- **Warning.** Non-exhaustive switch with non-`never` default. Domain
  logic in routes (>10 lines business logic). Validation cascade not
  parsed at boundary. Result-shape inconsistency within a domain module.
  `enum` keyword. `+server.ts` handling form POSTs. `$effect` writing
  derivable state. `$effect` for one-shot mount logic.
- **Suggestion.** Optional-field-as-state-marker. Single-module
  state-machine boolean. Local validation cascade that could be
  factored to a parse step. `as` cast in domain that looks justified
  but lacks a comment.
- **Praise.** Modules that exemplify the canonical patterns (start
  with `standings.ts` and `registration.ts` as the baseline).

## Output format

```
## Findings

### Critical
### Warnings
### Suggestions
### Praise
```

Each finding: what, where (`file:line`), why it matters. 2–3 lines
max. Empty sections: "None."

## Out of scope

- Do not refactor.
- Do not propose major architectural changes.
- Do not flag style choices (Prettier handles formatting).
- Do not flag schema or PocketBase-layer issues.
- Do not enforce branded types — this codebase chose not to use them.
- Do not flag algorithmic correctness in PowerMatch / ElimBracket /
  Standings — that is the existing `/audit` skill's job.
