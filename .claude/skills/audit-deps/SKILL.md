---
name: audit-deps
description: Dependency security audit — npm audit findings, major-version drift, unpinned GHA actions, unpinned Docker base images, and unverified binary downloads. Run on demand and monthly.
---

# audit-deps

Surface security-relevant dependency state and pin compliance: `npm audit`
findings, major-version drift, unpinned GHA actions, unpinned Docker base
images, and unverified binary downloads.

Different from `/audit` (code quality) and `/security-review` (branch
security). This skill answers: "are dependencies and pins safe right now?"

Only run inside `~/Code/github` or `~/Code/playground`. Refuse if the
working directory is outside those paths (e.g. Vault, dotfiles).

## Steps

### 1. Run the deps checks script

```bash
.claude/skills/audit-deps/deps-checks.sh
```

Capture the full output. The script runs `npm audit`, `npm outdated`,
and grep-based pin scans across GHA workflows and Dockerfiles.

### 2. Brief Opus

Call `Agent` with `subagent_type: "general-purpose"` and
`model: "opus"`.

The prompt must be self-contained. Include:

- The full output from `deps-checks.sh` (step 1)
- The rubric below (verbatim)
- The severity rules (verbatim)
- The pin classification table (verbatim)
- The out-of-scope list (verbatim)

Instruct the agent to:

1. Apply the rubric to every finding in the script output.
2. Rank findings by severity: Critical → Warning → Suggestion → Praise.
3. Return output in the standard Findings format, followed by the two
   summary tables.

### 3. Print output

Relay the agent's output verbatim.

---

## Pin classification table (pass verbatim to agent)

### GHA action `uses:` pins

| Pattern | Example | Classification |
| ------- | ------- | -------------- |
| No version | `uses: actions/checkout` | Critical |
| Branch pin | `uses: actions/checkout@master` or `@main` | Critical |
| Floating major | `uses: actions/checkout@v4` | Warning |
| Specific minor | `uses: actions/checkout@v4.1.7` | OK |
| 40-char SHA | `uses: actions/checkout@abc123...` | Best |

### Dockerfile `FROM` base images

| Pattern | Example | Classification |
| ------- | ------- | -------------- |
| No tag | `FROM node` | Critical |
| `latest` tag | `FROM node:latest` | Critical |
| Floating major | `FROM node:20` | Warning |
| Specific minor | `FROM node:20.11.0` | OK |
| SHA digest | `FROM node:20.11.0@sha256:...` | Best |

### Binary downloads in Dockerfiles / workflow scripts

| Pattern | Classification |
| ------- | -------------- |
| `curl`/`wget` download without `sha256sum -c` verification | Critical |
| `curl`/`wget` download with `sha256sum -c` verification | OK |

---

## Rubric (pass verbatim to agent)

### npm audit

1. Any `npm audit` finding at **high** or **critical** severity → Critical.
2. Any `npm audit` finding at **moderate** severity → Warning.
3. Any `npm audit` finding at **low** severity → Suggestion.

### npm outdated

4. **Major-version drift** on a production dependency (current major <
   latest major) → Warning.
5. **Minor/patch drift** on a production dependency → Suggestion.
6. Dev dependencies: same classification one level lower (major →
   Suggestion; minor/patch → no finding).

### GHA action pins

Apply the pin classification table above. Report each workflow file and
step name alongside the finding. Flag every `uses:` line individually.

### Dockerfile base image pins

Apply the pin classification table above. Report each `FROM` line with
its file and line number.

Note: multi-stage builds have multiple `FROM` lines — flag each one
separately.

### Binary downloads

7. Any `curl`, `wget`, or `RUN sh -c` / `RUN bash -c` line in a
   Dockerfile that fetches a file must be followed (in the same `RUN`
   layer) by a `sha256sum -c` or equivalent verification. Missing
   verification → Critical.
8. Confirm the PocketBase binary download in `backend/Dockerfile` and
   `backend/Dockerfile.dev` still uses `sha256sum -c` with per-arch
   hashes. If the verification is intact → Praise. If removed →
   Critical.

### Workflow binary downloads

9. Any `wget`/`curl` in a GHA workflow step that fetches a binary
   without checksum verification → Warning (weaker than Dockerfile
   Critical because the CI runner is ephemeral, but still worth
   flagging).

---

## Severity rules (pass verbatim to agent)

- **Critical.** Any `npm audit` finding at high or critical. Unpinned
  or `latest`-tagged Dockerfile base image (`FROM image` or `FROM
  image:latest`). Binary download in a Dockerfile without checksum.
  GHA action with no version, `@master`, or `@main`.
- **Warning.** Any `npm audit` finding at moderate. Major-version drift
  on a production dependency. Floating major (`@v4`) on a GHA action.
  Floating major on a Dockerfile base image (`FROM node:20`). Binary
  download in a GHA workflow step without checksum.
- **Suggestion.** `npm audit` low findings. Minor/patch drift on any
  dependency. SHA-pinning GHA actions beyond version tags (best
  practice, not required).
- **Praise.** Dockerfiles with pinned base images and verified binary
  downloads. GHA workflows with SHA-pinned or specific-minor-pinned
  actions.

---

## Output format

Standard Findings sections, then the two summary tables:

```
## Findings

### Critical
### Warnings
### Suggestions
### Praise

### Outdated packages

| location | package | current | wanted | latest | type |
| -------- | ------- | ------- | ------ | ------ | ---- |
| root     | ...     | 1.2.3   | 1.2.4  | 2.0.0  | prod |

### npm audit summary

| location | critical | high | moderate | low |
| -------- | -------- | ---- | -------- | --- |
| root     | 0        | 0    | 0        | 1   |
| web/     | 0        | 0    | 1        | 3   |
```

Each finding: what, where (`file:line` where applicable), why it
matters. 2–3 lines max. Empty sections: "None."

---

## Out of scope

- Do not run `npm update`, `npm audit fix`, or modify any `package.json`.
- Do not recommend swapping libraries.
- Do not opine on bundle size, build time, or performance.
- Do not audit licenses.
- Do not modify Dockerfiles or workflows — only report.
