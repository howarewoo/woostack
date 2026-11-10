Authority: non-authoritative diagnostic evidence

Report only. This file does not authorize scope, assignment, acceptance, lifecycle changes,
repository edits, remediation, or publication. Fill only supported fields; use `unknown`,
`unavailable`, or `not applicable` explicitly. Evidence examples are alternatives, not required calls.

# QA run: {{APP_OR_FOCUS}}: {{DATE}}

## Review identity

- **Assignment and target:** {{scope; URL; environment}}
- **Candidate requested:** {{repository; PR/commit; comparison base; build identity | not supplied}}
- **Candidate observed:** {{verified revision/build and evidence | unknown or mismatch; local changes}}
- **Test context:** {{authorized account role and disposable fixture; no personal identifiers}}
- **Browser and coverage:** {{capability; engine/version; viewport; actual browser zoom; emulated or physical device}}
- **Requirements:** {{acceptance criteria, product documentation, or stated rationale; assumptions}}
- **Optional GitHub context:** {{none | exact independently read canonical PR/issue/Project and read time}}
- **Run bound:** {{journey queue; requested budget or --stop-first; actual ending condition}}
- **Sanitization:** {{passed residual check and time | no retained artifact if sanitization failed}}

## Preflight and summary

| Prerequisite | Observed evidence | Limitation or resume condition |
| --- | --- | --- |
| Reachability | {{result}} | {{gap or none}} |
| Candidate identity | {{result}} | {{gap or none}} |
| Required browser capabilities | {{result}} | {{gap or none}} |

- **Coverage outcome:** {{complete | partial | blocked | aborted}}; {{reason}}
- **Execution:** {{N of M scoped journeys executed; name partially executed journeys}}
- **Confirmed findings:** {{N, with severity/blocking breakdown | not assessed if no journeys ran}}
- **Unconfirmed observations:** {{N}}
- **Remaining risk:** {{missing required coverage, auth/origin boundaries, skipped effects, untested conditions}}
- **Stop point and next step:** {{queue position; condition or actor needed to resume | completed scope}}

A blocked preflight records zero executed journeys and no product verdict. A complete run means
its declared coverage was completed, not that the application is defect-free. No confirmed defects
with missing required coverage is partial or blocked, never blanket acceptance.

## Coverage

Use PASS (expectation observed), FAIL (confirmed contradiction), BLOCKED (prerequisite missing),
NOT RUN (including deferred), UNCONFIRMED (unreproduced anomaly), or SOURCE-ONLY (code inspection,
no UI execution). Split a journey into checks when its results differ. Preserve the original date
and revision for reused evidence; describe what an existing test asserts rather than equating green
with product acceptance.

| Journey/check and risk | Expected behavior and basis | Status | Observation and evidence | Gap or next step |
| --- | --- | --- | --- | --- |
| {{bounded queue item}} | {{expectation; requirement/rationale}} | {{status}} | {{what was actually observed; reference}} | {{limitation or none}} |

## Confirmed findings

Use HIGH / MEDIUM / LOW and a blocking flag, or explain the explicitly required project scale.
Severity describes user impact; scheduling priority is a separate decision. Deduplicate related
symptoms while retaining their distinct impacts. Omit this section if preflight prevented execution.

### {{ID}}. {{SEVERITY}}{{, blocking}}: {{title}}

- **Impact:** {{what a user loses or cannot accomplish}}
- **Context:** {{page; revision/environment/browser/account-role differences from run metadata | same as above}}
- **Preconditions:** {{starting state and synthetic data}}
- **Reproduction:**
  1. {{minimal step}}
  2. {{minimal step}}
- **Reproduction evidence:** {{initial observation and second clean execution; reproduced N of M attempts}}
- **Expected and basis:** {{behavior; acceptance criterion, documentation, or explicit rationale}}
- **Actual:** {{observed behavior; distinguish inaccessible state from missing data}}
- **Evidence:** {{minimum sanitized screenshot/DOM/console/request/state comparison and transient reference}}
- **Cause:** {{verified mechanism with source evidence | hypothesis and confidence | unknown}}
- **Retest criteria:** {{observable repaired behavior; relevant persistence/recovery and nearby boundaries}}
- **Suggested direction (optional):** {{supported bounded suggestion; no authority to edit}}
- **Related issue (optional):** {{exact independently verified canonical URL; read time}}

## Unconfirmed observations

- {{anomaly, user impact, observed frequency, attempted reproduction, and what prevents confirmation | none}}

## Retest and cleanup

- **Fix retest:** {{corrected candidate identity; original repro result; nearby checks | not a fix retest}}
- **Evidence reused:** {{original revision/date; why it still applies | none}}
- **Resources released:** {{task-owned resources released; cleanup limits; unrelated sessions/fixtures preserved}}
- **Evidence limits:** {{unavailable diagnostics, source-only conclusions, emulation, untested conditions}}
