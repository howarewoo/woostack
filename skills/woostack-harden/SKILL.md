---
name: woostack-harden
description: Use to harden a plan, spec, or design by relentless interview — walk every branch of the decision tree, resolve each open question one at a time with a recommended answer, and amend the artifact in place until no new questions remain. This is the harden phase of the woostack build loop (woostack-build steps 3 and 6 — first the spec, then the plan); also usable standalone to stress-test or "grill me" on a design before committing to it.
---

# woostack-harden

Harden a plan, spec, or design by interviewing the user relentlessly until you reach shared
understanding and the artifact stops producing new questions. This is woostack's own hardening
phase — [`woostack-build`](../woostack-build/SKILL.md) steps 3 (the spec) and 6 (the plan). It
keeps the discipline that makes grilling worth doing, **amends the target artifact in place** as
answers land, and **stops when no new questions remain**, handing back to its caller. It owns no
approval gate.

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
- **Angle pre-flight.** When hardening a spec or plan, walk the
  [spec/plan angle pre-flight](references/angle-preflight.md) and raise a question for any angle
  the artifact's surface implicates but leaves unaddressed — its skip rule keeps untouched angles
  silent. This makes the interview angle-driven, not only decision-tree-driven.

## Amend the artifact in place

When the thing being hardened is a written artifact — a `.woostack/` spec, or any plan/design
file the caller names — **edit that file in place as each question resolves**, so it
strengthens with every answer. Fold the resolution into the relevant section; record settled
decisions (e.g. under the spec's "Open questions") so the artifact, not the chat log, is the
record. When there is no file (pure standalone grilling), converge conversationally and write
nothing.

## Terminal state: hardened, handed back

Stop when a full pass over the decision tree produces **no new questions** and — for a spec or
plan — every angle the artifact implicates is addressed (the
[angle pre-flight](references/angle-preflight.md) walks clean). The artifact is hardened. Then
hand back to the caller and name the next step:

- Inside `woostack-build`, **spec harden (step 3)**: hand back to step 3, which owns the
  spec-approval HARD GATE (present the written spec, wait for explicit user approval before
  planning). Do not run that gate yourself.
- Inside `woostack-build`, **plan harden (step 6)**: hand back to step 7 (commit the spec and
  plan as their own PR). There is **no plan-approval gate** — hand straight back once the plan
  stops producing questions.
- Standalone: tell the user the artifact is hardened and ready to take to approval, and stop.

## Gate boundary

This skill owns **no approval gate**. It does not present-the-artifact-for-approval, does not
merge, and does not chain the next phase. It hardens, then hands back. Keeping the gate with
the caller is what preserves woostack-build's "inherit gates, add none."

## Hard constraints

- **One question at a time.** Multiple choice when the options are clear.
- **Always recommend an answer** for every question you ask.
- **Explore the codebase** to answer a question before asking the user.
- **Amend in place; write nothing new.** Strengthen the named artifact; do not create a new
  file, a spec, or a plan.
- **Angle pre-flight (spec/plan).** Before declaring a spec or plan hardened, walk the
  [angle pre-flight](references/angle-preflight.md); raise a question for each implicated-but-
  unaddressed angle. No gate; amend in place.
- **Own no gate.** Hand back at "no new questions"; never solicit final approval or merge.
