Authority: non-authoritative diagnostic evidence

Report only. This file is not issue scope, approval, assignment, lifecycle state, acceptance, or
permission to mutate the repository.

# QA run — {{APP_OR_FOCUS}} — {{DATE}}

## Report metadata

- **Target:** {{URL}}
- **Canonical repository:** {{REPOSITORY}}
- **Browser binding:** {{agent-browser|playwright-cli}}
- **Outcome:** {{complete|partial|aborted}}
- **Findings:** {{N}}
- **Sanitization:** passed residual check {{RECEIPT_OR_TIMESTAMP}}
- **Managed context:** {{none | exact verified issue/project provenance and read receipt}}

## Coverage receipt

- **Journey source:** {{focus args | verified managed context | blind exploration}}
- **Queue:** {{numbered journey list — the run bound}}
- **Bound:** one pass, no re-crawl{{; --stop-first exit at finding 1 if applicable}}
- **Session closed:** {{yes/no}}
- **Uncovered:** {{auth walls; destructive surfaces skipped; cross-origin boundaries | none}}
- **Aborted:** {{n/a | journey N, reason, and result of the one reconnect attempt}}

## Findings ({{N}}, ranked)

### 1. [{{HIGH|MEDIUM|LOW}}{{, blocking}}] {{one-line title}}

- **Repro (executed twice):**
  1. {{step}}
  2. {{step}}
- **Expected:** {{behavior}}
- **Actual:** {{behavior}}
- **Evidence:**
  - console: `{{minimum sanitized excerpt}}`
  - network: `{{METHOD /path → status}}`
  - screenshot: `evidence/{{DATE}}-{{SLUG}}/{{file}}.png` (transient, per-clone)
- **Suspected source:** `{{path/to/file.ext}}` — {{why}}
- **Root-cause confidence:** {{verified|high|medium|low}} — {{basis}}
- **Bounded remediation direction:** {{one or two sentences; not authority to edit}}

#### Proposed bounded remediation contract

- Canonical repository: {{REPOSITORY}}
- Proved problem: {{problem and root-cause confidence}}
- Bounded scope: {{source paths and excluded surface}}
- Evidence pointers: {{finding and sanitized evidence references}}
- Observable acceptance criteria: {{behavior that must be observed}}
- Optional Linear artifact: {{none | stable UUID / native ID / URL}}
- Artifact read-back: {{n/a | receipt ID and timestamp}}

## Unconfirmed observations

- {{anomaly seen once, reproduction failed — exact signal and where}} — or `none`

## Zero-finding or abort receipt

- {{When N=0: exact completed journey count and coverage. When aborted: findings-so-far and exact
  abort point. Otherwise: n/a.}}
