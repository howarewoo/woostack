---
name: woostack-plan
description: Turn an approved specification into a verified GitHub parent/child issue hierarchy or explicitly selected GitHub Project graph with prerequisite DAGs. Never executes or merges.
---

# woostack-plan

`woostack-plan` is the single owner of direct GitHub issue publication. In direct use and when
composed by a preparation caller, one complete approved specification and repository/evidence packet
becomes one verified specification parent or explicitly selected Project graph, complete PR-sized
children, and genuine native prerequisite edges. Plan independently reads the result back and returns
the actual publication evidence. It never implements, executes, or merges.
Plan keeps its native publication contract strict. A complete readable child index and explicit
prerequisite declarations are required content in addition to native relationships, so a later
Orchestrate tracker read remains meaningful if relationship metadata is absent or unavailable. That
read-only consumer fallback does not make missing Plan writes successful publication.
## Command

```text
/woostack-plan <approved specification> --parent-issue new
/woostack-plan [<approved specification>] --parent-issue <exact canonical GitHub issue URL>
/woostack-plan <approved specification> --project <exact canonical GitHub Project URL>
```

Select exactly one scope: `--parent-issue new`, one exact existing parent URL, or one exact GitHub
Project URL. Conflicting, repeated, missing, malformed, foreign, or ambiguous selectors block before
any GitHub mutation. Parent mode requires an exact canonical repository and explicit `new` intent or
an exact existing parent; it does not require a local run, Project, Status field, or configuration.
`new` requires a complete approved specification. An existing parent may supply that specification
when no direct specification is provided; material conflicts with the live input return to the caller
before mutation.

Project mode is an explicit alternative. Resolve only the supplied canonical Project, verify its
owner and repository association, and retain its existing Project identity and Status configuration.
Project mode never creates an implicit Project, imports nonmembers, or changes parent-mode behavior.
Plan does not select a destination from a title, recent activity, repository convention, or optional
configuration.

Before publication, load the shared [planning input packet](../using-woostack/references/planning-inputs.md),
the [GitHub publication context](references/github-context.md), and the [GitHub publication procedure](references/github-procedure.md).
The [GitHub profile](../woostack-init/references/artifact-providers/github.md#configuration-and-scope)
owns native identities, capabilities, and API semantics. Plan prefers suitable authorized native GitHub capabilities and supports host-authenticated `gh`
through that contract; it never reads credentials or uses a custom transport.

## Input and ownership

Standalone and composed Plan consume the same complete plain packet:

- exact canonical repository, checkout when present, immutable baseline, and evidence identities;
- an approved specification containing goal, users, behavior, constraints, exclusions, architecture
  decisions, acceptance, verification expectations, risks, and reuse/removal decisions; and
- a complete candidate issue plan when a caller already drafted one, or enough approved content for
  Plan to draft the smallest coherent PR-sized candidate.

Plan validates the packet and drafts only the issue decomposition: one executable issue per coherent
increment, stable task key, positive display ordinal, complete contract, and explicit prerequisite
set. It does not invent product decisions, silently resolve material corrections, or create an
approval event.

Before publication, Plan passes the complete candidate packet through the public Harden content
interface once. Harden performs read-only reconciliation and returns complete content or explicit
unresolved discrepancies. Plan pauses for user resolution of every material correction and publishes
only a complete handback with no unresolved questions. Harden never calls Plan, Plan never calls Plan
recursively, and Plan does not create a hidden planning record to replace either phase.

Prepare supplies this same packet when it composes Plan. Prepare may retain no local planning
authority, and Plan remains the sole publisher: do not perform a draft-only issue call, write a second
graph, or synchronize a second record. Direct and composed calls therefore share one publication owner
and recovery boundary.

Plan owns no implementation, source edit, commit, branch, worktree, PR, review, merge, approval,
Orchestrate dispatch, Execute dispatch, or execution handoff authority.

## Direct issue contract

Create or reconcile exactly one executable issue per increment under the selected GitHub scope. The
specification parent is a separate scope resource, not an increment: it receives no task key,
ordinal, implementation worker, worktree, PR, or dependency edge. Every child description carries all
of these fields:

- stable task ID, unique positive ordinal, concise outcome, and exactly one intended PR;
- exact bounded scope and explicit non-goals;
- affected files, symbols, interfaces, or bounded discovery surface, with relevant constraints;
- observable acceptance criteria defining completion;
- verified focused check definitions and one executable smoke scenario;
- material risks, active blockers, and documentation, migration, deployment, compatibility, or
  cross-increment effects;
- the exact prerequisite set and Git-parent-selection policy; and
- in parent mode, the exact canonical specification-parent URL plus enough specification context for
  a fresh worker, independently verified against the native parent link.

When an increment touches an inter-application boundary, its contract explicitly identifies each
boundary, adapter mapping, validation/narrowing, transport error translation, app-local placement,
wire/API compatibility, and focused boundary-check obligations under the canonical
[application-boundary adapters rule](../woostack-bootstrap/references/patterns.md#3-application-boundary-adapters).
Do not demand identity-only wrappers when an existing shared application/domain contract is correct.

Before admitting a check or smoke scenario, independently verify every named repository-local script
or path exists at the admitted parent tip, is created by an admitted prerequisite before use, or is
created by the same increment before use. A missing or invented command blocks publication; inspection
is not a passing-test claim.
When an increment adds or strengthens tests, link its testing contract and focused checks to the
canonical [Execute testing guidance](../woostack-execute/references/tdd.md). Plan records the
observable contract and verification expectations only; it does not implement or execute the tests.

## Graph invariants

Every task ID and positive ordinal is unique, every prerequisite names an admitted task, every
contract is complete, every acceptance criterion is covered, and the graph has no duplicate
prerequisites, self-dependencies, cycles, missing endpoints, or ambiguous identities. The fewest
independently reviewable increments that deliver coherent outcomes is preferred; do not split by
file or layer merely to manufacture issues.

Independent roots, forks, chains, and joins are valid. Ordinals are display/tie-break order only and
never imply ancestry or edges. Normalize every declared edge as one `[prerequisite, dependent]`
tuple. Only those tuples become native `blocked-by` edges, with the dependent pointing at the
prerequisite. Preserve existing exact edges unless the approved specification explicitly changes the
prerequisite set; never add or remove edges to match ordinal adjacency.

A root records its approved integration parent branch. A dependent records every prerequisite and
the policy for resolving one concrete existing Git parent branch and SHA from verified delivered
branches at dispatch. Plan never guesses a branch, creates an integration branch, or rewrites
dependencies. The technical DAG remains the planning evidence. Orchestrate, after this publication,
selects and summarizes a model-chosen pre-execution single-parent forest before allocation; added
ordering is compatibility evidence, not native relationship evidence. It preserves technical
prerequisites separately, retains useful parallelism, and uses effective prerequisites for worker
readiness and repair propagation. A join can therefore stack on a verified existing parent. Only
an approved `merge-checkpoint` fallback for existing divergence or repository constraints becomes
`waiting-for-merge`; a join otherwise does not require a new Plan invocation, parent decision,
native relationship write, or graph rewrite. Ask for a decision only when material parent ambiguity
remains.

Bounded Execute accepts one complete bounded task per invocation and is not a DAG dispatcher. A
branching, multi-root, or join graph is not handed to Execute as a runnable whole; retain it for
Orchestrate and report any unsupported single-task handoff before implementation mutation.

## Publication and read-back

The [GitHub publication procedure](references/github-procedure.md) owns both explicit Project and
native parent synchronization. Before the first write it:

1. verifies the exact repository and selected scope, complete pagination, stable identities,
   verification provenance, and every required issue/hierarchy/dependency capability;
2. reads the full existing hierarchy and dependency graph and compares it with the admitted
   candidate under the existing-description invariant;
3. preallocates one marker UUID per new specification parent or task, discovers zero exact marker
   matches across complete open/closed canonical-repository pagination, and creates/binds once;
4. independently reads every created or retained issue before native parent links, Project membership,
   child-index changes, or prerequisite edges; and
5. independently reads back every issue body/identity, native parent in both directions, selected
   Project membership when applicable, managed parent index, and the complete exact normalized edge
   set with both endpoint identities.

Parent containment and prerequisites are distinct. A native parent link is written only for a newly
allocated child after both sides conclusively show no parent; a retained missing link is drift and
blocks. The parent itself never enters task mappings or dependency endpoints. In Project mode,
membership and configured Status are verified separately from native parent state.

Unknown or partial writes retain confirmed objects, identities, and the last verified boundary. One
ownership-valid marker match recovers an unknown create; zero, multiple, foreign, or incomplete matches
block without replay or replacement. Resume only the first unproved operation after fresh drift
admission. An unchanged verified publication performs zero mutations. A relationship capability that
cannot be independently proved is blocking, not a nonblocking warning.

After the user separately selects Orchestrate, an exact tracker URL plus independently readable
issues and a complete declared index can establish executable membership even when these native
links were never installed. Orchestrate preserves that tracker as context and distinguishes declared
from native evidence. It does not retroactively satisfy Plan's native publication/read-back gates.

## Return

Return the exact canonical repository and admitted revision, selected scope, complete display-ordered
child contracts, actual parent and child URLs/native identities, explicit prerequisite sets and
parent-selection policies, repository assumptions/effects, verification-command provenance, native
parent read-back, exact normalized technical graph, mutation/read counts, stable recovery
identities, and any missing relation. Report a join without a currently verified existing parent as
an expected execution-time `waiting-for-merge` condition only when Orchestrate's selected execution
layout has an explicit `merge-checkpoint` fallback; otherwise a suitable selected parent may be used
without a new Plan decision. This is not a planning defect or a request for a new integration
strategy. Parent mode reports the specification parent separately from the child task index.

When required relationships are verified, return the complete planning handback and a separate
orchestration suggestion. A canonical tracker URL or selected Project URL is a convenience hint for
the matching Plan scope, not an exhaustive Orchestrate admission type:

```text
/woostack-orchestrate --issue <verified canonical tracker URL>
/woostack-orchestrate --project <verified selected-Project-URL>
```

Show only the applicable hint; Project mode does not invent a specification parent. The user may
instead provide the complete handback or understandable tracker context in conversation. Orchestrate
reads the tracker and every selected issue, resolves executable tasks and a bounded technical DAG
from available evidence, then chooses and summarizes its effective execution forest. It preserves
native or declared provenance, retains parallelism, and asks about material ambiguity. It can
interpret a complete tracker index without native links, but does not treat inaccessible task issues,
ambiguous membership, unreadable contracts, unknown dependency meaning, or an unresolved
contradiction as executable. Project mode does not invent a specification parent. The suggestion is
not an automatic dispatch or execution claim. A partial graph, missing relationship capability, stale
specification, unresolved correction, unknown identity, or empty executable plan is not Plan
publication-ready.
Plan never invokes Orchestrate or Execute and never claims implementation, delivery, review,
passing checks, product acceptance, or merge.

## Hard constraints

- One complete approved packet in; one coherent, directly published GitHub scope out.
- For Plan publication, select exactly one explicit parent or Project destination; parent mode never
  implicitly selects a Project. This publication boundary does not define Orchestrate admission.
- Exactly one executable child per increment; the specification parent stays separate from task
  mappings, dependency endpoints, workers, worktrees, and PRs.
- Native parent links define containment; only declared child-to-child prerequisites define
  `blocked-by` edges; Git ancestry remains separate.
- Direct and composed Plan use the same public Harden handback and the same publisher. No draft-only
  delegated mode and no wrapper-owned second writer.
- Preserve unrelated human content, existing identities, historical resources, Project state, and
  exact native relationships. Never silently reparent, flatten, detach, replace, or widen scope.
- No credentials, fuzzy selection, hidden ledger, automatic execution, implementation source edit,
  branch/PR creation, approval, merge, or Orchestrate/Execute dispatch.
- Never claim publication or read-back without the corresponding observed evidence.
