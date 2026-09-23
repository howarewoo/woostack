# GitHub direct publication profile

This profile owns GitHub identities, exact scope, native issue hierarchy, prerequisite edges, Project
membership/Status operations, and direct-publication recovery. The shared [artifact contract](../artifact-backends.md)
owns local authority, retained data, filesystem safety, ordering, and independent read-back. There is
no provider selector and no remote mirror of a local plan.

## Configuration and scope

The optional canonical policy is the top-level `github` object described by
[canonical GitHub configuration](../artifact-backends.md#canonical-github-configuration). It contains
only `owner`, `ownerType`, `statusField`, and `projectStatuses`; `visibility` is not a setting. The
resolver validates this object once. Existing Projects retain and report their actual visibility.

Select the exact GitHub scope before any GitHub read or write. Use an available, authorized GitHub
capability that supports the selected operation and its verification. Prefer the host's native GitHub
tools when suitable; host-authenticated official `gh` remains supported where appropriate. Discover
actual capabilities, supported read/query shapes, and schemas from the host rather than assuming tool
names or request forms. Custom HTTP/REST/GraphQL clients, credential reads, and token forwarding
remain forbidden. Scope operations strictly to the canonical repository and explicitly selected
parent issue or Project; parent selection never selects a Project or provider mirroring.

- Plan parent-issue publication uses the canonical repository plus `--parent-issue new` or one
  exact existing parent issue URL; Orchestrate parent execution uses `--issue <exact-parent-url>`.
  Neither path requires `github`, a Project, Status configuration, or Project capabilities.
- Explicit Project operations require one exact caller-supplied Project and the actual Project
  mappings/capabilities needed by that operation. They never infer a Project from configuration,
  create a destination from a goal, or treat a missing Project capability as a parent-mode failure.
- Exact issue association is read-only context until the owning Commit path records its verified
  closing reference. It never selects a publication destination.

Use an authorized native GitHub capability when the host exposes a suitable interface; the
host-authenticated `gh` CLI is supported. Do not invent tool names, read credentials, forward tokens,
or add another transport layer. Scope every operation to the canonical repository and exact selected
parent, issue, or Project.

## Capabilities and native graph

Prove each operation's capabilities independently through the selected authorized GitHub interface:
issue reads/writes, native parent/sub-issue reads/writes, dependency reads/writes, terminal
pagination, and independent read-back. Issue-write access alone does not prove sub-issue or
dependency-write access. Before publication, preflight every required write family without a test
mutation; unsupported or unknown capability blocks only the operation that requires it. Project
read/write, membership, and Status capabilities are required only for selected Project operations.
Unavailable Project access does not block parent-only planning or explicitly selected Orchestrate
parent-hierarchy reads.

Use GitHub's native sub-issue semantics through the selected host capability. The REST route forms
below describe the required resource and identity semantics, not a mandatory transport:
`GET repos/{owner}/{repo}/issues/{number}/sub_issues` must exhaust all pages; read the actual parent
independently (`GET .../parent` or an explicitly selected nullable GraphQL `parent`). An HTTP or
tool error is not proof of `parent = null`. A link operation takes the child's numeric REST `id` as
`sub_issue_id`, not its issue number or GraphQL node ID. Never set `replace_parent` to true. API
permission to link another repository's issue does not widen the canonical-repository scope. Require
native reads in both directions after a link write.


Normalize each prerequisite as `[prerequisite, dependent]`. Read both endpoint collections completely,
verify repository and scope, then write only the declared edge and independently read both endpoint
identities back. Do not flatten nested containers, infer missing edges from prose, or silently adopt a
foreign issue.

Planning and orchestration normalize every direct child with a stable task identity, a positive
ordinal, and a complete declared predecessor set. Ordinals are display/order metadata, not an
implicit dependency chain. Reject duplicate or missing task identities, foreign predecessor
references, self-dependencies, cycles, and edges whose endpoints were not independently read in
the admitted exact scope. A blocked external prerequisite remains blocked; it never widens the
scope or becomes an invented task.

## Direct issue publication

Plan publishes the complete specification and one-level PR-sized children directly to the exact new
or existing parent, or synchronizes only the exact explicit Project span. A specification parent is
not an executable task. Existing unrelated issue fields, Project state, labels, views, parent links,
and historical resources are preserved. Publication never closes issues or Projects, changes product
acceptance, or grants merge authority.

For an existing parent, read its open issue state, actual parent, complete body/comments, every native
child page, each child's actual parent, contract, prerequisite pages, and delivery evidence before any
mutation. Require a top-level parent (`parent = null`), complete pagination, unique task identities,
and one direct child level. A changed or incomplete read blocks rather than expanding scope.

Every newly created issue uses a preallocated mutation marker in its body. Before creation, completely
search the exact scope for that marker; recover an unknown outcome by repeating that discovery and
reading the one ownership-valid match. Never allocate another marker or replay a create. Bind each
native identity once after independent read-back. Existing missing links are drift, not permission to
adopt unrelated issues.

## Selected Project content

The managed specification lives in `ProjectV2.readme` between the existing whole-line markers
`<!-- woostack-spec-start -->` and `<!-- woostack-spec-end -->`. Preserve every byte outside that span.
Before its first write, retain one UUID for `<!-- woostack-project-mutation:<UUID> -->` inside the span,
bound to the exact Project URL/node ID and approved-contract identity. This identifies a README
mutation, not permission to create a Project or import a historical record.

Bootstrap's span contains that marker, the approved-contract identity, canonical intended repository
URL, integration/base branch, and a `### designApproved` section containing the complete approved goal,
architecture, scope, and decisions. After scaffold verification, add or reconcile a
`### bootstrapVerified` section in the same span with the observed repository URL/branch, resolved
stack and versions, created surfaces, and individual command outcomes, distinguishing unrun checks.
Preserve the approved design. These are Markdown sections in the README, not Project fields or
separate status-update objects. Plan's explicit Project path uses the same admitted specification span;
its approved reconciliation must preserve unrelated Bootstrap verification and human content.

Read the Project's `id`, `url`, owner, actual visibility, and complete `readme` before mutation; confirm
that visibility is approved for the content. Bootstrap needs Project read/update capability, not issue,
membership, or Status writes. With no existing markers,
append one owned span after the unchanged README. Reuse a span only when its retained marker and
contract binding match; missing paired markers, duplicates, unbound ownership, or conflicting content
block rather than authorizing replacement. Reject supplied content that contains the boundary-marker
lines. Re-read immediately before writing and stop on drift. Bootstrap updates only `readme` through
`updateProjectV2(input: {projectId, readme})` or an equivalent authorized native capability; do not
change title, visibility, lifecycle, or unrelated fields. README replacement has no claimed atomic CAS.

Independently read the same Project and complete README back, verifying identity, the marker, exact
approved/observed content, and preserved outside bytes. On an unknown write, re-read this exact Project:
matching content confirms the same operation without another append; missing, changed, partial, or
ambiguous content blocks pending reconciliation. Never allocate a replacement marker or Project,
repeat an append blindly, or report publication success from the mutation response alone.

## Doctor live receipt

The optional controller-owned receipt is normalized, mode 0600, non-secret, and consumed by the shell
engine without provider calls. It has exactly these semantic requirements:

- `schemaVersion: 1`, `provider: "authorized-github"`, `interfaceAvailable: true`, authenticated
  ready state, a non-secret viewer, unique owner resolution, and a canonical repository URL;
- complete single-select `projectStatuses` with five distinct option IDs and names for `planned`,
  `executing`, `inReview`, `done`, and `blocked`, plus the resolved Status field; and
- boolean capability evidence including fixed read-only requirements `projectRead`, `statusFieldRead`,
  `pagination`, and `independentReadBack`.

The shell rejects extra/secret keys, malformed or foreign identity/read-back evidence, and any missing
fixed capability. It never trusts receipt-declared required-capability lists. `projectWrite`,
`statusFieldWrite`, `issueWrite`, and dependency writes may be false. A parent-issue operation does not
need this Project-oriented receipt.

Retain the complete DAG for explicit Orchestrate execution; Execute cannot accept or dispatch it as a
graph. A caller may select one task from any valid DAG for
[bounded Execute admission](../../../woostack-execute/SKILL.md#admit-one-task), supplying its concrete
parent and complete prerequisite-readiness evidence under the
[workspace/ancestry guidance](../worktrees.md#repository-and-ancestry-evidence). An unresolved join
parent blocks that task, not unrelated tasks. Run-store storage retains the existing
task/dependency/mapping forms without schema migration or edge rewriting; workflow admission validates
the DAG.

## Recovery and delivery boundary

Retain the exact issue/Project identity, marker, repository, scope, last independently read boundary,
and delivery note needed to recover an interrupted publication. Unknown create, link, relation, or
read-back outcomes stop at that boundary; rediscovery uses the same identity and never duplicates work.
Persist local checkpoints with the shared run-store locking/CAS contract when a caller requires them.

Orchestrate owns scheduling and independent delivery-note recovery for an admitted parent hierarchy.
Execute owns one bounded task through one PR. Git, branches, commits, pull requests, reviews, and merge
evidence remain authoritative; merge authority is human-only.
