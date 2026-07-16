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

## Action receipts

One append-only action receipt is written last for every expected
case/variant/repetition. Its exact shape is:

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
`behavior` or `trigger`. `baseline.kind` is `git-ref`, `path`, or `none`, with a reproducible
`identity`. Exactly one of non-empty `model` and non-empty `sessionIdentity` supplies the
completion identity. `tier` and `effort` are strings when exposed and otherwise `null`.
`startedAt` is RFC 3339 UTC, `durationMs` is a non-negative finite integer, and `output`
identifies a regular evidence file by relative path, SHA-256, and byte length.

`transcript` is either an output identity with the same `{path,sha256,bytes}` shape or the
literal `unavailable`. `tokenUsage` is either `unavailable` or
`{"input":<non-negative integer>,"output":<non-negative integer>,"total":<non-negative integer>}`.
It is never zero-filled when telemetry is absent. A trigger receipt sets `selectedSkill` to a
canonical skill name or `none`; a behavior receipt sets it to `null`.

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
  "receipt": {"path":"evidence/action.grader.preserve-approval-gate.1.clarity-grader.json","sha256":"sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"}
}
```

The grade contains no candidate/baseline label. `graderId`, `assertionId`, and
`anonymizedOutputId` are stable kebab-case identities. `completionStatus` uses the action
receipt enum. On `complete`, `pass` is boolean, `rationale` is non-empty, and `error` is null.
Otherwise `pass` and `rationale` are null and `error` has the receipt error shape. The
aggregate restores the variant only through the manifest and completed grader receipt.

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
    "durationMs": {"candidate":{"mean":1234,"variance":12},"baseline":{"mean":1400,"variance":18}},
    "tokenUsage": "unavailable"
  },
  "evidenceErrors": []
}
```

`executionStatus` is exactly `complete`, `blocked`, or `degraded`. Assertion failures may
coexist with `complete`. Missing, duplicate, malformed, failed, timed-out, unknown, or
identity-mismatched required evidence makes the aggregate `blocked`. Explicitly accepted
candidate-only smoke evidence is `degraded` and emits no comparison or trigger metric.

Each case entry identifies `caseId`, `kind`, and separate `candidate` and `baseline`
repetition results; each assertion result identifies `assertionId`, `critical`, `pass`, and
its observed evidence identity. Qualitative results additionally preserve `rationale` and
the grade/receipt identities. Rates are numbers from zero through one. Variance is the
literal `unavailable` for one repetition; unavailable duration or token metrics are never
coerced to zero. The aggregate accepts exactly the manifest's expected identities, reports
per-case and overall variance, preserves objective failures separately from execution
failure, and contains no merge verdict.

`criticalFailures` contains `{caseId,assertionId,repetitions}` entries. `evidenceErrors` uses
exactly `{code,field,path,message}`: `code` is stable kebab-case, `field` is an RFC 6901
pointer (or the empty pointer), `path` is a run-root-relative evidence path, and `message` is
non-empty sanitized text.

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
