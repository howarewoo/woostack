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
