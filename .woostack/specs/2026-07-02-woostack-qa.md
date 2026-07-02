---
name: woostack-qa
type: spec
status: approved
date: 2026-07-02
branch: feature/woostack-qa
links:
---

# woostack-qa — Design Spec

> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-07-02-woostack-qa]]

## 1. Problem

woostack can audit standing code (`woostack-audit`), review diffs (`woostack-review`), and
root-cause known bugs (`woostack-debug`), but it has no engine that exercises a **running
application** the way a user does. Bugs that only surface in the browser — unhandled console
exceptions, 4xx/5xx responses on real interactions, broken form validation, dead buttons,
visual breakage — have no woostack home today. Users hand-write ad-hoc "act as a QA engineer"
prompts per session, with no evidence conventions, no report artifact, and no handoff into
the fix loop.

## 2. Goal

A 20th public command skill, `woostack-qa`: point it at a running app URL and it acts as an
autonomous exploratory QA engineer — walks the core user journeys, attacks edge cases,
monitors an always-on assertion floor (console errors, failed network requests, visual bugs,
dead links/buttons), reproduces every suspected bug once before logging it, and emits a
severity-ranked, evidence-backed, **report-only** findings document under `.woostack/qa/`
that hands off per-bug to `woostack-fix` (small) or `woostack-build` (large).

## 3. Non-goals

- **Not a fixer.** Never writes application code, never commits, never merges. Fix execution
  belongs to `woostack-fix` / `woostack-build`.
- **Not a test-suite author.** Writing durable Playwright/unit tests is `woostack-tdd`'s job.
  woostack-qa produces a findings report, not test files.
- **Not CI.** No GitHub Action delivery, no gating, no PR posting. On-demand, local,
  interactive-session engine (like `woostack-audit`, unlike `woostack-review`).
- **Not a load/perf/security scanner.** No lighthouse budgets, no fuzzing at protocol level,
  no auth-bypass hunting. (A security-relevant observation found incidentally is still
  reported.)
- **Not app lifecycle management.** It does not start, build, or restart the target app; the
  server must already be running (dead server = clean stop, see §6).
- **No per-repo `qa` config block in v1.** YAGNI; the `audit`-style sibling key can come later.

## 4. Approach

Report-only exploratory engine, shaped like `woostack-audit`'s sibling for runtime behavior:

- **Browser binding: CLI over MCP.** The agent drives the browser stepwise from bash via
  **`agent-browser`** (Vercel's browser-automation CLI for AI agents; reference binding),
  with **Playwright's agent CLI** (`@playwright/cli`) as the sanctioned fallback — first
  available wins. CLI-over-bash keeps the skill host-agnostic (any bash host works, no MCP
  server config), token-cheap (compact ref-based snapshots), and evidence-native
  (screenshots land as files). Neither package is version-pinned; names only.
- **Lean on the tool's shipped guidance.** `agent-browser` ships version-matched usage
  skills (`agent-browser skills get core`, `... get dogfood` — the latter is its own
  systematic app-exploration guide). The QA skill instructs the agent to load those at run
  start instead of restating command reference, so woostack-qa never drifts from the
  installed CLI.
- **Invocation:** `/woostack-qa <url> [focus…]` — URL required (no accidental default
  target); optional free-form focus instructions. `--stop-first` halts at the first
  confirmed bug and deep-dives it.
- **Journey resolution is layered:** explicit focus args → `.woostack/` knowledge (spec §7
  acceptance criteria, `fixes/` as regression hotspots, `wisdom/` house-rules) plus
  route/source inspection → blind exploration of the discovered nav surface. The resolved
  plan is written into the report preamble as proof of attempted coverage
  ([[autonomy-needs-structural-proof]]: receipts, not vibes).
- **Explore adversarially:** core journeys first, then edge attacks — invalid inputs, empty
  submissions, double-submits, back-button traps, malformed URL params.
- **Coverage-defined run bound:** the resolved journey list is the work queue; blind
  exploration is one pass over the discovered nav surface (each page visited once plus its
  edge attacks), no re-crawl loops, no wall-clock cap. `--stop-first` is the only early
  exit. The bound is auditable in the coverage preamble.
- **Session hygiene:** the run closes its browser session (`close`) on completion and on
  abort paths, so the CLI daemon never leaks between runs.
- **Assertion floor on every step:** console errors/page exceptions (`console`, `errors`),
  4xx/5xx responses (`requests`), visual breakage (snapshot + screenshot: overflow, overlap,
  off-screen controls, unreadable contrast), dead links/buttons.
- **Origin containment:** exploration never leaves the target URL's origin. External links
  get a lightweight status probe for the broken-link floor but are never navigated into;
  cross-origin redirects (e.g. OAuth) are recorded as coverage boundaries.
- **Report artifact:** severity-ranked markdown at `.woostack/qa/<date>-<slug>.md`
  (git-tracked; joins `woostack-dream`'s decision corpus like `.woostack/audits/`), with
  screenshots under `.woostack/qa/evidence/<date>-<slug>/` — **gitignored** (the `visuals/`
  precedent: bulky, per-clone). The report inlines the textual evidence (console excerpts,
  failed request lines, repro steps) so it stands alone; screenshots are referenced by
  relative path with a transient note. Zero findings → explicit coverage report ("N journeys
  walked, no findings"), never a silent empty.

## 5. Components & data flow

One new skill directory, `skills/woostack-qa/`:

- **`SKILL.md`** — the whole engine: preflight contract, journey-resolution ladder,
  exploration doctrine, assertion floor, evidence rules, report format, handoff pointers,
  hard constraints. No scripts in v1 — the agent drives `agent-browser` interactively; the
  only deterministic pieces (preflight probe, report path) are single bash lines inlined in
  SKILL.md.
- **`references/report-template.md`** — the findings-doc skeleton (frontmatter, run
  preamble/coverage receipt, per-finding block: severity, repro steps, expected vs actual,
  evidence excerpts, screenshot links, suspected source, proposed fix direction, handoff).

Data flow:

```
/woostack-qa <url> [focus]
  → preflight (browser CLI present? url responds?)          — stop cleanly on failure
  → resolve journeys (args → .woostack knowledge → blind)   — write coverage preamble
  → explore loop: act → observe floor → (suspect? reproduce once → log finding + evidence)
  → rank findings by severity (review's vocabulary: HIGH/MEDIUM/LOW + blocking flag —
    one severity language across review, audit, qa; no new scale)
  → write .woostack/qa/<date>-<slug>.md + evidence/         — report-only artifact
  → terminal summary + per-finding handoff (/woostack-fix | /woostack-build)
```

Skill-collection bookkeeping (the [[lockstep-edit-sites]] surface for a 20th public
command): AGENTS.md (count, list, file map, Mode B), README, `using-woostack` routing row,
CONTRIBUTING sites, bootstrap `development.md` command list if present, authored `site/`
docs pages, plus any doctor check/test that asserts the skill count. The site's per-skill
reference page regenerates from SKILL.md at build time.

## 6. Error handling

- **No browser CLI available.** Preflight probes `agent-browser` then the Playwright agent
  CLI; neither runs → hard stop with install hint (`pnpm i -g agent-browser`, note its
  node ≥24 / pnpm ≥11 engine floor and `npx -y agent-browser` as the no-install path). Never
  simulate results without a browser.
- **Target URL unreachable.** Preflight `open <url>` (or curl probe) fails → hard stop:
  report the URL tried and the failure; do not guess a port, do not start the app.
- **Browser session dies mid-run.** Attempt one reconnect/reopen; if the run cannot
  continue, write the report with findings-so-far plus an explicit "run aborted at journey
  N" coverage note — a partial report never masquerades as full coverage.
- **Unreproducible suspicion.** A one-off anomaly that fails its reproduction attempt is
  logged in a separate "unconfirmed observations" report section, never as a finding.
- **Auth walls.** Credentials come only from explicit user input — focus args or a
  pause-and-ask when a login wall blocks the resolved journeys. Never guessed, never
  harvested from app source or `.env` on the skill's own initiative, never written into the
  report. No credentials → test the public surface and name the auth wall as uncovered in
  the coverage preamble.
- **Destructive-action guard.** Exploration avoids irreversible app actions (deletes,
  payments, sends) unless the focus args explicitly authorize them; when avoided, the report
  notes the skipped surface.
- **Secrets on screen.** Values seen in the app (tokens, emails, keys) stay in the local
  report/evidence only; the skill never sends them anywhere.

## 7. Acceptance criteria

Each AC is a testable behavior → ≥1 plan task.

> **Angle pre-flight.** Security → secrets-stay-local (§6) + destructive-action guard (AC6);
> observability → coverage receipts (AC2, AC7); api/database → N/A (no app code shipped);
> edge/error → AC5, AC6.

- **AC1 — Invocation contract**
  - happy: `/woostack-qa http://localhost:3000` runs full sweep; `--stop-first` halts at
    first confirmed bug with deep-dive; focus args narrow the journey set.
  - error: missing URL → usage error naming the required argument; never picks a default.
  - edge: URL plus flags plus multi-word focus parse together.
- **AC2 — Preflight gates**
  - happy: `agent-browser` present + URL responds → run proceeds; fallback CLI used when
    reference binding absent.
  - error: no browser CLI → stop with install hint; dead URL → stop naming URL and failure.
    No report of "no findings" is ever produced from a failed preflight.
  - edge: pnpx engine-check failure on `agent-browser` → hint offers `npx -y` path.
- **AC3 — Journey resolution ladder**
  - happy: focus args win; absent args, journeys derive from `.woostack/` specs/fixes/wisdom
    and route inspection; bare repo → blind nav exploration.
  - error: no journeys derivable and app has no discoverable nav → report says so explicitly;
    an uncredentialed auth wall names the gated surface as uncovered.
  - edge: derived journeys are listed in the report preamble even when zero findings result;
    the coverage bound (one pass, no re-crawl) is stated there too.
- **AC4 — Assertion floor**
  - happy: a console error, a 4xx/5xx response, a dead control, or visual breakage observed
    during any step becomes a finding (or unconfirmed observation).
  - error: floor signals from the app's own noise (expected 401 on logout, dev-mode
    warnings) are triaged, not auto-logged as bugs.
  - edge: multiple floor signals from one root interaction dedupe into one finding;
    external links are status-probed but never navigated into (origin containment).
- **AC5 — Reproduce-before-log**
  - happy: each finding carries numbered repro steps that were executed twice (found +
    reproduced).
  - error: reproduction fails → "unconfirmed observations" section, not a finding.
  - edge: `--stop-first` still requires the reproduction pass before halting.
- **AC6 — Report artifact & handoff**
  - happy: severity-ranked markdown at `.woostack/qa/<date>-<slug>.md`, evidence under
    `.woostack/qa/evidence/<date>-<slug>/`, each finding with expected vs actual, evidence,
    suspected source file(s), fix direction, and a `/woostack-fix` or `/woostack-build`
    pointer.
  - error: aborted run → partial report labeled aborted with coverage-so-far.
  - edge: zero findings → explicit coverage report; destructive surfaces skipped are named.
- **AC7 — Collection bookkeeping**
  - happy: all lockstep sites updated (AGENTS.md count/list/map, README, routing row,
    CONTRIBUTING, development.md if applicable, site authored pages); `pnpm -C site build`
    passes and generates the woostack-qa reference page.
  - error: doctor/tests asserting the command surface pass with the new count.
  - edge: N/A — no other surfaces enumerate the command count.

## 8. Testing

This repo ships prose + templates, not app code, so testing is the collection's own
verification surface: `pnpm -C site build` (site page generation + authored-page sync),
`woostack-doctor --check` if it asserts command-surface counts, and any existing skill-lint
tests that enumerate skills. The skill's runtime behavior (ACs 1–6) is specified as SKILL.md
contract language that `woostack-harden` stress-tests; a live smoke run against a local app
is the manual test in the PR test plan. Per-behavior cases live in §7.

## 9. Open questions

Settled during hardening:

- **Pointer-only handoff.** The report never auto-opens a `woostack-fix` plan; each finding
  carries the suggested command only. (Settled at design approval.)
- **Evidence gitignored, report self-sufficient.** `qa/evidence/` joins the `visuals/`
  gitignore class; the tracked report inlines all textual evidence. Gitignore entry is part
  of the lockstep bookkeeping surface (init template + doctor drift check).
- **Overnight integration deferred.** `woostack-execute-overnight` QA passes are out of
  scope v1.
