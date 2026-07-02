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
