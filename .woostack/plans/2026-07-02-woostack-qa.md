---
type: plan
source: .woostack/specs/2026-07-02-woostack-qa.md
status: ready
branch: feature/woostack-qa
---

**Source:** [[specs/2026-07-02-woostack-qa]]

# woostack-qa — Exploratory browser QA engine — Implementation Plan

**Goal:** Ship `woostack-qa`, the 20th public command skill: an autonomous, report-only
exploratory QA engineer that drives a running app through the `agent-browser` CLI, walks core
journeys, attacks edge cases, monitors an always-on assertion floor, reproduces every bug before
logging it, and writes a severity-ranked findings doc under `.woostack/qa/` that hands off to
`woostack-fix` / `woostack-build`.

**Architecture:** Two linearly-stacked increments on the spec+plan base PR (#441). Increment 1
ships the skill itself — `skills/woostack-qa/SKILL.md` (the whole engine: preflight, journey
ladder, exploration doctrine, assertion floor, evidence rules, report contract, hard
constraints), `references/report-template.md`, and the `qa/evidence/` line in
`woostack-init`'s gitignore template (the doctor drift check reads that template, so it follows
automatically). Increment 2 does the 20th-public-skill command-surface bookkeeping across the
collection. No scripts ship in v1 — the agent drives `agent-browser` interactively and leans on
its version-matched shipped guidance (`skills get core`, `skills get dogfood`).

**Tech Stack:** Markdown skill prose, `agent-browser` CLI (reference binding; Playwright agent
CLI fallback — names only, never version-pinned), grep/`pnpm -C site build` structural
verification.

**Lockstep note (wisdom: [[lockstep-edit-sites]]):** the public-command surface moves together —
AGENTS.md (count word ×2, twenty-one-files constraint, skill list, Quick file map, Mode B command
list), README, CONTRIBUTING surface sentence, `using-woostack` routing table,
bootstrap `development.md` command table, and the authored site utilities page. Increment 2 moves
all of them in one commit. **Autonomy proof (wisdom: [[autonomy-needs-structural-proof]]):**
every increment pins its result with concrete verification commands (grep with expected output,
site build), never bare prose.

---

## Increment 1: The `woostack-qa` skill

> One independently shippable PR — the skill directory plus the gitignore-template line. Not yet
> routed/listed anywhere; a `woostack-defer(increment 2)` marker in SKILL.md declares the
> bookkeeping gap so reviewing this PR in isolation doesn't flag the unregistered command.

### Task 1: Author `skills/woostack-qa/SKILL.md`

**Files:**
- Create: `skills/woostack-qa/SKILL.md`

- [ ] **Step 1: Write the skill file**
  ```markdown
  ---
  name: woostack-qa
  description: Use to exploratory-QA a running web app in a real browser — walk the core user journeys, attack edge cases (invalid inputs, empty submits, malformed params), monitor an always-on assertion floor (console errors, 4xx/5xx responses, visual breakage, dead links/buttons), reproduce each bug before logging it, and write a severity-ranked, report-only findings doc under .woostack/qa/ that hands off per-finding to woostack-fix or woostack-build. Never fixes, commits, posts, or merges. Invoke via /woostack-qa <url> [focus…].
  install: pnpx skills add howarewoo/woostack
  recommends:
    bins: [agent-browser]
  ---

  <!-- woostack-defer(increment 2): command-surface bookkeeping (AGENTS.md, README, routing) lands in increment 2 -->

  # woostack-qa

  Exploratory-QA a **running application** the way a user would. Where
  [`woostack-audit`](../woostack-audit/SKILL.md) inspects standing code at rest and
  [`woostack-review`](../woostack-review/SKILL.md) gates a diff, `woostack-qa` drives the live
  app in a real browser: it walks the core journeys, attacks edge cases, watches an always-on
  assertion floor, reproduces every suspected bug once before logging it, and emits a
  severity-ranked, **report-only** findings document under `.woostack/qa/`.

  It is **report-only** — it **never** writes application code, **never** commits, **never**
  posts to a code host, and **never merges**. Each finding carries a handoff pointer:
  [`woostack-fix`](../woostack-fix/SKILL.md) (small) or
  [`woostack-build`](../woostack-build/SKILL.md) (large). It is an on-demand local engine —
  no CI delivery, no gating. It is not a test-suite author (durable tests are
  [`woostack-tdd`](../woostack-tdd/SKILL.md)'s job), not a load/perf/security scanner, and it
  never starts, builds, or restarts the target app.

  ## Commands

  - `/woostack-qa <url> [focus…]` — QA the app at `<url>`. **The URL is required** (no
    accidental default target). Optional free-form focus instructions narrow the journey set,
    supply credentials, or authorize destructive surfaces.
  - `/woostack-qa <url> --stop-first` — halt at the first **confirmed** (reproduced) bug and
    deep-dive it: inspect the relevant source in the repo, and write the report with that one
    finding's suspected cause and proposed fix direction.

  ## Browser binding

  Drive the browser from bash via the **`agent-browser`** CLI (reference binding). At run
  start, load its version-matched shipped guidance instead of guessing commands:

  ```bash
  agent-browser skills get core --full   # command reference + patterns
  agent-browser skills get dogfood       # its systematic app-exploration guide
  ```

  Fallback: the Playwright agent CLI (`@playwright/cli`) when `agent-browser` is unavailable —
  first available wins. Reference both by name only; never pin versions. Any equivalent
  snapshot/act/console/network/screenshot CLI satisfies the contract.

  ## Preflight (hard gates — never fake results)

  1. **Browser CLI present.** Probe `agent-browser --version` (fall back to
     `npx -y agent-browser --version`), then the Playwright agent CLI. Neither runs → **stop**
     with the install hint `pnpm i -g agent-browser` (engine floor: node ≥ 24, pnpm ≥ 11; the
     `npx -y agent-browser` path needs no global install). Never simulate browser results.
  2. **Target responds.** `agent-browser open <url>` (or a `curl -sf -o /dev/null <url>`
     probe first). Unreachable → **stop**, naming the URL and the failure. Do not guess
     another port; do not start the app.

  A failed preflight produces **no report** — "no findings" from a run that never ran is the
  false-clean the receipts doctrine forbids.

  ## Journey resolution (layered)

  Resolve the work queue before exploring, and write it into the report preamble as the
  coverage receipt:

  1. **Focus args win.** Explicit instructions define the journeys (and only they can supply
     credentials or authorize destructive surfaces).
  2. **`.woostack/` knowledge.** Spec §7 acceptance criteria describe intended behavior;
     `fixes/` are regression hotspots; `wisdom/` house-rules apply. Pair with route/source
     inspection of the repo serving the app.
  3. **Blind exploration.** No knowledge available → discover the nav surface from the app
     itself and enumerate it.

  **Run bound is coverage-defined:** the resolved journey list is the queue; blind exploration
  is one pass over the discovered nav surface (each page once, plus its edge attacks) — no
  re-crawl loops, no wall-clock cap. `--stop-first` is the only early exit.

  ## Exploration doctrine

  - **Core journeys first, then adversarial edges:** invalid inputs, empty submissions,
    double-submits, back-button traps, malformed URL params.
  - **Origin containment.** Never leave the target URL's origin. External links get a
    lightweight status probe for the broken-link floor but are never navigated into;
    cross-origin redirects (e.g. OAuth) are recorded as coverage boundaries.
  - **Auth walls.** Credentials come only from explicit user input — focus args, or a
    pause-and-ask when a login wall blocks the resolved journeys in an interactive session.
    Never guessed, never harvested from app source or `.env` on the skill's own initiative,
    never written into the report. No credentials → test the public surface and name the
    gated surface as uncovered.
  - **Destructive-action guard.** Avoid irreversible app actions (deletes, payments, sends)
    unless the focus args explicitly authorize them; name every skipped surface in the report.
  - **Session hygiene.** `agent-browser close` on completion **and** on abort paths, so the
    CLI daemon never leaks between runs.

  ## Assertion floor (every step)

  After each interaction, check all four signal classes:

  - **Console:** `agent-browser console` + `agent-browser errors` — unhandled exceptions,
    error-level logs.
  - **Network:** `agent-browser requests` — 4xx/5xx responses tied to the interaction.
  - **Visual:** `agent-browser snapshot` (+ `screenshot` for evidence) — overflow, overlapping
    text, off-screen controls, unreadable contrast.
  - **Dead controls:** links/buttons that produce no navigation, no request, and no DOM
    change.

  Triage before logging: expected noise (a 401 on logout, dev-mode warnings) is not a bug.
  Multiple floor signals from one root interaction dedupe into **one** finding.

  ## Reproduce before log

  A suspected bug becomes a **finding** only after a second, clean reproduction from its
  numbered steps. Reproduction fails → it is an **unconfirmed observation** (its own report
  section), never a finding. `--stop-first` still requires the reproduction pass before
  halting.

  ## Report

  Write one severity-ranked markdown doc per run to `.woostack/qa/<date>-<slug>.md`
  (git-tracked; it joins `woostack-dream`'s decision corpus like `.woostack/audits/`), from
  [references/report-template.md](references/report-template.md). Severity uses review's
  vocabulary — `HIGH` / `MEDIUM` / `LOW` plus a `blocking` flag for crash/data-loss/
  journey-blocking bugs — one severity language across review, audit, and qa.

  - **Preamble = coverage receipt:** the resolved journey queue, the run bound, auth walls and
    destructive surfaces skipped, and the binding used.
  - **Per finding:** severity, numbered repro steps (executed twice), expected vs actual,
    inlined textual evidence (console excerpts, failed request lines), screenshot paths,
    suspected source file(s) from repo inspection, proposed fix direction, and the
    `/woostack-fix` or `/woostack-build` pointer.
  - **Evidence:** screenshots under `.woostack/qa/evidence/<date>-<slug>/` — **gitignored**
    (the `visuals/` precedent; per-clone proof). The report inlines all textual evidence so it
    stands alone; screenshot references carry a transient note.
  - **Zero findings** → an explicit coverage report ("N journeys walked, no findings") —
    never a silent empty. **Aborted run** (browser session died after one reconnect attempt)
    → a partial report labeled aborted, with findings-so-far and the abort point.
  - **Secrets stay local.** Values seen in the app (tokens, emails, keys) appear in the local
    report/evidence only; the skill never sends them anywhere.

  ## Hard constraints

  - **Report-only.** No app-code writes, no commits, no code-host posting, no auto-fix, no
    merge.
  - **Explicit URL required.** Never pick a default target.
  - **Never fake browser results.** No CLI or dead server → hard stop, no report.
  - **Reproduce before log.** Unreproduced suspicions are observations, not findings.
  - **Credentials only from the user.** Never guessed or harvested; never in the report.
  - **Stay on origin; guard destructive actions; close the session.**
  ```

- [ ] **Step 2: Verify frontmatter + structure**
  Run: `head -8 skills/woostack-qa/SKILL.md | grep -c "name: woostack-qa\|description: Use to\|install: pnpx"`
  Expected: `3`
  Run: `grep -c "^## " skills/woostack-qa/SKILL.md`
  Expected: `9` (Commands, Browser binding, Preflight, Journey resolution, Exploration
  doctrine, Assertion floor, Reproduce before log, Report, Hard constraints)

### Task 2: Author `references/report-template.md`

**Files:**
- Create: `skills/woostack-qa/references/report-template.md`

- [ ] **Step 1: Write the template**
  ```markdown
  ---
  name: {{DATE}}-{{SLUG}}
  type: qa-report
  date: {{DATE}}
  target: {{URL}}
  binding: {{agent-browser|playwright-cli}}
  findings: {{N}}
  status: {{complete|aborted}}
  ---

  # QA run — {{APP_OR_FOCUS}} — {{DATE}}

  ## Coverage (receipt)

  - **Target:** {{URL}} ({{binding}}, session closed: {{yes/no}})
  - **Journey source:** {{focus args | .woostack knowledge | blind exploration}}
  - **Queue:** {{numbered journey list — the run bound}}
  - **Bound:** one pass, no re-crawl{{; --stop-first exit at finding 1 if applicable}}
  - **Uncovered:** {{auth walls hit without credentials; destructive surfaces skipped;
    cross-origin boundaries}} — or `none`
  - **Aborted:** {{n/a | "at journey N — <why>, after one reconnect attempt"}}

  ## Findings ({{N}}, ranked)

  ### 1. [{{HIGH|MEDIUM|LOW}}{{, blocking}}] {{one-line title}}

  - **Repro (executed twice):**
    1. {{step}}
    2. {{step}}
  - **Expected:** {{behavior}}
  - **Actual:** {{behavior}}
  - **Evidence:**
    - console: `{{exact excerpt}}`
    - network: `{{METHOD /path → status}}`
    - screenshot: `evidence/{{DATE}}-{{SLUG}}/{{file}}.png` (transient, per-clone)
  - **Suspected source:** `{{path/to/file.ext}}` — {{why}}
  - **Fix direction:** {{one or two sentences}}
  - **Handoff:** `/woostack-fix {{one-line description}}` {{or /woostack-build for large}}

  ## Unconfirmed observations

  - {{anomaly seen once, reproduction failed — exact signal and where}} — or `none`
  ```

- [ ] **Step 2: Verify template placeholders**
  Run: `grep -c "{{" skills/woostack-qa/references/report-template.md`
  Expected: a non-zero count (placeholders present); and
  `grep -c "type: qa-report\|## Coverage (receipt)\|## Unconfirmed observations" skills/woostack-qa/references/report-template.md` → `3`

### Task 3: Add `qa/evidence/` to the init gitignore template

**Files:**
- Modify: `skills/woostack-init/templates/gitignore` (transient block, after `visuals/`)

- [ ] **Step 1: Add the line**
  In the `# Transient, per-clone — not shared knowledge.` block, after `visuals/`:
  ```
  qa/evidence/
  ```

- [ ] **Step 2: Verify the doctor drift check picks it up**
  Run: `grep -n "qa/evidence/" skills/woostack-init/templates/gitignore`
  Expected: one hit inside the transient block. (`woostack-doctor`'s
  `gitignore-drift.sh` reads this template directly — no doctor edit needed.)

- [ ] **Step 3: Commit increment 1**
  ```bash
  gt create -m "feat: add woostack-qa skill (exploratory browser QA engine)"
  gt submit
  ```

## Increment 2: 20th-public-command bookkeeping

> One independently shippable PR — every lockstep site moves together; removes increment 1's
> `woostack-defer` marker. All prose edits; verification is grep + `pnpm -C site build`.

### Task 4: AGENTS.md (4 sites)

**Files:**
- Modify: `AGENTS.md:17` (count), `AGENTS.md:~40` (skill list), `AGENTS.md:43`
  (nineteen-skill phrasing), `AGENTS.md:104` (rename constraint), Quick file map, Mode B list

- [ ] **Step 1: Update the surface count and list**
  - Line 17: `nineteen skills` → `twenty skills`.
  - Add `- [\`woostack-qa\`](skills/woostack-qa/SKILL.md)` to the public list (after
    `woostack-sweep`, before `woostack-audit`, matching command-family grouping).
  - Line 43: `nineteen-skill command surface` → `twenty-skill command surface`.
  - Line 104: `twenty-one \`SKILL.md\` files (the nineteen public` → `twenty-two \`SKILL.md\`
    files (the twenty public`.
  - Mode B paragraph: add `/woostack-qa` to the command enumeration.
  - Quick file map: add
    `- Exploratory browser QA engine (report-only): [\`skills/woostack-qa/SKILL.md\`](skills/woostack-qa/SKILL.md)`.

- [ ] **Step 2: Verify**
  Run: `grep -c "woostack-qa" AGENTS.md`
  Expected: `≥ 4`; and `grep -c "nineteen" AGENTS.md` → `0`

### Task 5: README, CONTRIBUTING, routing, development.md

**Files:**
- Modify: `README.md` (skill list section, ~line 124 area)
- Modify: `CONTRIBUTING.md:3` (surface sentence)
- Modify: `skills/using-woostack/SKILL.md` (routing table, after the audit row ~line 85)
- Modify: `skills/woostack-bootstrap/references/development.md` (command table, ~line 15)

- [ ] **Step 1: README** — add
  `- **Exploratory browser QA** → [/woostack-qa](skills/woostack-qa/SKILL.md)` beside the
  audit entry.

- [ ] **Step 2: CONTRIBUTING** — add `woostack-qa` to the public-surface sentence (before
  `woostack-audit`, mirroring AGENTS.md order).

- [ ] **Step 3: using-woostack routing row** — after the audit row:
  ```markdown
  | `/woostack-qa <url> [focus…] [--stop-first]`, exploratory-QA a running app in a real browser, report-only findings under `.woostack/qa/` | `woostack-qa` |
  ```

- [ ] **Step 4: development.md row** — in the command table:
  ```markdown
  | Exploratory-QA a running app in the browser | `woostack-qa` |
  ```

- [ ] **Step 5: Verify**
  Run: `grep -l "woostack-qa" README.md CONTRIBUTING.md skills/using-woostack/SKILL.md skills/woostack-bootstrap/references/development.md | wc -l`
  Expected: `4`

### Task 6: Site utilities page + build check

**Files:**
- Modify: `site/content/docs/concepts/utilities.mdx` (read-only utilities table)

- [ ] **Step 1: Add the row** to the read-only utilities table (with `woostack-ask`,
  `woostack-visualize`, `woostack-status`, `woostack-debug`):
  ```markdown
  | [woostack-qa](/docs/skills/woostack-qa) | Exploratory-QAs a running app in a real browser and writes a severity-ranked, report-only findings doc. | report file only | `/woostack-qa <url> [focus…]` |
  ```
  (Mutation column: the report file under `.woostack/qa/` is the only write.)

- [ ] **Step 2: Remove the deferral marker** from `skills/woostack-qa/SKILL.md` (the
  `woostack-defer(increment 2)` comment) — the bookkeeping it deferred now exists.
  Run: `grep -c "woostack-defer" skills/woostack-qa/SKILL.md`
  Expected: `0`

- [ ] **Step 3: Site build**
  Run: `pnpm -C site build`
  Expected: exit 0; the generated per-skill page `site/content/docs/skills/woostack-qa.mdx`
  appears (gitignored — do not commit it).

- [ ] **Step 4: Commit increment 2**
  ```bash
  gt create -m "docs: register woostack-qa across the command surface"
  gt submit
  ```

## Plan Checks

- **Spec coverage** — §4 approach → Task 1 (binding, ladder, doctrine, floor, bound); §5
  components → Tasks 1–2; §5 bookkeeping + AC7 → Tasks 4–6; §6 error handling → Task 1
  (Preflight, hygiene, abort, auth, destructive, secrets); evidence-gitignore decision →
  Task 3.
- **AC coverage** — AC1 (Commands section), AC2 (Preflight section incl. the npx engine-floor
  edge), AC3 (Journey resolution + coverage receipt), AC4 (Assertion floor + triage/dedupe +
  origin probe), AC5 (Reproduce before log incl. --stop-first edge), AC6 (Report section +
  template), AC7 (Increment 2 + site build). ACs are skill-contract prose pinned by the grep
  verifications; the live smoke run is the PR's manual test plan.
- **No placeholders** — full SKILL.md and template content inline; exact paths/commands with
  expected output. (Template `{{…}}` tokens are the template's own fill-slots, not plan
  placeholders.)
- **Type consistency** — n/a (prose); names (`woostack-qa`, `.woostack/qa/`, `qa/evidence/`)
  consistent across tasks.
- **Angle coverage** — security (auth/secrets/destructive in Task 1), observability
  (receipts/abort labeling in Tasks 1–2), tests (structural greps + site build; no runner in
  this repo → concrete verification per woostack-tdd), deps (`recommends: bins`, names
  unpinned).
