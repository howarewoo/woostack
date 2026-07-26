# Linear increment issue template

This template defines the readable description for one managed `increment` issue in one verified
repository-owned Linear feature project. It is not a local file output. The planner reconciles the
rendered content through official host-exposed Linear MCP and independently reads it back.

## Managed identity

- **Stable client UUID:** `{{INCREMENT_CLIENT_UUID}}`
- **Ordinal:** `{{UNIQUE_POSITIVE_ORDINAL}}`
- **Project:** `{{EXACT_PROJECT_ID_OR_URL}}`
- **Git parent:** `{{PENDING_PROJECT_FROZEN_BASE_REFERENCE_OR_ONE_DEPENDENCY_ISSUE_ID}}`

The stable UUID, not title or ordinal, owns identity. Ordinals are presentation order and never imply
dependency or Git ancestry.

During planning, each dependency root uses the typed unresolved reference
`{"kind":"projectFrozenBase","state":"pending"}`. Immediately before `ready`, after the lifecycle
authority freezes the exact base branch and commit SHA, reconcile every root to
`{"kind":"projectFrozenBase","state":"bound","branch":"{{EXACT_BASE_BRANCH}}","sha":"{{EXACT_40_HEX_SHA}}"}`;
independently read each root and the complete graph back. A pending, wrong, or partially read root
blocks `ready`. Non-root Git parents remain exact native dependency issue IDs.

## Objective

{{ONE_INDEPENDENTLY_SHIPPABLE_OUTCOME}}

## Acceptance criteria

- {{EXACT_ACCEPTANCE_CRITERION_AND_OBSERVABLE_RESULT}}

Every project acceptance criterion maps to at least one increment issue. Preserve explicit happy,
error, edge, success, and failure behavior or record why a class is not applicable.

## Files

- Create: `{{EXACT_PATH}}` — {{SINGLE_RESPONSIBILITY}}
- Modify: `{{EXACT_PATH}}` — {{SINGLE_RESPONSIBILITY}}
- Test: `{{EXACT_PATH}}` — {{OBSERVABLE_CONTRACT}}

## Native dependencies

- Blocked by: `{{STABLE_DEPENDENCY_ISSUE_ID_OR_NONE}}`

Materialize each dependency as a native Linear `blocked by` relation. Reject cycles, foreign or
unknown issues, and graphs with more than one representable Git parent.

## Red → Green → Refactor tasks

- [ ] **Red:** add `{{EXACT_TEST}}` for `{{OBSERVABLE_BEHAVIOR}}`.
- [ ] Run `{{EXACT_COMMAND}}`; expect failure `{{EXACT_FAILURE}}`.
- [ ] **Green:** implement the minimum change in `{{EXACT_PATHS}}`.
- [ ] Run `{{EXACT_COMMAND}}`; expect success `{{EXACT_SUCCESS}}`.
- [ ] **Refactor:** remove duplication or improve names without changing behavior.
- [ ] Run `{{EXACT_VERIFICATION_COMMANDS}}`; expect `{{EXACT_RESULTS}}`.

Use concrete paths, interfaces, commands, cases, and outcomes. Placeholders such as `TBD`, `TODO`,
“similar to,” or an unspecified verification step are invalid in a reconciled issue.

## Automated verification

- Command: `{{EXACT_AUTOMATED_COMMAND}}`
- Expected result: `{{EXACT_MACHINE_CHECKED_RESULT}}`

## Manual verification

- Procedure: `{{EXACT_MANUAL_VERIFICATION_STEPS}}`
- Expected result: `{{EXACT_OBSERVED_RESULT}}`

## Reconciliation contract

Preserve the stable issue identity across replans. Reconcile the exact description, project
membership, native relations, ordinal, work owner, and state; independently read every mutation and
the complete final graph back. Never persist MCP transport input or emit a specification or plan
record to the repository. Refuse deletion or detachment of an issue carrying implementation
evidence and return the conflict to the project lifecycle authority.
