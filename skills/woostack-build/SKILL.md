---
name: woostack-build
description: Use when building a feature with the full woostack development loop — ideate a design, harden it, plan it, harden the plan, ship the selected artifact backend's spec and plan, then implement it through exactly three gates.
---

# woostack-build

## Overview

Drives one feature from idea to the selected backend's supported terminal state through a fixed,
gated chain. Thin glue: it sequences proven sub-skills and routes spec/plan reads and writes
through the configured artifact backend. It **inherits two gates** (design and written-spec
approval) and **adds exactly one** (the execution handoff). Storage changes neither their order
nor their meaning.

At the start of the run, execute
`skills/woostack-init/scripts/artifacts/resolve-backend.sh <repo-root>` exactly once and
retain its normalized JSON result. Branch on its `backend` value; never infer the backend
from folders, arguments, or available credentials, and never fall back from Linear to
Markdown.

Both branches implement the same pre-execution chain:

```
ideate → capture spec → harden + persist spec → spec approval → plan
  → verify decomposition → harden plan → mark ready → execution handoff
```

Either backend may continue from that gate into per-increment execution and a reviewed PR stack.
Markdown preserves its existing persistence order:
`commit spec PR → approve spec → plan → append plan to spec+plan PR → execution handoff`.
Linear passes its managed project and issue identities directly to execution and creates no
docs-only base PR.

The only hard stops are **design approval**, **spec approval**, and **execution handoff**.
Hardening amends the selected artifact in place and owns no gate. Planning, persistence,
read-back, lifecycle transitions, and Markdown's spec/plan PR are work steps, not approval
stops.

Lifecycle spelling is backend-specific: Markdown plan frontmatter uses `in-review`; the
normalized Linear project/issue status is `inReview`. Never translate one storage token into
the other.

## Procedure

1. Resolve the selected artifact backend with
   [`resolve-backend.sh`](../woostack-init/scripts/artifacts/resolve-backend.sh). Keep the
   returned repository identity and resolved Linear configuration for adapter calls. Then
   follow exactly one procedure below.

## Markdown backend procedure

{/* <!-- markdown-gates: design-approval | spec-approval | execution-handoff --> */}

<HARD-GATE backend="markdown" name="design-approval">

1. **Ideate.** Invoke [`woostack-ideate`](../woostack-ideate/SKILL.md) to explore
   the problem and converge on a design. Let it run its own approval gate. It hands back an
   approved design and stops there — it writes no spec and chains no plan, so the next steps
   are yours to drive.
   The design phase loads `.woostack/wisdom/*.md` wholesale as guidance (via `woostack-ideate`'s
   context exploration); see the wisdom contract
   [`../woostack-init/references/wisdom.md`](../woostack-init/references/wisdom.md).
</HARD-GATE>
2. **Write the spec as markdown.** When the design is approved, do **not** write to a generic
   `docs/specs/` location. **First create the spec+plan worktree** (the first write of this run,
   per the [worktree contract](../woostack-init/references/worktrees.md)): pick the branch
   `feature/<slug>`, then `git worktree add -b feature/<slug>
   "$WOOSTACK_ROOT/.woostack/worktrees/feature-<slug>" "$(bash <wi>/resolve-base.sh)"`, run
   `gt track --parent "$(bash <wi>/resolve-base.sh)"` from inside that worktree, and run
   **steps 2–7 with cwd = that worktree** — the spec, the `woostack-plan` plan, and both hardens
   author into it, never the primary tree. (On abandon at the spec gate, `git worktree remove
   --force` it and delete the branch.) Instead author a markdown spec to
   `.woostack/specs/YYYY-MM-DD-<slug>.md`, populating
   [references/spec-template.md](references/spec-template.md). Markdown specs are the source
   of truth: they carry `type: spec` frontmatter, are Obsidian vault nodes that can `[[link]]`
   memory notes, and are excluded from memory recall routing by type. **Visualize on demand** —
   if a rich view is wanted, hand the markdown to
   [`woostack-visualize`](../woostack-visualize/SKILL.md) (audience `engineer` for specs; it
   uses [references/spec-template.html](references/spec-template.html) as a starting point).
   The HTML is a presentation target only, never the authored source. Set the spec's
   `status: draft` in frontmatter — the build loop owns the `status:` enum and authors a
   transition at each step so `/woostack-status` can read it (the enum and join contracts live
   in [`../woostack-status/references/conventions.md`](../woostack-status/references/conventions.md);
   link it, do not restate it).
<HARD-GATE backend="markdown" name="spec-approval">

3. **Harden the spec, commit it for review, then get spec approval.** Invoke
   [`woostack-harden`](../woostack-harden/SKILL.md) against the spec. Amend the spec
   in place until hardening stops producing new questions, then set `status: hardened`. **Then
   commit the spec before the gate** so the user reviews it in a PR, not as a raw worktree file:
   from inside the `feature/<slug>` worktree, commit the `.woostack/specs/` markdown via
   [`woostack-commit`](../woostack-commit/SKILL.md) on the existing `feature/<slug>` branch and
   submit it — this opens the spec+plan base PR, **initially spec-only** (the plan is appended in
   step 7; it is the same base PR, not a separate one). Then **always present the spec to the user
   and get explicit approval before planning** — this is a hard gate. Point the user at the **PR
   URL** (the committed spec; offer the file path or a `woostack-visualize` render if it helps),
   wait for a clear yes, and make any requested changes before advancing.
   - **Go** → set `status: approved` (the worktree stays alive; steps 4–7 plan into it and step 7
     appends the plan to this same PR).
   - **Revise** → amend the spec in the still-alive worktree, **commit the revision** on the same
     `feature/<slug>` branch (so the PR reflects it), and re-present at the gate.
   - **Abandon** → `git worktree remove --force` the worktree, delete the `feature/<slug>` branch,
     and **close the now-open PR**.
   Do **not** proceed to step 4 on inferred or assumed approval; silence is not a yes. Committing
   the spec here is a work step; it adds no gate.
</HARD-GATE>
4. **Plan.** Once the spec is approved, invoke
   [`woostack-plan`](../woostack-plan/SKILL.md) with the approved spec path. It writes the
   plan to `.woostack/plans/<spec-basename>.md` with YAML frontmatter followed by the
   `**Source:** [[specs/<basename>]]` wikilink line so status and doctor join it 1:1, structures
   it as PR-sized increments, and sets the plan's `status: planning`. It writes the plan and
   ships in this collection, so the build loop has no external skill dependencies.
5. **Verify the increment decomposition.** `woostack-plan` already structures the plan as
   PR-sized increments; build confirms the increment boundaries are reviewable, independently
   shippable, and feed cleanly into `woostack-execute`. Flag any slice that is not reviewable
   or independently shippable and propose a further split before executing. The
   `spec : plan : PRs = 1 : 1 : N` invariant holds throughout: exactly one plan per spec, and
   that one plan owns the N increment PRs.
6. **Harden the plan.** Invoke [`woostack-harden`](../woostack-harden/SKILL.md) again, this
   time against the plan and its increment breakdown — stress-test the sequencing, the
   increment boundaries, and the verifications until hardening stops producing new questions.
   Amend the plan markdown in place as answers land. This adds **no approval gate**: harden
   owns none and hands straight back. The chain's last hard stop is the **execution-handoff
   gate (step 8)**, after the spec+plan PR — not a plan-*quality* gate here. Do not turn this
   harden into a plan-approval gate. When hardening stops producing new questions, set the
   plan's `status: ready` — the [conventions.md](../woostack-status/references/conventions.md)
   value for "plan hardened, ready for execution" (mirroring step 3's `hardened`, but for the
   plan). Plans own implementation lifecycle, so this transition is authored on the **plan**, not the spec.
7. **Append the plan to the spec+plan PR.** The spec was already committed and its PR opened in
   step 3, so this step **adds the plan to that same PR** — it does not open a second one. Before
   any implementation, commit the `.woostack/` plan via
   [`woostack-commit`](../woostack-commit/SKILL.md) onto the **same** `feature/<slug>` branch,
   updating the existing PR so it now carries the spec **and** the plan. This docs-only PR is the
   **base of the stack** — execution increments (step 9) stack on top of it via `gt create`. It
   carries no code and is **never merged** by build. This is a work step, not an approval stop. The
   commit happens inside the spec+plan worktree via `woostack-commit`; after the plan is committed,
   **teardown** the worktree
   (`git worktree remove "$WOOSTACK_ROOT/.woostack/worktrees/feature-<slug>"`) — the branch/commits/PR
   persist as the stack base. Leave the worktree on failure and report its path
   ([worktree contract](../woostack-init/references/worktrees.md)).
<HARD-GATE backend="markdown" name="execution-handoff">

8. **Stop before execute (execution-handoff gate).** After the spec+plan PR is open, **halt** —
   this is a hard gate. Surface the handoff artifacts: the plan path (`.woostack/plans/…`), the
   spec+plan PR URL, and — on request — a
   [`woostack-visualize`](../woostack-visualize/SKILL.md) render of the plan (audience
   `engineer`). Then ask the user to choose:
   - **Go** → proceed to step 9 and run `woostack-execute` in this session.
   - **Run overnight** → proceed to step 9 but run
     [`woostack-execute-overnight`](../woostack-execute-overnight/SKILL.md) instead: it drives the
     whole plan **unattended** (autonomous, no further input) and leaves a morning report under
     `.woostack/overnight/` for you to test. Use this to let a well-made plan run overnight.
   - **Hand off** → stop here. The user takes the plan PR and executes later or elsewhere (e.g.
     Codex, or a fresh session via `/woostack-execute <plan-path>`).
   Ambiguous or no answer is **not** a "go": never auto-run execute (supervised or overnight)
   without an explicit go-ahead. This is the chain's last hard gate.
</HARD-GATE>
9. **Execute.** Invoke [`woostack-execute`](../woostack-execute/SKILL.md) — or, if the user chose
   **Run overnight** at step 8, [`woostack-execute-overnight`](../woostack-execute-overnight/SKILL.md)
   (unattended) — with the plan path to
   work the plan as PR-sized stacked increments on top of the spec+plan PR — each implemented
   with TDD (the [woostack-tdd kernel](../woostack-tdd/SKILL.md)), the plan's checkboxes
   ticked in place, committed via `woostack-commit`, reviewed per
   the execution mode the active driver selects (`woostack-execute`: shared task-level
   spec-compliance and code-quality checks, performed inline by the controller or by reviewer
   subagents depending on mode; `woostack-execute-overnight` drives its own autonomous review
   policy), and distilled into
   `.woostack/memory/` — `woostack-execute` pausing on a blocking stop, `woostack-execute-overnight`
   instead logging the blocker and continuing per its halt policy. `woostack-execute` owns the
   per-increment commit/review/distill cadence and the inline-vs-subagent mode choice (one plan
   per spec, multiple stacked PRs per plan), so it absorbs what used to be separate "distill
   memory" and "offer the PR" steps here. As branches, commits, and increment PRs appear the
   plan advances into the `executing` → `in-review` band; `woostack-execute` authors the plan's
   terminal `status: done` at the final increment (so the authored value no longer lags), while the
   board still **computes** that band from the artifacts via its truth table — showing `in-review`
   until the final PR merges, then `done` — so any still-lagging authored `status:` is reconciled
   rather than trusted blindly.
10. **End on the chosen terminal state.** Build ends in one of three shapes, never merging any:
    - **Hand off** → only the spec+plan PR is open (no increment PRs), ready for external or
      later execute.
    - **Go** → a Graphite stack with the spec+plan PR at the base and a reviewed increment PR
      above each step.
    - **Run overnight** → an autonomous `woostack-execute-overnight` run: a reviewed (or partially
      reviewed, blockers logged) stack — linear or tree-stacked across `## Track:`s — plus a
      morning report under `.woostack/overnight/`.
    Build does not separately ask to open a PR (step 7 and the execute phase open them as work
    steps) and **never merges**.

### Markdown hard constraints (preserved)

- **Inherit two gates, add one.** Do not insert *extra* approval stops beyond the three hard
  gates: **design approval** (step 1) and **spec approval** (step 3), both inherited, plus the
  **execution handoff** (step 8), which build owns because the plan→execute boundary belongs to
  no sub-skill. The spec commit (step 3), the plan harden (step 6), and appending the plan to the
  spec+plan PR (step 7) are work steps, not gates.
- **Harden twice, neither harden gates.** Harden the spec (step 3, feeds the spec-approval gate)
  and the plan (step 6, amends in place, no gate). The execution-handoff gate (step 8) is
  separate and build-owned, not a plan-*quality* gate; never turn the plan harden into a
  plan-approval gate.
- **Always get explicit spec approval before planning.** After the spec harden, present the
  written spec and wait for the user's clear yes. Never advance to `woostack-plan` on assumed
  or inferred approval.
- **Markdown specs and plans, under `.woostack/`.** Never write specs to a generic location
  outside `.woostack/`. HTML is a render-on-demand target only, not the authored format.
- **Commit the spec before its approval gate.** After the spec harden (step 3), commit the
  `.woostack/specs/` markdown on the `feature/<slug>` branch and open the base PR **before** asking
  for spec approval, so the user reviews the spec in the PR rather than a raw worktree file
  (mirroring [`woostack-fix`](../woostack-fix/SKILL.md)). Revisions at the gate are committed
  before re-presenting; Abandon closes the now-open PR. This is a work step — it adds no gate, so
  the chain still has exactly the three hard gates.
- **Spec+plan ship as their own PR before execution.** The spec is committed at the gate (step 3)
  and the plan appended to the **same** docs-only PR (step 7) — the base of the stack — before any
  implementation begins. One PR, not two; never merge it.
- **Stop before execute.** Never auto-run execute — supervised `woostack-execute` or unattended
  `woostack-execute-overnight`; always halt at the execution-handoff gate (step 8) after the
  spec+plan PR and let the user choose Go / Run overnight / Hand off. The plan PR is the artifact
  for executing here or in another tool. Ambiguous or no answer is not a "go."
- **Never merge.** build ends on the terminal state (handoff PR, or reviewed stack), nothing
  further.
- **Author status on the owning Markdown artifact.** Follow the canonical lifecycle and ownership
  rules in
  [`../woostack-status/references/conventions.md`](../woostack-status/references/conventions.md).
  The local spec-gate `Abandon` path closes the open PR, then removes the temporary branch and
  worktree; because no Markdown artifact survives, do not create a status-only abandonment
  commit. Otherwise write each transition only on the artifact that owns it.
- **One increment per cycle.** Do not let a single build cycle balloon past a reviewable PR.
- **Distill durable knowledge only.** `woostack-execute` writes scoped, deduplicated memory
  notes per increment — never feature-specific trivia, never a duplicate of an existing note. A
  small curated store beats a large noisy one.

## Linear backend procedure

{/* <!-- linear-gates: design-approval | spec-approval | execution-handoff --> */}

All Linear operations below use
[`linear.sh`](../woostack-init/scripts/artifacts/linear.sh); cross-link its commands rather
than embedding GraphQL, endpoint calls, or transport behavior. Every mutation must return a
verified mandatory read-back receipt. A failed or incomplete receipt blocks the next step.
Treat every returned Linear artifact under the shared
[artifact trust boundary](../woostack-init/references/artifact-backends.md#linear-artifact-trust-boundary).

<HARD-GATE backend="linear" name="design-approval">
1. **Ideate.** Invoke
   [`woostack-ideate`](../woostack-ideate/SKILL.md). It writes no artifact and stops until the
   user explicitly approves the design. Silence or ambiguity does not clear the gate.
</HARD-GATE>
2. **Preflight, capture run context, discover, then capture the spec.** Before the first
   mutation of the run, invoke `linear.sh preflight` with the resolver's configured workspace,
   team name/key, project-status names, and issue-state names. Capture its normalized receipt
   as `LINEAR_CONTEXT`; validate that it contains exactly the resolved workspace UUID, team
   UUID, complete semantic project-status UUID map, and complete semantic issue-state UUID map.
   Then extract and retain `LINEAR_TEAM_ID="$(jq -r '.team.id' <<<"$LINEAR_CONTEXT")"`,
   `LINEAR_PROJECT_STATUSES="$(jq -c '.projectStatuses' <<<"$LINEAR_CONTEXT")"`, and
   `LINEAR_ISSUE_STATES="$(jq -c '.issueStates' <<<"$LINEAR_CONTEXT")"`. The resolver's names
   are preflight input only; every later adapter command uses these extracted UUID values as
   `--team-id`, `--status-map`, and `--issue-state-map`. Invoke `linear.sh feature-resolve`
   with the repository marker, `"$LINEAR_PROJECT_STATUSES"`, eligible semantic statuses, and
   any explicit Linear UUID/URL supplied by the user.
   - Across sessions, an explicit UUID or exact Linear URL wins. Without one, continue only
     when discovery returns **exactly one eligible managed project** for this repository. Zero
     means create; multiple candidates require explicit selection and no mutation.
   - For a new feature, render the approved design with the backend-neutral sections in
     [references/spec-template.md](references/spec-template.md), then invoke
     `linear.sh feature-create` with `"$LINEAR_TEAM_ID"` and
     `"$LINEAR_PROJECT_STATUSES"`. It creates one project in `draft`, one managed
     `designState: draft` spec document, and verifies both by discovery/read-back.
   - Resume never adopts by title. There must be **one managed Linear project, exactly one
     managed spec document, and one ordered managed issue set** for the feature.
   Linear mode creates **no spec/plan worktree, branch, commit, or docs-only PR**. It writes no
   `.woostack/specs/` or `.woostack/plans/` source file.
<HARD-GATE backend="linear" name="spec-approval">
3. **Harden and approve the Linear spec.**
   Invoke `linear.sh spec-read`, harden that selected document through `woostack-harden`, and
   persist each revision with `linear.sh spec-write` using the last observed revision. On the
   final verified write, change the managed metadata only from `designState: draft` to
   `designState: hardened`; then invoke `linear.sh feature-transition` from `draft` to
   `hardened` and require its mandatory read-back receipt. Present the managed spec document
   URL and wait:
   - **Go** → read again, use evidence-aware `linear.sh spec-write` to change only
     `designState: hardened` to `designState: approved`, verify it, invoke
     `linear.sh feature-transition` from `hardened` to `approved`, verify the project read-back,
     then plan.
   - **Revise** → read again with `linear.sh spec-read`, amend the same document, write with
     `linear.sh spec-write` and its optimistic revision without changing `designState:
     hardened`, require read-back, and re-present. The project remains `hardened`.
   - **Abandon** → read again, use `linear.sh spec-write` to change the managed lifecycle to
     `designState: abandoned`, verify it, invoke `linear.sh feature-transition --target
     abandoned`, require project read-back, preserve the project/document audit history, and
     stop. Never delete or archive it.
   Failed read-back, ambiguity, or silence never advances the gate.
</HARD-GATE>
4. **Plan in Linear.** Invoke [`woostack-plan`](../woostack-plan/SKILL.md) with the selected
   project UUID or exact Linear URL plus the retained resolver result and `LINEAR_CONTEXT`.
   The planning skill owns the complete Linear planning procedure and reuses that normalized
   caller context without resolving or preflighting again. Continue only after it hands back the
   same owned project and spec in `planning` with the managed increment issues reconciled and
   verified.
5. **Verify and read back the plan.** Invoke `linear.sh plan-read` with
   `"$LINEAR_ISSUE_STATES"` and reject missing or duplicate ordinals, cycles, cross-project
   dependencies, native/metadata relation drift, unreviewable slices, uncovered ACs, or Git
   ancestry that Graphite cannot represent. Replanning must preserve stable issue identities
   and implementation evidence, may safely add/reorder/rewire, and must **refuse to remove an
   issue with branch or pull-request evidence**.
6. **Harden the plan in place.** Invoke `woostack-harden` against the selected ordered issue
   set. Reconcile changes with `linear.sh plan-reconcile` using `"$LINEAR_TEAM_ID"` and
   `"$LINEAR_ISSUE_STATES"`, then verify with `linear.sh plan-read`. This adds no approval gate.
   Only a clean read-back permits another `linear.sh spec-read` plus evidence-aware
   `linear.sh spec-write` to author `designState: planning → ready`, followed by the project
   `planning → ready` through `linear.sh feature-transition` using
   `"$LINEAR_PROJECT_STATUSES"` and another mandatory read-back receipt.
7. **Freeze the execution base.** **Immediately before the execution-handoff gate**, resolve
   the base branch with
   [`resolve-base.sh`](../woostack-init/scripts/resolve-base.sh) and resolve its exact commit
   SHA. Read the spec with `linear.sh spec-read`, write exactly the canonical `baseBranch`,
   `baseCommitSha`, and `designState: ready` fields into its owned metadata with
   `linear.sh spec-write --issue-state-map "$LINEAR_ISSUE_STATES"` using the observed revision,
   then call `linear.sh feature-read` with both extracted UUID maps and require those exact
   values in its normalized read-back. No lifecycle or artifact mutation may intervene
   between this verified freeze and the gate. The pair is provisional while `designState` is
   `ready`: an accidental `ready → ready` pair change fails closed, but explicit pre-execution
   replanning may replace it only while every managed increment has null `branch` and
   `pullRequest`.
   - **Explicit replan sequence:** call `linear.sh plan-read` and verify that live evidence is
     empty, then call `linear.sh spec-read` and retain its `.revision`. Call
     `linear.sh feature-transition --target planning --replan --expected-revision
     '<revision-json>'` with `"$LINEAR_PROJECT_STATUSES"` and `"$LINEAR_ISSUE_STATES"`. The
     adapter resolves the repository-owned spec, requires the
     project and managed spec lifecycle to match, rechecks null branch/PR evidence, and
     optimistically claims the revisioned spec as
     `planning` before it attempts the project transition. A concurrent execution approval loses
     or wins that spec-revision race before the project can be mutated. If the project transition
     then fails, stop on the verified, resumable `planning` spec receipt; only a later explicit
     resume after fresh reads may complete the idempotent project transition. After a verified
     return, the spec is already `planning`: reconcile and harden the new increment plan, return
     `planning → ready`, resolve the new base immediately before handoff, and repeat this step's
     verified freeze. Any branch or pull-request evidence, project/spec lifecycle mismatch, or
     execution-approved/later `designState` rejects the change.
8. <HARD-GATE backend="linear" name="execution-handoff">**Stop before execute.** Present the
   project URL, spec document URL, ordered issue URLs and dependency/Git-parent shape, and frozen
   base branch+SHA. Up to this point there is **no implementation branch, worktree, commit, or
   PR**. Ask the user to choose:
   - **Go** → record execution approval as described below, then run `woostack-execute` in this
     session.
   - **Run overnight** → record execution approval as described below, then run
     `woostack-execute-overnight` unattended.
   - **Hand off** → stop with the Linear artifacts ready for later or external execution; the
     base remains provisional until that executor records approval.
   For **Go** or **Run overnight**, before creating any implementation Git artifact, call
   `linear.sh plan-read` and require null branch/PR evidence, call `linear.sh spec-read`, then
   call `linear.sh spec-write --issue-state-map "$LINEAR_ISSUE_STATES"` with the observed
   revision to change only `designState: ready` to `designState: executionApproved`. Verify it
   with `linear.sh feature-read`. This work step is not another gate; it is the point where the
   base pair becomes immutable. Ambiguous or no answer is not Go. Create no implementation Git
   artifact until the user explicitly chooses **Go** or **Run overnight** and that verified
   approval marker exists.
</HARD-GATE>
9. **Execute.** Invoke the selected execution skill with the Linear project UUID/URL. Linear
   mode has no docs-only base PR: root increment branches start from the frozen SHA and
   dependent increments use their declared Git parent. Execution owns issue/PR evidence and
   lifecycle updates; build never merges.

## Shared terminal states

- **Hand off** → the selected spec/plan artifacts are ready and no implementation PR exists.
- **Go** → a reviewed Graphite stack with one implementation PR per increment; Markdown keeps
  its spec+plan PR at the base, while Linear starts root increments from the frozen SHA.
- **Run overnight** → an autonomous reviewed or truthfully blocked stack plus its morning report.

Build never separately asks to open a PR and never merges.

## Hard constraints

- **Resolve once; never mix backends.** All spec/plan operations use the selected backend and
  its adapter. Linear failure never falls back to local Markdown.
- **Exactly three hard gates per backend.** Design approval, written-spec approval, and
  execution handoff are the only hard stops. Storage writes, read-backs, transitions,
  decomposition, hardening, and Markdown commits are work steps.
- **Harden twice, neither harden gates.** Amend the selected spec and plan artifacts in place;
  hand directly back when no new questions remain.
- **Always get explicit spec approval before planning.** Never advance on inferred approval.
- **Markdown compatibility is exact.** Preserve `.woostack/specs/` and `.woostack/plans/`
  paths, YAML frontmatter, reciprocal Obsidian source joins, the feature worktree, and the
  single docs-only spec+plan base PR.
- **Commit the spec before its approval gate (Markdown).** The same PR begins spec-only;
  revisions update it, the plan is appended later, and no fourth gate or second PR appears.
- **Linear has no Git spec/plan artifacts.** Never create a feature worktree, local spec/plan
  file, branch, commit, or docs-only PR for Linear artifacts.
- **Verified mutations only.** Every Linear write or lifecycle transition must be followed by
  adapter discovery/read-back; unknown or partial outcomes stop.
- **Linear design lifecycle is closed.** Build authors
  `draft → hardened → approved → planning → ready → executionApproved`; execution owns
  `executing → inReview → done`; same-state writes are idempotent, explicit evidence-free replan
  alone permits `ready → planning`, active states may explicitly become `abandoned`, and
  `done`/`abandoned` are terminal. Every other jump or backtrack fails closed.
- **One feature join.** Markdown remains `spec : plan : PRs = 1 : 1 : N`; Linear remains
  `project : spec document : increment issues : implementation PRs = 1 : 1 : N : N`.
- **Stop before execute.** Both backends halt for explicit **Go**, **Run overnight**, or
  **Hand off** and create no implementation Git artifact before Go/Run plus any required verified
  execution-approval write.
- **Never merge.** Build ends at the selected terminal state.
- **Distill durable knowledge only.** Execution writes scoped, deduplicated memory notes, not
  feature-specific trivia.
