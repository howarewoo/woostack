# Skill evaluation schemas

All schemas in this document use `schemaVersion: 1`. Producers must reject unknown
versions, unknown fields, wrong JSON types, and duplicate identities. Paths are POSIX-style,
relative paths even when the host is Windows. They must be normalized before use, must stay
inside the stated root, and must resolve only through regular, non-symlink files.

## Corpus files

Both corpus files have this envelope:

```json
{"schemaVersion":1,"skill":"woostack-example","cases":[]}
```

`skill` must exactly equal the package frontmatter `name`. A case `id` is a stable,
unique, lower-case kebab-case identifier. Published IDs are never repurposed for a different
scenario. Assertion IDs are likewise stable and unique within their case.

### Behavior corpus

`evals/evals.json` contains behavior cases:

```json
{
  "schemaVersion": 1,
  "skill": "woostack-example",
  "cases": [{
    "id": "preserves-approval-gate",
    "prompt": "Carry out the approved plan.",
    "fixtures": ["approved-plan.md"],
    "capabilities": ["read-workspace"],
    "expected": "The worker stops at the required approval gate.",
    "assertions": [{
      "id": "mentions-approval",
      "kind": "final-contains",
      "substring": "approval",
      "critical": true
    }]
  }]
}
```

Required case fields are `id`, non-empty `prompt`, non-empty `expected`, and non-empty
`assertions`. `fixtures` is optional and contains unique paths relative to the owning
`evals/fixtures/` directory. A fixture may not be absolute, contain a `..` segment, escape
that directory, or resolve through a symlink or non-regular file.

`capabilities` is optional and defaults to `["read-workspace"]`. Its only allowed values are:

- `read-workspace`
- `write-workspace`
- `shell-workspace`

Corpus data can never grant network, credential, provider, environment-inspection, or
out-of-workspace access.

### Trigger corpus

`evals/trigger-evals.json` contains trigger cases:

```json
{
  "schemaVersion": 1,
  "skill": "woostack-example",
  "cases": [{
    "id": "runs-example-command",
    "query": "Evaluate this example skill.",
    "shouldTrigger": true,
    "expectedSkill": "woostack-example",
    "conflictsWith": ["woostack-review"]
  }]
}
```

Required fields are `id`, non-empty `query`, boolean `shouldTrigger`, and
`expectedSkill`. `expectedSkill` is a canonical skill name or the literal `none`.
`conflictsWith` is an optional unique array of canonical skill names. Positive and negative
cases use this same shape.

## Assertions

Every assertion has exactly `id`, `kind`, its kind-specific fields, and optional boolean
`critical` (default `false`). The eight deterministic kinds and the qualitative kind are:

| `kind` | Required fields | Semantics |
| --- | --- | --- |
| `path-exists` | `path` | A regular, non-symlink workspace path exists. |
| `path-absent` | `path` | No workspace entry exists at the path. |
| `file-contains` | `file`, `substring` | UTF-8 file includes the literal substring. |
| `file-excludes` | `file`, `substring` | UTF-8 file excludes the literal substring. |
| `json-path-equals` | `file`, `pointer`, `expected` | Parsed JSON value at the pointer is deeply equal to the JSON `expected` value. |
| `final-contains` | `substring` | Captured final output includes the literal substring. |
| `final-excludes` | `substring` | Captured final output excludes the literal substring. |
| `receipt-field-equals` | `pointer`, `expected` | Action receipt value at the pointer is deeply equal to `expected`. |
| `qualitative` | `rubric` | An isolated grader answers the explicit boolean question in `rubric`. |

`path` and `file` are relative to the copied case workspace and never follow symlinks.
All `substring` checks are case-sensitive, literal UTF-8 substring checks: they are not
regular expressions, globs, Unicode normalization, or Markdown-aware matching. An empty
substring is invalid.

`pointer` is an RFC 6901 JSON Pointer. It is either the empty string (the whole document) or
starts with `/`; `~0` decodes to `~` and `~1` to `/`. No dot-path or URI-fragment syntax is
accepted. `qualitative.rubric` must be a non-empty question answerable strictly true or false.
The grader's boolean and rationale are stored in a grade, never inferred from prose.

## Manifest

`manifest.json` is host-owned and has this exact shape:

```json
{
  "schemaVersion": 1,
  "runId": "20260715T120000Z-1234",
  "targetSkill": "woostack-example",
  "mode": "all",
  "runs": 2,
  "baseline": {"kind":"git-ref","identity":"0123456789abcdef0123456789abcdef01234567"},
  "runConfiguration": {
    "host": null,
    "runner": null,
    "model": null,
    "sessionIdentity": null,
    "tier": null,
    "effort": null
  },
  "originalPackageHash": "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
  "packageHashes": {
    "candidate": "sha256:123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef0",
    "baseline": "sha256:abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
  },
  "gradingPlan": [{
    "caseId": "preserves-approval-gate",
    "repetition": 1,
    "assertionId": "clear-handoff",
    "graderId": "clarity-grader"
  }],
  "expected": [{
    "caseId": "preserves-approval-gate",
    "variant": "candidate",
    "repetition": 1,
    "kind": "behavior"
  }, {
    "caseId": "preserves-approval-gate",
    "variant": "baseline",
    "repetition": 1,
    "kind": "behavior"
  }],
  "pairs": [{
    "caseId": "preserves-approval-gate",
    "repetition": 1,
    "candidate": "cases/preserves-approval-gate/1/candidate",
    "baseline": "cases/preserves-approval-gate/1/baseline"
  }]
}
```

Every object has exactly the keys shown. `runId`, `targetSkill`, `mode`, `runs`, baseline
identity, and the six run-configuration fields follow the runner contract. Exactly one of
`model` and `sessionIdentity` is a non-empty string in a resolved manifest; the inactive field is
exactly `null`, never an empty string or another JSON type. `originalPackageHash` is the source
candidate identity captured before preparation. `packageHashes` instead binds the actual copied
package trees: `candidate` is a canonical SHA-256 identity, and `baseline` is a canonical SHA-256
identity except that it is exactly `null` for a no-skill baseline. Every copied package for one
variant must hash to its frozen value. For `baseline.kind: path`, `baseline.identity` is exactly
the same frozen identity as `packageHashes.baseline`; it does not retain a different pre-copy
source-tree hash. An action receipt uses its variant's frozen hash; a grader receipt uses the
candidate frozen hash.

`gradingPlan` contains exactly one entry per frozen qualitative assertion and case/repetition pair,
sorted by case ID, repetition, then assertion ID. `caseId`, `assertionId`, and a resolved
`graderId` are stable kebab-case; `repetition` is one-based and within `runs`. Preparation writes
`graderId: null`, and host orchestration must resolve every null to one stable grader ID before
dispatch or aggregation. Within one case/repetition, each qualitative assertion must resolve to a
distinct `graderId`, so its deterministic input, grade, and receipt names cannot collide. The plan
may not omit or add a qualitative assertion, contain duplicate identities, or select a
case/assertion absent from the frozen definitions.

`expected` is the canonical unique action identity set. Comparative runs contain candidate then
baseline for every pair; an explicitly accepted candidate-only run may omit baseline expected
identities but retains both workspace paths in `pairs`. Each pair has exactly one selected
case/repetition, canonical contained workspace paths, and no concurrency field. `expected`,
`pairs`, and `gradingPlan` retain their required deterministic order even though JSON object member
order is insignificant.

## Action receipts

One append-only action receipt is written last for every expected case/variant/repetition and for
every grader action. Worker action receipts use the deterministic filename
`action.<kind>.<case-id>.<variant>.<repetition>.json`, where `kind` is `behavior` or `trigger`.
Grader action receipts use
`action.grader.<case-id>.<variant>.<repetition>.<grader-id>.json`, with the exact resolved
`gradingPlan` grader ID. All are host-owned names written with create-new semantics. Every receipt
has this exact shape:

```json
{
  "schemaVersion": 1,
  "runId": "20260715T120000Z-1234",
  "caseId": "preserves-approval-gate",
  "repetition": 1,
  "variant": "candidate",
  "kind": "behavior",
  "targetSkill": "woostack-example",
  "baseline": {"kind":"git-ref","identity":"0123456789abcdef0123456789abcdef01234567"},
  "packageHash": "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
  "capabilities": ["read-workspace"],
  "host": "omp",
  "runner": "worker",
  "model": "model-name",
  "sessionIdentity": null,
  "tier": null,
  "effort": null,
  "startedAt": "2026-07-15T12:00:00.000Z",
  "durationMs": 1234,
  "output": {"path":"outputs/final.txt","sha256":"sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","bytes":42},
  "transcript": "unavailable",
  "tokenUsage": "unavailable",
  "selectedSkill": null,
  "completionStatus": "complete",
  "error": null
}
```

`repetition` is one-based. `variant` is exactly `candidate` or `baseline`; `kind` is exactly
`behavior`, `trigger`, or `grader`. `baseline.kind` is `git-ref`, `path`, or `none`, with a
reproducible `identity`. Exactly one of non-empty `model` and non-empty `sessionIdentity` supplies the
completion identity. `tier` and `effort` are strings when exposed and otherwise `null`.
`packageHash` is exactly the manifest's frozen hash for the receipt variant. For `kind: grader`,
it is exactly the frozen candidate hash. A no-skill baseline worker receipt alone uses `null`.
`startedAt` is component-valid RFC 3339 UTC. `durationMs`, every identity byte length, and every
token count is a non-negative JSON safe integer. `output`
identifies a regular evidence file by relative path, SHA-256, and byte length.

`transcript` is either an output identity with the same `{path,sha256,bytes}` shape or the
literal `unavailable`. `tokenUsage` is either `unavailable` or
`{"input":<non-negative integer>,"output":<non-negative integer>,"total":<non-negative integer>}`.
`total` must equal `input + output` without exceeding the JSON safe-integer range.
Materialized evidence JSON and output files are limited to 1 MiB each; exceeding the limit blocks
with `evidence-too-large`. Transcript content is hashed and counted through a stream,
so it is not materialized in aggregate memory.
It is never zero-filled when telemetry is absent. A trigger receipt sets `selectedSkill` to a
canonical skill name or `none`; a behavior or grader receipt sets it to `null`. A completed
grader receipt is host-owned: its case, repetition, and variant map the linked grade's blind
`anonymizedOutputId` back to one manifest identity only after the receipt validates.

`completionStatus` is exactly `complete`, `failed`, or `timed-out`. A complete receipt has
`error: null`; another status has exactly
`{"code":"<stable-kebab-case>","message":"<non-empty sanitized text>"}`. A receipt is not
proof until it is the unique receipt for a manifest identity and all identity/configuration
fields match its paired run.

## Qualitative grades

A grade is append-only and has this exact shape:

```json
{
  "schemaVersion": 1,
  "runId": "20260715T120000Z-1234",
  "caseId": "preserves-approval-gate",
  "repetition": 1,
  "graderId": "clarity-grader",
  "assertionId": "clear-handoff",
  "anonymizedOutputId": "output-7f3a",
  "completionStatus": "complete",
  "pass": true,
  "rationale": "The handoff names the required next action.",
  "error": null,
  "input": {"path":"evidence/input.preserves-approval-gate.candidate.1.clarity-grader.json","sha256":"sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"},
  "receipt": {"path":"evidence/action.grader.preserves-approval-gate.candidate.1.clarity-grader.json","sha256":"sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}
}
```

The grade JSON contains no candidate/baseline label. Its host-owned deterministic filename is
`grade.<case-id>.<variant>.<repetition>.<grader-id>.json`; the host does not present that filename
or variant to the grader/model. Its `receipt.path` must be exactly
`evidence/action.grader.<case-id>.<variant>.<repetition>.<grader-id>.json` for the same resolved
grading-plan identity. `graderId`, `assertionId`, and `anonymizedOutputId` are stable kebab-case
identities. `completionStatus` uses the action receipt enum. On `complete`, `pass` is boolean,
`rationale` is non-empty, and `error` is null. Otherwise `pass` and `rationale` are null and
`error` has the receipt error shape. The aggregate restores the variant only after validating the
linked completed grader receipt against the manifest; it never infers the variant from grade
content.

The host writes the blind input mapping create-new before grader dispatch. Its deterministic
filename is `input.<case-id>.<variant>.<repetition>.<grader-id>.json`; that filename and its
variant are not presented to the grader/model. The mapping has exactly:

```json
{
  "schemaVersion": 1,
  "runId": "20260715T120000Z-1234",
  "caseId": "preserves-approval-gate",
  "repetition": 1,
  "graderId": "clarity-grader",
  "assertionId": "clear-handoff",
  "anonymizedOutputId": "output-7f3a",
  "source": {"path":"outputs/final.txt","sha256":"sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef","bytes":42}
}
```

The grade's exact `{path,sha256}` `input` identity must resolve to that mapping. Its source identity
must exactly equal the validated worker output identity. Before validating any linked grade or
grader receipt, the aggregator indexes every syntactically valid host-owned input mapping,
including orphan mappings and mappings whose later proof fails. Every `anonymizedOutputId` is
globally unique across all cases and repetitions in the run; the candidate and baseline mappings
in one pair therefore always differ. A swapped mapping, reused anonymized ID, wrong source, orphan
input, or mismatched valid grader identity blocks both grades in every affected pair before any
boolean is exposed.

Grader receipts are exempt from the workers' manifest `runConfiguration`. Each linked grader
receipt still has exactly one concrete completion identity (`model` or `sessionIdentity`). For the
candidate and baseline grades sharing one case, repetition, and `graderId`, their validated grader
receipts must match on `host`, `runner`, completion identity, `tier`, and `effort`; a mismatch
blocks aggregation rather than permitting grading bias.

Qualitative unblinding always requires complete candidate and baseline grade, mapping, and grader-
receipt proofs for the pair. This remains true for an accepted candidate-only run: the baseline
worker result is omitted from aggregate cases, but its isolated grading proof is still required to
unblind the candidate grade. A lone candidate proof remains blind rather than becoming paired by
degradation alone.

## Aggregate

The aggregate is versioned and has these top-level fields:

```json
{
  "schemaVersion": 1,
  "runId": "20260715T120000Z-1234",
  "targetSkill": "woostack-example",
  "executionStatus": "complete",
  "baseline": {"kind":"git-ref","identity":"0123456789abcdef0123456789abcdef01234567"},
  "runs": 3,
  "cases": [],
  "overall": {
    "objectivePassRate": {"candidate":1,"baseline":0.67,"delta":0.33},
    "criticalFailures": [],
    "triggerPrecision": "unavailable",
    "triggerRecall": "unavailable",
    "durationMs": {"candidate":{"mean":1234,"variance":12},"baseline":{"mean":1400,"variance":18},"delta":-166},
    "tokenUsage": "unavailable"
  },
  "evidenceErrors": []
}
```

`executionStatus` is exactly `complete`, `blocked`, or `degraded`. Assertion failures may
coexist with `complete`. Missing, duplicate, malformed, failed, timed-out, unknown, or
identity-mismatched required evidence makes the aggregate `blocked`; every comparison, duration,
token, precision, and recall metric is then `unavailable`, while individually proven repetition
evidence remains in `cases`. Explicitly accepted candidate-only smoke evidence is `degraded` and
likewise emits no comparison, duration, token, precision, or recall metric.

Each case entry identifies `caseId`, `kind`, and separate `candidate` and `baseline`
repetition results; each assertion result identifies `assertionId`, `critical`, `pass`, and
its observed evidence identity. Qualitative results additionally preserve `rationale` and
the grade/receipt identities. Rates are numbers from zero through one. Variance is the
literal `unavailable` for one repetition; unavailable duration or token metrics are never
coerced to zero. The aggregate accepts exactly the manifest's expected identities, reports
per-case and overall variance, preserves objective failures separately from execution
failure, and contains no merge verdict.

Aggregate and HTML report publication share one create-new authority at mode `0600`: it writes
and fsyncs a same-directory temporary file, atomically links that file to the requested absent
output path, fsyncs the parent directory, and removes the temporary name on success or failure.
It never overwrites an existing aggregate or report.

`objectivePassRate` uses only deterministic assertion observations from behavior cases. For each
variant, every assertion/repetition observation has equal weight: the rate is passing deterministic
observations divided by all deterministic observations. Trigger outcomes and `qualitative`
assertions, including their pass/fail values, are excluded from both numerator and denominator. A
zero denominator is `unavailable`; delta is candidate minus baseline only when both rates are
numeric.

Duration metrics use completed expected worker receipts of kind `behavior` or `trigger` only;
grader receipt durations are excluded. For each variant and repetition, average all included
worker `durationMs` values into one repetition observation. Overall mean is the arithmetic mean of
those repetition observations, and duration delta is candidate overall mean minus baseline overall
mean when both are numeric. Overall variance is population variance across the repetition
observations, `sum((observation - mean)²) / runs`; with one repetition it is `unavailable`, not
zero. Per-case duration applies the same population formula to that case's one receipt per
repetition.

For trigger metrics, selecting `targetSkill` is the positive prediction; selecting any other
skill or `none` is negative. A `shouldTrigger: true` case is positive ground truth and
`shouldTrigger: false` is negative ground truth. Therefore: TP is positive ground truth with the
target selected; FP is negative ground truth with the target selected; FN is positive ground truth
without the target; TN is negative ground truth without the target. Precision is
`TP / (TP + FP)` and recall is `TP / (TP + FN)`. A zero denominator produces `unavailable`, never
zero. Each metric is computed separately for candidate and baseline from `selectedSkill` receipts,
never transcript prose. Delta is candidate minus baseline only when both values are numeric;
otherwise it is `unavailable`.

`criticalFailures` contains `{caseId,assertionId,repetitions}` entries. `evidenceErrors` uses
exactly `{code,field,path,message}`: `code` is stable kebab-case, `field` is an RFC 6901
pointer (or the empty pointer), `path` is a run-root-relative evidence path, and `message` is
non-empty sanitized text.

Aggregate evidence and fatal snapshot errors use these exhaustive canonical codes and fields:

| Code | Emitted field(s) | Condition |
| --- | --- | --- |
| `missing-receipt` | empty pointer | An expected action receipt or qualitative grade is absent. |
| `duplicate-receipt` | empty pointer | More than one file claims one expected action or qualitative identity. |
| `unknown-receipt` | empty pointer or `/caseId`, `/variant`, `/repetition`, `/kind`, `/assertionId` | A receipt, grade, grader receipt, or input mapping claims no expected identity. |
| `malformed-receipt` | empty pointer or the malformed payload pointer | JSON cannot be parsed, is not an object, has a noncanonical key set, or has an invalid completion/error payload. |
| `missing-field` | the missing field pointer | A required action, grade, nested receipt, or input field is absent. |
| `incomplete-receipt` | `/completionStatus` | A required worker or grader failed or timed out. |
| `missing-completion-identity` | `/model` | Exactly one concrete model or session identity is not present. |
| `configuration-mismatch` | `/host`, `/runner`, `/model`, `/sessionIdentity`, `/tier`, or `/effort` | A worker differs from the manifest run configuration. |
| `grader-configuration-mismatch` | `/host`, `/runner`, `/model`, `/sessionIdentity`, `/tier`, or `/effort` | Paired grader receipts differ on required grading configuration. |
| `grader-identity-mismatch` | `/graderId` | Candidate and baseline grades in a pair use different grader identities. |
| `identity-mismatch` | the mismatched identity or payload pointer | An action receipt, grade, linked receipt, or input path disagrees with its host-owned expected identity, including the resolved grader ID in a grader receipt filename. |
| `missing-grade-receipt` | `/receipt/path` | A grade's deterministic linked `action.grader.<case-id>.<variant>.<repetition>.<grader-id>.json` receipt is absent. |
| `missing-grade-input` | `/input/path` | A grade's deterministic host-owned input mapping is absent. |
| `grade-input-hash-mismatch` | `/input/sha256` | A grade's input hash does not match the host-owned mapping bytes. |
| `grade-input-mismatch` | `/schemaVersion`, `/runId`, `/caseId`, `/repetition`, `/graderId`, `/assertionId`, `/anonymizedOutputId`, or `/source` | A mapping's identity or source provenance differs from its grade and validated worker output. |
| `anonymized-output-collision` | `/anonymizedOutputId` | An anonymized output identity is reused by another grade/mapping anywhere in the run. |
| `grade-receipt-hash-mismatch` | `/receipt/sha256` | A grade's receipt hash does not match the linked grader receipt. |
| `evidence-too-large` | empty pointer, `/output/path`, `/transcript/path`, or `/input/path` | A materialized JSON, output, or input file exceeds the 1 MiB bound. |
| `output-hash-mismatch` | `/output/sha256` | Worker or grader output bytes do not match the receipt hash. |
| `output-bytes-mismatch` | `/output/bytes` | Worker or grader output length does not match the receipt byte count. |
| `transcript-hash-mismatch` | `/transcript/sha256` | Transcript bytes do not match the receipt hash. |
| `transcript-bytes-mismatch` | `/transcript/bytes` | Transcript length does not match the receipt byte count. |
| `package-hash-mismatch` | `/packageHash` | A copied package, worker receipt, or grader receipt differs from the applicable frozen manifest package identity. |
| `unsafe-evidence-path` | `/output/path`, `/transcript/path`, or `/receipt/path` | The referenced path is absolute, escapes the run root, or is otherwise unsafe. |
| `non-regular-evidence` | `/output/path`, `/transcript/path`, or `/receipt/path` | Referenced evidence is missing, a directory, symlink, special file, or unstable regular file. |
| `snapshot-mutation` | empty pointer | Fatal: a snapshotted path, directory identity/name set, opened-handle inode/device/size/mtime, or streamed SHA-256 changes; publication is refused. |
Errors are normalized and sorted by `path`, then `field`, then `code`. A single-fault input emits
only its canonical error; secondary missing/unknown errors for the same rejected receipt are not
added.

## Validator result and errors

`node validate.mjs ... --json` emits one JSON object with exactly `schemaVersion`, `valid`,
`package`, `files`, `corpora`, `packageHash`, and `errors`. `valid` is `errors.length === 0`.
`package` contains normalized `name`, `description`, and package-root-relative `path`;
`files` contains sorted `{path,type,bytes,sha256}` entries where `type` is `skill`,
`reference`, `script`, `asset`, or `eval`; `corpora` contains behavior/trigger presence and
case counts; `packageHash` is a `sha256:` identity or `null` when safe hashing cannot finish.

Every validator error has exactly `{code,field,path,message}`. `field` is an RFC 6901
pointer into the source document (the empty pointer for a whole-file/path failure), `path` is
package-relative, and `message` is non-empty. Errors are sorted by `path`, then `field`, then
`code`. The CLI exits non-zero exactly when `errors` is non-empty. It reports only the
fatal deterministic contracts; root/reference size, TOC, unlinked auxiliary files, degrees
of freedom, and prose quality are not validator errors.
