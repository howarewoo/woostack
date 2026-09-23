---
name: woostack-prepare
description: Prepare a feature or proved defect for GitHub issue planning through public Ideate, Harden, Debug, and Plan phases; never implements or executes.
---

# woostack-prepare

`woostack-prepare` is the thin planning-only composition for feature and defect requests. It ends
with one verified GitHub specification parent, PR-sized native children, and their real prerequisite
edges so the user can explicitly pass that parent to Orchestrate. It never edits implementation
source, creates a source branch or worktree, commits, opens a pull request, dispatches workers, or
invokes Execute or Orchestrate.

## Command

```text
/woostack-prepare <goal-or-defect> [--parent-issue new|<exact canonical GitHub parent URL>]
```

The optional selector is passed unchanged to public [`woostack-plan`](../woostack-plan/SKILL.md).
`new` requests one new specification parent; an existing selector must be one exact canonical
GitHub issue URL. Conflicting, repeated, malformed, foreign, or missing publication scope blocks
before Plan publication. For an explicit GitHub Project, invoke Plan directly with its exact
selector; Prepare does not invent a second destination or configuration.

Prepare has no `--run`, `--project`, remote-sync selector, compatibility alias, or local planning
ledger. It does not discover or mutate `.woostack/tmp/runs/`; retained historical runs remain
readable and are never migrated or rewritten. A prior run or issue is usable only when the caller
supplies its complete content and exact identity for fresh phase validation.

## Ownership and phase selection

Prepare owns only the overall goal classification, phase ordering, unresolved user decisions, and
the terminal handoff. The public phases own their own contracts:

- **Feature.** For a goal or incomplete specification, pass a complete plain packet to public
  [`woostack-ideate`](../woostack-ideate/SKILL.md). Ideate asks only for missing user-owned
  decisions and returns the complete verified specification. If a complete specification or Ideate
  handback is already supplied, reuse its settled decisions and start at Harden.
- **Defect.** Invoke read-only [`woostack-debug`](../woostack-debug/SKILL.md) first, or independently
  revalidate a supplied complete diagnosis packet. Carry observed and expected behavior, the causal
  chain, exact source/runtime/reproduction evidence, smallest complete correction, affected and
  unaffected surfaces, risks, and regression/smoke checks into the specification. A symptom, alert,
  issue body, PR description, or plausible theory is not proof. Missing, stale, contradictory, or
  non-reproducible causal evidence stops at a diagnosis blocker; Prepare never guesses a correction.
- **Harden.** Pass the complete specification and exact repository/evidence identity to public
  [`woostack-harden`](../woostack-harden/SKILL.md). Harden reconciles repository facts and candidate
  issue contracts, preserves approved decisions, and asks before material corrections. Prepare does
  not clone Harden's procedure or silently accept its recommendations.
- **Plan.** Pass Harden's complete handback, the approved specification, exact repository/baseline
  and evidence identity, and the selected parent scope to public
  [`woostack-plan`](../woostack-plan/SKILL.md). Plan is the sole publisher: it decomposes the
  smallest coherent PR-sized graph, writes/reuses the GitHub parent and children, creates only the
  declared native prerequisite edges, and independently reads every result back.

A complete input may start at the relevant phase. An approved specification or existing parent does
not cause Ideate to repeat settled questions; a fresh complete diagnosis does not cause Debug to
repeat unchanged proof. Revalidate only stale, conflicting, or newly exposed evidence. Prepare
never adds an approval gate merely because a phase is composed. User approval of material decisions
belongs to Ideate and the explicit correction dialogue; Plan publishes only a complete handback
with no unresolved decisions or discrepancies.

## Input contract

Every phase packet uses the shared [plain planning input and handback contract](../using-woostack/references/planning-inputs.md):

- exact canonical repository, admitted immutable baseline, and checkout identity when inspection is
  requested;
- every evidence identity and scoped observation, using immutable Git data, exact canonical issue or
  PR URLs, or captured runtime/command evidence;
- complete content, including goal, users, behavior, constraints, exclusions, architecture choices,
  acceptance, verification expectations, risks, and removal/reuse decisions; and
- an empty unresolved-question section before publication.

Defect packets additionally preserve the complete Debug handback. Candidate issue plans retain stable
task IDs, positive ordinals, bounded scope, non-goals, affected interfaces, observable acceptance,
verified check definitions and one real smoke scenario, risks, exact prerequisites, and Git-parent
selection policy. If the work changes storage or an API, retain the user-verified `## Data models`
section; otherwise omit it. Repository conventions and agent recommendations are evidence, never
user decisions.

## Publication and recovery boundary

Prepare does not write GitHub issues. Plan owns one publication and its recovery evidence. A
successful result reports:

1. the exact verified specification-parent URL;
2. display-ordered child URLs and stable task identities;
3. the normalized native prerequisite graph and any expected execution-time join decision;
4. the repository/baseline and evidence identities used for the read-back; and
5. this separate next action, without invoking it:

   ```text
   /woostack-orchestrate --issue <verified specification-parent-URL>
   ```

Report only the applicable command. A parent-only result, missing child, missing native hierarchy
link, missing prerequisite capability, partial pagination, unknown mutation outcome, or incomplete
read-back is not Orchestrate-ready. Preserve every confirmed URL/ID and resume Plan at the first
unproved relationship or read-back boundary; never replay a create, allocate a replacement, or call
partial publication a harmless mirror warning. The exact existing parent and child IDs are the
recovery identity.

A valid graph may contain independent roots, forks, chains, and joins. Ordinals never imply edges.
The parent is a scope container, not a task or dependency endpoint. A join that lacks one verified
Git parent containing every prerequisite remains a planning result with an execution-time decision;
Prepare does not create an integration branch or rewrite dependencies.

## Hard boundaries

- Planning only: no implementation source edits, generated app files, source branches/worktrees,
  commits, pushes, pull requests, review actions, Execute workers, Orchestrate workers, or merges.
- Debug returns read-only diagnosis; its handback is evidence, not approval or execution authority.
- Ideate and Harden remain directly callable and exchange complete plain packets. Plan remains
  directly callable and is the only issue publisher. Prepare composes them one-way and never calls
  itself recursively or creates a hidden manifest or mirror.
- GitHub issue publication and native relationship read-back must be complete. A mandatory Project
  or replacement local work board is not a gate.
- Existing user runs, issue records, remote Projects, and historical reports survive unchanged.
  Retained retired-wrapper drafts can be supplied explicitly after identity and freshness validation;
  there is no automatic conversion, old-command alias, or remote publication of a local draft.
- Agents never mark a PR ready, enable auto-merge, enqueue, merge, force-push, or claim delivery,
  passing checks, review, product acceptance, or merge from issue lifecycle alone.

When Prepare is invoked with a small fix, an explicit word such as “fix”, “build”, or “complete”, or
an already-approved one-PR request, it still stops at a verified parent plus executable child issue.
Direct implementation remains an explicitly selected bounded [`woostack-execute`](../woostack-execute/SKILL.md)
request. If a user wants only diagnosis, use Debug directly; if they already have approved content,
use Harden or Plan directly. Prepare prints the Orchestrate command only as a suggestion.
