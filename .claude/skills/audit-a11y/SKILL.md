---
name: audit-a11y
description: WCAG 2.2 AA accessibility audit — runs axe-core via Playwright over login, register, team, and admin flows; surfaces semantic HTML, keyboard, contrast, and screen-reader findings. Run on demand and before milestone tags.
---

# audit-a11y

Audit critical user flows against WCAG 2.2 AA: semantic HTML, keyboard
navigation, color contrast, and screen-reader labels. Produces a baseline
on first run; subsequent runs detect regressions.

Different from `/audit` (code quality). This skill answers: "are the key
flows accessible to keyboard-only and screen-reader users?"

Only run inside `~/Code/github` or `~/Code/playground`. Refuse if the
working directory is outside those paths (e.g. Vault, dotfiles).

## Prerequisites

One-time install (already recorded in `web/package.json`):

```bash
cd web && npm install --save-dev @axe-core/playwright axe-core
```

## Steps

### 1. Run static grep checks

```bash
.claude/skills/audit-a11y/a11y-grep.sh
```

Capture the full output. It greps `web/src/routes/` and
`web/src/lib/components/` for static a11y anti-patterns.

### 2. Run svelte-check

```bash
cd web && npm run check 2>&1
```

Capture any accessibility warnings Svelte's built-in a11y checker emits.
Svelte warns on many a11y issues at compile time (missing `alt`, missing
`for`, interactive elements without handlers, etc.).

### 3. Start the test PocketBase container

```bash
npm run pb:test:up
```

Then wait for health:

```bash
curl --retry 10 --retry-delay 1 --retry-connrefused \
  http://localhost:28090/api/health
```

Source credentials from `.env.test`:

```bash
set -a && . ./.env.test && set +a
```

### 4. Run axe via Playwright

From the repo root (the `e2e:a11y` script handles env sourcing and directory):

```bash
npm run e2e:a11y
```

Or manually (from `web/`):

```bash
# from repo root — sources .env.test, then runs playwright inside web/
set -a && . ./.env.test && set +a && (cd web && npx playwright test --config playwright.a11y.config.ts)
```

The config and spec both live in `web/`, so playwright must be invoked
from inside `web/` to avoid a dual-version conflict with the root
`node_modules`.

The spec (`web/e2e/a11y-flows.e2e.ts`) navigates to each target route,
runs `AxeBuilder().withTags(['wcag2a','wcag2aa','wcag21aa','wcag22aa']).analyze()`,
and prints a JSON summary of violations per route to stdout.

**Coach route note.** `/team` requires an approved coach login. Set
`A11Y_COACH_EMAIL` and `A11Y_COACH_PASSWORD` in the environment before
running. If these are not set, the `/team` test is skipped automatically
with a clear message. Use staging credentials if no approved coach exists
in the local test PB.

### 5. Read all output

Collect:
- The grep output from step 1.
- The svelte-check output from step 2.
- The JSON axe violations from step 4 (one entry per route: route path,
  violation id, impact, description, nodes).

### 6. Brief Opus

Call `Agent` with `subagent_type: "general-purpose"` and `model: "opus"`.

The prompt must be self-contained. Include:

- The full grep output (step 1)
- The svelte-check output (step 2)
- The axe violation JSON (step 4) — all routes, all violations, all nodes
- The rubric below (verbatim)
- The severity rules (verbatim)
- The out-of-scope list (verbatim)
- Instruction to produce Findings sections plus the per-route violation
  count table

### 7. Print output

Relay the agent's output verbatim, then append:

```
## Baseline note

Save this output as docs/a11y-baseline-YYYY-MM-DD.md (manual step).
Future runs should compare violation counts against the latest baseline
and flag any increase as an additional Warning even when the issue pre-dated
the baseline.
```

---

## Rubric (pass verbatim to agent)

### Static anti-patterns (from grep)

1. **`<div onclick=` or `<span onclick=`** — non-interactive elements
   with click handlers. Use `<button>` for clickable controls.

2. **`<a href="javascript:`** — broken link pattern. Use `<button>` for
   non-navigation actions.

3. **`<a>` without `href`** — an anchor without href is not keyboard-
   focusable by default. Add `href` or use `<button>`.

4. **`<img>` without `alt`** — every `<img>` must have an `alt`
   attribute. Missing `alt` is a WCAG 1.1.1 failure.

5. **`<img alt="">`** — an empty `alt` signals a decorative image. Flag
   for review; many are accidental. If truly decorative, the empty `alt`
   is correct — note it as a Suggestion.

6. **`<input>` without an associated `<label>`** — checked by presence of
   a `for` attribute matching the input `id`, a wrapping `<label>`, or an
   `aria-label` / `aria-labelledby`. Unlabeled inputs fail WCAG 1.3.1 and
   4.1.2.

7. **Form `<input>` without a `name` attribute** — prevents form
   submission and breaks screen-reader context.

8. **`role="button"` on a non-button element without `tabindex="0"` and a
   keyboard handler** — custom buttons must be keyboard-accessible.
   Missing either `tabindex` or `onkeydown`/`onkeypress` is a WCAG 2.1.1
   failure.

### Dynamic checks (from axe)

Axe covers:
- Color contrast (WCAG 1.4.3, AA thresholds).
- ARIA validity (roles, properties, required children).
- Focus management and keyboard traps.
- Landmark structure (`<main>`, `<nav>`, etc.).
- Heading hierarchy.
- Form label associations.

Do not duplicate these in grep — axe is more accurate than static
analysis for these patterns.

### Additional checks (from agent reading file content)

- **Skipped heading levels** — `<h1>` to `<h3>` with no `<h2>` in
  between. WCAG 1.3.1. Grep for this is unreliable; Opus catches it from
  file content when reviewing route `.svelte` files.
- **Missing `<main>` landmark** — every page should have exactly one
  `<main>`. Axe catches this; Opus reinforces it.
- **Focus visible on interactive elements** — `:focus` styles must be
  present. Axe checks contrast but not all focus styles. Note if Tailwind
  classes suppress the focus ring (`outline-none` without a replacement).

## Severity rules (pass verbatim to agent)

- **Critical.** Axe `critical` or `serious` violations. Form inputs with
  no labels at all. Missing `<main>` landmark. Keyboard traps.
- **Warning.** Axe `moderate` violations. Skipped heading levels. Missing
  `alt` on `<img>`. `role="button"` on a div without keyboard handler.
  `outline-none` suppressing focus ring without replacement.
- **Suggestion.** Axe `minor` violations. `<img alt="">` that may be
  intentional but warrants review. Use of `title` attribute as the only
  label.
- **Praise.** Routes that pass axe with zero violations.

## Output format

```
## Findings

### Critical
### Warnings
### Suggestions
### Praise

### Per-route violation counts

| route                   | critical | serious | moderate | minor |
| ----------------------- | -------- | ------- | -------- | ----- |
| /login                  | 0        | 0       | 0        | 0     |
| /register               | ...      | ...     | ...      | ...   |
| /register/teacher-coach | ...      |         |          |       |
| /register/pending       | ...      |         |          |       |
| /team                   | ...      |         |          |       |
| /admin                  | ...      |         |          |       |
| /admin/teams            | ...      |         |          |       |
| /admin/tournaments      | ...      |         |          |       |
```

Each finding: what, where (`file:line` where applicable), why it matters.
2–3 lines max. Empty sections: "None."

## Out of scope

- Do not redesign the UI.
- Do not change visual styling, colors, or layout choices.
- Do not flag prose tone or content.
- Do not enforce WCAG AAA.
- Do not audit the `/demo` route.
- Do not audit `frontend/` (legacy Elm).
