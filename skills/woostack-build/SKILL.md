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

Lifecycle spelling is backend-specific: Markdown plan frontmatter uses `in-review`; the
normalized Linear project/issue status is `inReview`. Never translate one storage token into
the other.

## Backend resolution

1. Execute
   [`resolve-backend.sh`](../woostack-init/scripts/artifacts/resolve-backend.sh) `<repo-root>` exactly once.
   Continue only after it returns a successful normalized result; retain the repository identity
   and resolved Linear configuration for adapter calls. Never infer a backend, retry resolution
   as another backend, or fall back.
2. Branch on that result and load exactly one direct procedure:

   When the selected backend is `markdown`, read and follow only the
   [Markdown backend procedure](references/markdown-procedure.md).

   When the selected backend is `linear`, read and follow only the
   [Linear backend procedure](references/linear-procedure.md).

Do not read or combine the unselected backend procedure.

## Shared chain and gate barriers

The selected procedure must preserve this order:

```
ideate → capture spec → harden + persist spec → spec approval → plan
  → verify decomposition → harden plan → mark ready → execution handoff
```

Markdown preserves its existing persistence order:
`commit spec PR → approve spec → plan → append plan to spec+plan PR → execution handoff`.
Linear passes its managed project and issue identities directly to execution and creates no
docs-only base PR.

### HARD GATE 1 — design-approval

The approved design authorizes capture of the selected backend's written spec. No backend
artifact is created before this barrier clears.

### HARD GATE 2 — spec-approval

The hardened written spec must receive explicit approval before planning. In Markdown, commit
the spec and open the spec+plan base PR before presenting this gate; revisions update the same
PR, and Abandon must close the now-open PR before removing its branch and worktree. In Linear,
every spec write and lifecycle transition must have a verified read-back receipt before this
gate or any following work can advance.

### HARD GATE 3 — execution-handoff

Stop after the selected plan is hardened and ready. Markdown must first append the plan to the
same never-merged docs-only base PR. Linear must first verify and freeze `baseBranch` and
`baseCommitSha`; after explicit **Go** or **Run overnight**, it must verify the
`designState: executionApproved` write before creating any implementation Git artifact. Only an
explicit **Go**, **Run overnight**, or **Hand off** clears this barrier.

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
- **Silence is not approval.** Ambiguous, inferred, or missing answers never clear any gate.
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
- **Lifecycle authority stays canonical.** Follow the canonical lifecycle and ownership rules in
  [`../woostack-status/references/conventions.md`](../woostack-status/references/conventions.md).
  On Markdown Abandon, close the PR and remove the worktree and branch; because no Markdown artifact survives,
  never create a status-only abandonment commit. Linear preserves its
  project/document audit history instead.
- **Stop before execute.** Both backends halt for explicit **Go**, **Run overnight**, or
  **Hand off** and create no implementation Git artifact before Go/Run plus any required verified
  execution-approval write.
- **Never merge.** Build ends at the selected terminal state.
- **Distill durable knowledge only.** Execution writes scoped, deduplicated memory notes, not
  feature-specific trivia.
