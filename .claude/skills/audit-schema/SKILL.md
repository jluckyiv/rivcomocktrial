---
name: audit-schema
description: PocketBase schema lockdown audit — verifies every collection in pocketbase-types.ts has a spec, every spec matches live rule strings on the test PB, and coverage is complete. Run on demand and pre-tag.
---

# audit-schema

Audit every PocketBase collection's rule lockdown: completeness of spec
coverage and accuracy of assertions against the live test PB. Produces a
coverage matrix and severity-ranked findings.

Different from `/audit` (code quality) and `/security-review` (branch
security). This skill answers: "is the lockdown still complete and accurate?"

Only run inside `~/Code/github` or `~/Code/playground`. Refuse if the
working directory is outside those paths (e.g. Vault, dotfiles).

## Steps

### 1. Boot the test PB

```bash
npm run pb:test:up
```

Wait for health:

```bash
curl -sf http://localhost:28090/api/health
```

If already running, continue. This step is non-destructive — `pb:test:up`
is idempotent.

### 2. Run the completeness script

```bash
.claude/skills/audit-schema/schema-completeness.sh
```

Capture the full output. It:
- Enumerates every collection from `web/src/lib/pocketbase-types.ts`
- Fetches live `listRule`, `viewRule`, `createRule`, `updateRule`, `deleteRule`
  from the test PB at port 28090 using credentials from `.env.test`
- Lists every `.spec.ts` file in `web/src/lib/schema/`
- Greps each spec for `getCollection()` calls and rule assertions
- Reports collections with no spec coverage
- Flags any `it.skip` entries

### 3. Read the canonical spec pattern

Read `web/src/lib/schema/coach-access.spec.ts` in full. This is the
reference for what a correct assertion looks like:
- `getCollection('<name>')` in `beforeAll`
- One `it()` per rule slot (5 total: list, view, create, update, delete)
- `toBe('<string>')` for non-null rules; `toBeNull()` for admin-only rules

### 4. Brief Opus

Call `Agent` with `subagent_type: "general-purpose"` and `model: "opus"`.

The prompt must be self-contained. Include:

- The full output from `schema-completeness.sh` (step 2)
- The content of `web/src/lib/schema/coach-access.spec.ts` (canonical pattern)
- The rubric below (verbatim)
- The severity rules (verbatim)
- The out-of-scope list (verbatim)

Instruct the agent to:
1. Parse the live rule strings from the script output
2. Parse the spec assertions from the script output
3. For each collection × rule slot, determine the cell status:
   - `match` — spec asserts the live value (toBe matches, or toBeNull for null)
   - `mismatch` — spec asserts a different value
   - `unasserted` — no spec test for this slot
   - `skipped` — `it.skip` for this slot
4. Produce severity-ranked Findings (Critical / Warnings / Suggestions / Praise)
5. Produce the coverage matrix table

### 5. Print output

Relay the agent's output verbatim.

---

## Rubric (pass verbatim to agent)

- Every collection in `pocketbase-types.ts` has a spec file covering it.
  One spec file may cover several related collections (group by domain,
  e.g. `ballots.spec.ts` covers all ballot collections).
- Every spec asserts all 5 rule slots per collection (`listRule`,
  `viewRule`, `createRule`, `updateRule`, `deleteRule`).
- Every assertion is a strict-equality (`toBe()`) match against the live
  rule string. `null` rules use `toBeNull()`.
- Asymmetric coverage (e.g. `viewRule` asserted but `updateRule`
  unasserted) is a Warning even when the unasserted rule is `null`
  (superusers only) — explicit assertion is the lockdown.
- `it.skip` entries are flagged. Each must have a comment linking to a
  tracking issue. A skipped test without a comment is Critical.

## Severity rules (pass verbatim to agent)

- **Critical.** A live rule does not match the asserted string (drift
  detected). A skipped test with no issue link.
- **Warning.** A collection has zero coverage. Asymmetric coverage (some
  rule slots asserted, others not).
- **Suggestion.** Spec organization (consolidating files, deduplicating
  helpers).
- **Praise.** Collections with full 5-rule lockdown matching live.

## Output format

```
## Findings

### Critical
### Warnings
### Suggestions
### Praise

### Coverage matrix

| collection | list | view | create | update | delete |
| ---------- | ---- | ---- | ------ | ------ | ------ |
| users      | ✓    | ✓    | ✓      | ✓      | ✓      |
| ...        |      |      |        |        |        |

Legend: ✓ = matches live | ✗ = mismatch | - = unasserted | s = skipped
```

Each finding: what, where (`file:line` where applicable), why it
matters. 2–3 lines max. Empty sections: "None."

## Out of scope

- Do not propose rule *changes*.
- Do not author missing specs (only identify them).
- Do not migrate collections.
- Do not comment on hook behavior, domain logic, or UI.
