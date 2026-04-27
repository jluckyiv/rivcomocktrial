---
name: audit-docs
description: Documentation drift audit — verifies every load-bearing claim in CLAUDE.md, README.md, docs/decisions.md (ADRs), and docs/*.md matches code reality. Run on demand and quarterly. Pre-tag.
---

# audit-docs

Audit every load-bearing claim in `CLAUDE.md`, `README.md`,
`docs/decisions.md`, and other `docs/*.md` files against code
reality. Surfaces stale ADRs, wrong file paths, wrong port numbers,
and outdated stack names.

Different from `/audit` (code quality) and `/security-review` (branch
security). This skill answers: "do the docs still match the code?"

Only run inside `~/Code/github` or `~/Code/playground`. Refuse if the
working directory is outside those paths (e.g. Vault, dotfiles).

## Steps

### 1. Run the claims extraction script

```bash
.claude/skills/audit-docs/docs-claims.sh
```

Capture the full output. It:

- Enumerates all `docs/*.md` files (excluding `docs/archive/`)
- Extracts file path references, shell command references, port
  numbers, stack component names, and hook file name references
- Cross-checks each claim against the filesystem and config files
- Reports mismatches

### 2. Read each doc in scope

Read these files in full:

- `CLAUDE.md`
- `README.md`
- `docs/decisions.md`
- `docs/competition-workflow.md`
- `docs/backups.md`
- `docs/pocketbase-jsvm.md`
- `docs/power-matching-analysis.md`
- `docs/smoke-tests.md`
- Any additional `docs/*.md` not in `docs/archive/`

### 3. Read the verifying sources

Read these files to verify claims:

- Root `package.json` — script names, devDependencies
- `web/package.json` — stack component names, script names
- `backend/Caddyfile` — port numbers, proxy routing
- `docker-compose.yml` — port numbers, service config
- `docker-compose.test.yml` — test port numbers
- Directory listing of `backend/pb_hooks/` — hook file names
- Directory listing of `backend/pb_migrations/` (latest 5) — recent
  schema changes that may contradict ADR decisions

### 4. Check ADR change history

For each ADR that looks potentially stale, run:

```bash
git log --oneline --follow docs/decisions.md | head -20
```

to see when it was last updated, and cross-reference with code changes
that contradict the decision text.

### 5. Brief Opus

Call `Agent` with `subagent_type: "general-purpose"` and
`model: "opus"`.

The prompt must be self-contained. Include:

- The full output from `docs-claims.sh` (step 1)
- The full content of every doc in scope (step 2)
- The full content of the verifying sources (step 3)
- The ADR git log output (step 4)
- The rubric below (verbatim)
- The severity rules (verbatim)
- The out-of-scope list (verbatim)

Instruct the agent to:

1. For each load-bearing claim in each doc, determine whether it
   matches code reality.
2. For each ADR, determine whether the decision reflects current code
   or is marked with a valid supersession note.
3. Produce severity-ranked Findings (Critical / Warnings / Suggestions
   / Praise) with `doc:line` citations and contradicting evidence at
   `file:line` or `package.json#scripts`.

### 6. Print output

Relay the agent's output verbatim.

---

## Rubric (pass verbatim to agent)

- Every file path mentioned in a doc exists on disk.
- Every shell command referenced exists in `package.json` scripts
  (root or `web/`).
- Every port number matches `backend/Caddyfile` and
  `docker-compose*.yml`.
- Every stack component named (CSS framework, bundler, adapter) is
  present in `web/package.json` dependencies or devDependencies. If a
  component was replaced, the old name must be absent and the new name
  present.
- Every ADR's decision either:
  - Reflects current code reality, OR
  - Is marked `Superseded by ADR-N`, with N existing and being a
    valid supersession.
- Every hook file name referenced (`auth_guard.pb.js`, etc.) exists in
  `backend/pb_hooks/`.

## Severity rules (pass verbatim to agent)

- **Critical.** ADR decision contradicts current code with no
  supersession note. Doc references a nonexistent file or command.
- **Warning.** Wrong port number. Outdated stack-component name
  (e.g., calling Tailwind "Bulma"). Architectural assertion that is
  half-true or no longer applies.
- **Suggestion.** Missing supersession cross-reference even when both
  ADRs are otherwise consistent. Rotted cross-references between docs.
- **Praise.** ADRs that are demonstrably current and correctly
  superseded where appropriate.

## Output format

Standard Findings sections. Each finding cites `<doc>:<line>` and the
contradicting evidence at `<file>:<line>` or
`<package.json#scripts/field>`.

```
## Findings

### Critical
### Warnings
### Suggestions
### Praise
```

Each finding: what, where (`doc:line`), why it matters. 2–3 lines
max. Empty sections: "None."

## Out of scope

- Do not rewrite docs.
- Do not propose new ADRs.
- Do not assess prose quality, formatting, or tone.
- Do not touch `docs/archive/`.
- Do not analyze `frontend/`.
