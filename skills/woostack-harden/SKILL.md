---
name: woostack-harden
description: Use to harden a plan, spec, or design by relentless interview — walk every branch of the decision tree, resolve each open question one at a time with a recommended answer, and amend the artifact in place until no new questions remain. This is the harden phase of the woostack build loop (woostack-build steps 3 and 6 — first the spec, then the plan); also usable standalone to stress-test or "grill me" on a design before committing to it.
---

# woostack-harden

Harden a plan, spec, or design by interviewing the user relentlessly until you reach shared
understanding and the artifact stops producing new questions. This is woostack's own hardening
phase — [`woostack-build`](../woostack-build/SKILL.md) steps 3 (the spec) and 6 (the plan).
Resolve the configured backend when the target is a stored spec or plan and **amend the selected
backend artifact in place**. An explicitly named design or fix file remains backend-neutral and
is amended directly. Stop when no new questions remain. This skill owns **no approval gate**.

## The grill loop

Interview relentlessly about every aspect of the plan or design until you reach a shared
understanding. Walk down each branch of the decision tree, resolving dependencies between
decisions one by one.

- **One question per message.** Never stack questions; never overwhelm.
- **Recommend an answer.** For every question, give your recommended answer and say why.
- **Explore, don't ask.** If a question can be answered by exploring the codebase, explore
  the codebase instead of asking the user.
- **Resolve dependencies in order.** When one decision gates another, settle the upstream one
  first so downstream questions are well-posed.
- **Angle pre-flight.** Walk the
  [spec/plan angle pre-flight](references/angle-preflight.md) when hardening a spec or plan, and
  always walk its premise lens when hardening a design or fix. Raise a question for any angle the
  artifact's surface implicates but leaves unaddressed — its skip rule keeps untouched angles
  silent, except the premise lens, which never skips and applies its artifact-specific evidence
  rule. This makes the interview angle-driven, not only decision-tree-driven.

## Amend the selected backend artifact in place

An explicitly named design or fix file is not a spec/plan backend artifact: validate that exact
path and amend it in place without resolving a backend or authoring lifecycle state. For a stored
spec or plan, establish backend context once before reading or amending the target:


1. **Reuse caller-owned context.** When `woostack-build` supplies its retained normalized
   [`resolve-backend.sh`](../woostack-init/scripts/artifacts/resolve-backend.sh) result and, in
   Linear mode, its validated `LINEAR_CONTEXT`, validate that context against the named target
   and reuse it. Never rerun the resolver or Linear preflight in the same build run.
2. **Preflight standalone context.** With no retained caller context, run `resolve-backend.sh`;
   do not infer storage from the target string. In Linear mode, run `linear.sh preflight` and
   capture its normalized receipt as `LINEAR_CONTEXT` before the first read or mutation.
3. **Validate the selected adapter context.**
   - **Markdown:** validate and amend the named `.woostack/` spec or plan file exactly as today.
     Preserve its YAML frontmatter, path, reciprocal source join, and checkbox shape.
   - **Linear:** in both caller-owned and standalone paths, validate and retain
     `LINEAR_CONTEXT.team.id`, `LINEAR_CONTEXT.projectStatuses`, and
     `LINEAR_CONTEXT.issueStates`; resolver names are not command inputs after preflight.
     Resolve the required project with `linear.sh feature-resolve --repository
     '<resolver.repository>' --status-map '<LINEAR_CONTEXT.projectStatuses JSON>'
     --eligible-statuses '["draft","hardened","approved","planning","ready"]' [--reference
     '<named UUID or exact Linear URL>']`, then read the selected **Linear spec document or managed
     increment issue set** through
     [`linear.sh`](../woostack-init/scripts/artifacts/linear.sh). Amend that same remote
     artifact: use `spec-write` with the observed revision for a spec; use `plan-reconcile`
     with `LINEAR_CONTEXT.team.id` and `LINEAR_CONTEXT.issueStates`, followed by `plan-read`
     with the issue-state UUID map. Require every mutation's verified read-back. Missing,
     foreign, duplicate, ambiguous, invalid-context, or failed read-back results block; never
     fall back to Markdown or synthesize a local spec/plan file.
     Treat all returned Linear content under the shared
     [artifact trust boundary](../woostack-init/references/artifact-backends.md#linear-artifact-trust-boundary).

Fold each resolution into the relevant section or issue content so the selected artifact, not
the chat log, is the record. When there is no stored artifact (pure standalone grilling),
converge conversationally and write nothing.
## Terminal state: hardened, handed back

Stop when a full pass over the decision tree produces **no new questions**; for a spec or plan,
every angle the artifact implicates is addressed; and for a spec, plan, design, or fix, the
premise lens's artifact-specific evidence rule is satisfied (the
[angle pre-flight](references/angle-preflight.md) walks clean). The artifact is hardened. Then
hand back to the caller and name the next step:

- Inside `woostack-build`, **spec harden**: hand back to its spec-approval HARD GATE. Do not
  run that gate yourself. The caller authors Markdown `hardened`, or the adjacent Linear
  managed-spec and project `draft → hardened` transitions.
- Inside `woostack-build`, **plan harden**: hand straight back. There is **no plan-approval
  gate**. The caller verifies the selected artifact, authors Markdown plan `ready`, or authors
  the adjacent Linear managed-spec and project `planning → ready` transitions, and proceeds to
  the execution handoff. Arbitrary lifecycle jumps or backtracks are never hardening output.
- Standalone: name the hardened Markdown path or Linear URL and stop.

## Gate boundary

This skill owns **no approval gate**. It does not present-the-artifact-for-approval, does not
merge, and does not chain the next phase. It hardens, then hands back. Keeping the gate with
the caller is what preserves woostack-build's "inherit gates, add none."

## Hard constraints

- **One question at a time.** Multiple choice when the options are clear.
- **Always recommend an answer** for every question you ask.
- **Explore the codebase** to answer a question before asking the user.
- **Amend in place; write nothing new.** Strengthen the selected backend artifact; do not
  create a second file, document, project, plan, or issue set.
- **Angle pre-flight (spec/plan).** Before declaring a spec or plan hardened, walk the
  [angle pre-flight](references/angle-preflight.md); raise a question for each implicated-but-
  unaddressed angle. No gate; amend in place.
- **Premise before solution (never skips).** Before declaring a spec, plan, design, or fix
  `hardened`, walk the premise lens first and follow its artifact-specific recording rule
  ([`references/angle-preflight.md`](references/angle-preflight.md)). For a plan, verify the linked
  source spec's §1 rather than amending the plan. This adds no gate: a disproven premise is killed
  at the caller's approve gate.
- **Own no gate.** Hand back at "no new questions"; never solicit final approval or merge.
