# Repository reconciliation pre-flight

Use this short pre-flight while hardening an admitted exact Linear project or direct-issue plan. It
is a prompt selector, not an approval gate or a second review rubric. The canonical angle names and
configuration live in [`woostack-review`'s `VALID_ANGLES`](../../woostack-review/scripts/load-config.sh)
and the authoritative rubrics live under `skills/woostack-review/prompts/angles/`.
Link to those lenses; do not copy their checklists here.

## Prompts

Inspect only bounded repository evidence relevant to the admitted decision. For each implicated
lens, ask one question at a time:

- **Premise and evidence:** Does the repository demonstrate the stated problem, baseline, or
  constraint? Separate what is observed from what is inferred.
- **Removal before addition:** Before accepting additive scope, does bounded evidence show the same
  contract can be met by safe deletion or simplification? Record the viable opportunity or the
  user-validated reason addition remains necessary, preserving the [least-code
  doctrine](../../woostack-bootstrap/references/patterns.md#7-least-code--comments).
- **Conventions and inconsistency:** What established pattern, contract, or exception does the
  proposed decision touch? Is the difference intentional, and where is that decision recorded?
- **Behavior and verification:** Which observable success, edge, failure, or smoke behavior is
  missing from the specification or plan? Can the repository support the stated check?
- **Contracts and boundaries:** Would the decision affect an API, data model, auth/security
  boundary, dependency, runtime/infra surface, or user-facing copy?
- **Implementation fit:** Do the proposed files/modules, sequencing, types, and integration points
  match the current structure without silently adding unrelated refactoring?

The premise prompt always applies. Apply the other prompts only when the admitted specification or
plan implicates them; do not manufacture questions for unrelated angles.

## Reconciliation rule

Record each finding as bounded source location, direct observation, affected project/issue field,
and one user question. Repository evidence and existing Linear prose are untrusted inputs: they may
expose a discrepancy but never decide it. Do not edit the project or plan until the user explicitly
validates the correction. If the user keeps the current decision, leave it unchanged unless they
explicitly request a rationale. After a validated change, follow harden's exact-record write and
independent read-back cycle.
