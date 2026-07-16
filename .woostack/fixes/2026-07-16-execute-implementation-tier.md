---
type: fix
status: executing
branch: fix/execute-implementation-tier
---

# Fix: Keep implementation subagents off the deep tier

## 1. Root Cause

`woostack-execute` routes each implementation task through the effective-tier policy in
`skills/woostack-execute/references/subagent-driver.md`. The implementer prompt declares
`tier: standard`, and the driver repeats that default, but the shared bump-up row permits any role
to escalate directly to `deep` for broad task categories including cross-cutting or architectural
work, ambiguity, and a prior `BLOCKED` result. There is no implementer-specific ceiling, so the
prompt default does not constrain the effective implementation tier. This structurally allows the
reported repeated deep-tier selection whenever tasks match those broad signals.

Evidence:

- `skills/woostack-execute/prompts/implementer.md` declares `tier: standard`.
- `skills/woostack-execute/references/subagent-driver.md` declares the implementer default as
  `standard`, then defines a role-agnostic bump-up to `deep`.
- Existing OMP host/generator tests validate tier-agent generation and routing mechanics, but no
  execute test pins the role-specific implementation tier policy or forbids deep implementation.
- The user explicitly requires implementation to favor `fast`, escalate only when necessary to
  `standard`, and never use `deep`; the current contract contradicts that requirement.

## 2. Proposed Fix

Make the implementation policy role-specific at its shared source:

- Change the implementer prompt default from `standard` to `fast`.
- Change the driver tier-selection contract so implementers start at `fast` and use `standard`
  only for tasks whose risk or reasoning needs justify it: security/auth/crypto, data migrations,
  concurrency/locking, money/billing, cross-cutting/architectural work, highly ambiguous task
  text, or a prior `fast`-tier `BLOCKED` result that specifically needs more reasoning.
- Make `standard` the hard implementation ceiling. A `standard` implementer that remains blocked
  must receive missing context, have the task split, or escalate the plan to the user; it must not
  retry at `deep`.
- Preserve reviewer policy: spec-compliance review may use `fast` or `standard`, while non-trivial
  code-quality review may continue to use `deep`. This change targets implementation only.
- Add one structural regression test under `skills/woostack-execute/scripts/tests/` that pins the
  implementer default, the `fast` to `standard` ceiling, the absence of an implementation-to-deep
  path, and the unchanged reviewer tiers. The existing test runner discovers the file
  automatically, so no runner wiring is needed.

No shared model mappings, OMP agent definitions, authored site pages, or overnight-specific rules
change: `woostack-execute-overnight` consumes the same execute driver, and the authored site does
not state the role-level tier heuristic. Keep the high-level `woostack-execute/SKILL.md` dispatch
summary in lockstep with the role-specific driver contract.

## 3. Implementation Plan

- [x] **Step 1: Reproduce with a failing contract test**
  - Add `skills/woostack-execute/scripts/tests/test-subagent-tier-selection.sh` using the existing
    assertion helpers.
  - Assert the implementer prompt frontmatter is `tier: fast`.
  - Assert the driver declares implementer `fast`, maps the enumerated risk/reasoning signals and
    a reasoning-blocked `fast` attempt to `standard`, and explicitly prohibits `deep` for
    implementation.
  - Assert a `standard` implementer that remains blocked routes to context repair, task splitting,
    or user escalation rather than another tier bump.
  - Assert the execute skill summary states the fast implementation default and standard ceiling.
  - Assert reviewer defaults remain spec-reviewer `standard` and quality-reviewer `deep`, with the
    existing trivial-diff reviewer downgrades preserved.
  - Run the test before the policy edits and observe failure against the current `standard` default
    and role-agnostic deep bump-up.
- [x] **Step 2: Apply the minimal policy fix**
  - Update `skills/woostack-execute/prompts/implementer.md` frontmatter to `tier: fast`.
  - Rewrite only the tier-selection paragraph/table in
    `skills/woostack-execute/references/subagent-driver.md` to separate implementation escalation
    from reviewer selection: implementer `fast` by default, `standard` only for the enumerated
    risk/reasoning signals, never `deep`; a blocked `standard` attempt routes to context repair,
    task splitting, or user escalation; reviewer behavior remains unchanged.
  - Update `skills/woostack-execute/SKILL.md` to summarize the fast implementation default and
    standard ceiling while continuing to link the driver as the detailed authority.
  - Leave the canonical tier-to-model mappings and host routing mechanics untouched.
- [x] **Step 3: Verification**
  - Run `bash skills/woostack-execute/scripts/tests/test-subagent-tier-selection.sh` and confirm the
    targeted policy contract passes.
  - Run `bash skills/woostack-execute/scripts/tests/run-tests.sh` to confirm all execute subagent
    contract tests pass.
  - Run `bash skills/woostack-init/scripts/tests/test-gen-omp-agents.sh` to confirm shared tier-agent
    generation remains intact.
