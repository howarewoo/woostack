---
name: woostack-audit
description: Use to audit standing code — an explicit file, directory, module, or whole repo at rest (not a diff) — from multiple angles, focused on code simplification and production readiness. Synthesizes an all-added diff and drives woostack-review's swarm + adversarial validators, then writes a ranked, report-only findings doc under .woostack/audits/ that hands off to woostack-fix / woostack-build. Never gates, posts to a code host, auto-fixes, or merges. Invoke via /woostack-audit <target>.
install: pnpx skills add howarewoo/woostack
requires:
  bins: [jq, node, git]
recommends:
  bins: [rg]
---

# woostack-audit

Audit **standing code** — code at rest, not a change. Where
[`woostack-review`](../woostack-review/SKILL.md) gates a *diff* (a PR, in CI, with a blocking
event), `woostack-audit` inspects an explicit target on demand and emits a **ranked, report-only**
findings document. It **repoints the review engine**: it synthesizes an all-added diff from the
target so review's diff-anchored angle swarm and adversarial validators audit code at rest
unchanged, then renders a report instead of posting a review.

It is **report-only** — it **never** gates, **never** posts to a code host, **never** auto-fixes,
and **never merges**. It points findings at [`woostack-fix`](../woostack-fix/SKILL.md) (small) or
[`woostack-build`](../woostack-build/SKILL.md) (large), the way review points at `woostack-debug`.

## Commands

- `/woostack-audit <target>` — audit the path (file or directory). **The target is required** (no
  bare default — auditing a whole repo is opt-in, not accidental).
- `/woostack-audit --all` — audit the repo root (the sanctioned whole-repo opt-in).
- `/woostack-audit <target> --fast | --deep` — one-run tier override (review's `FORCE_TIER`).
- `/woostack-audit <target> --simplify | --prod-only` — narrow to one lens; `bugs` + `security`
  remain on as a safety floor.

## Angles

Audit runs on the synthetic diff with **`simplify`** and **`production-readiness`** always-on
(plus the `bugs` + `security` safety floor), and auto-detects review's other angles
(`observability`, `types`, `deps`, `tests`, `conventions`, …) on the target. The `architecture`
angle is skipped — `simplify` owns the full simplification surface when it is absent (see
[`prompts/angles/simplify.md`](../woostack-review/prompts/angles/simplify.md)). Both new angles are
shared with `woostack-review`, which also runs them on source-touching diffs.

## Per-repo configuration

Drop an optional sibling **`audit`** block in `.woostack/config.json` (review's loader ignores
non-`review` keys, so the two namespaces never collide):

```json
{ "audit": { "severity_floor": "high", "angles": { "skip": ["deps"] }, "ignore": ["**/*.generated.ts"] } }
```

Keys mirror review: `angles.force` / `angles.skip`, `severity_floor`, `ignore`, `models`,
`chunking.max_loc`, `report_dir`. Parsed by `scripts/load-audit-config.sh`; an unknown key
hard-fails.

## Workflow

Resolve `WOO_REVIEW_ACTION_PATH` to the installed `woostack-review` skill directory and resolve
`OUTDIR` once (`woostack-review/scripts/resolve-outdir.sh`), exporting both to every stage and
sub-agent. Then run, in order:

1. **Build the target diff** — `scripts/build-target-diff.sh` (with `AUDIT_TARGET=<target>`):
   writes the all-added `diff.txt` (+ chunks) and a synthetic `meta.json`, applying review's
   section-aware cap and `chunk-diff.sh`. An empty/binary-only target reports "no auditable files"
   and stops cleanly.
2. **Resolve the audit angle set** — `scripts/load-audit-config.sh` writes `$OUTDIR/config.json`
   (forces `simplify` + `production-readiness`, skips `architecture`, honors the lens flag), then
   `$WOO_REVIEW_ACTION_PATH/scripts/detect-angles.sh` reads it to produce `$OUTDIR/angles.txt`.
3. **Run the bounded swarm** — `$WOO_REVIEW_ACTION_PATH/scripts/run-bounded-swarm.sh`, one worker
   per angle (× chunk), each reading `_header.md` + its angle prompt and writing
   `findings.<angle>.json` + a receipt. Then the receipt gate
   `$WOO_REVIEW_ACTION_PATH/scripts/verify-receipts.sh` hard-fails the run if any angle never
   executed (no false-clean report).
4. **Merge + adversarially validate** — `merge-findings.sh` → prosecutor → defender →
   `intersect-findings.sh`, reused unchanged. The validated set is `$OUTDIR/findings.json`.
5. **Render the report** — `scripts/render-report.sh` writes a severity-grouped, anchored,
   report-only markdown doc to `.woostack/audits/<date>-<slug>.md` (git-tracked; it joins
   `woostack-dream`'s decision corpus) and prints a terminal summary.

The PR-only stages of review — fetch, incremental marker, prior-thread event floor, the host
posting step, defer markers — are not part of an audit run; there is no event and no remote
mutation.

## Hard constraints

- **Report-only.** No event, no code-host posting, no PR mutation, no auto-fix, no merge.
- **Explicit target required.** Never audit a default scope; `--all` is the only whole-repo path.
- **Reuse, don't fork.** Drive `woostack-review`'s scripts via `WOO_REVIEW_ACTION_PATH`; audit owns
  only `build-target-diff.sh`, `load-audit-config.sh`, and `render-report.sh`.
- **Secrets stay local.** A finding may quote source containing a secret; the report is a local
  file and is never sent anywhere.
