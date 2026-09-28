# GitHub direct publication profile

This profile owns GitHub identities, exact scope, issue and dependency relationships, Project
membership/Status operations, and direct-publication recovery. The shared [artifact contract](../artifact-backends.md)
owns local authority, retained data, filesystem safety, and the read-back and recovery invariants.
There is no provider selector and no remote mirror of a local plan.

## Configuration and scope

The optional canonical policy is the top-level `github` object described by
[canonical GitHub configuration](../artifact-backends.md#canonical-github-configuration). It contains
only `owner`, `ownerType`, `statusField`, and `projectStatuses`; `visibility` is not a setting. The
resolver validates this object once. Existing Projects retain and report their actual visibility.

Select the exact GitHub operation scope before any GitHub read or write. Resolve the destination
under the shared [publication boundary](../artifact-backends.md#direct-publication-and-recovery);
when two candidates remain plausible, ask the user instead of guessing. Use an available, authorized
GitHub capability that supports that operation and its verification. Prefer the host's native GitHub tools when
suitable; host-authenticated official `gh` remains supported where appropriate. Discover actual
capabilities, supported read/query shapes, and schemas from the host rather than assuming tool names
or request forms. Custom HTTP/REST/GraphQL clients, credential reads, and token forwarding remain
forbidden. Plan may read relevant issues while planning but makes no GitHub mutation unless the
request asks for publication. Orchestrate reads the canonical repository and the issue/task context
needed to resolve the user's work; a Project is included only when explicitly selected, and its
status lifecycle is used only when that selection requests status mutation.

Orchestrate's tracker interpretation is read-only and has different evidence requirements. It may
use a complete verified readable index to establish membership when native child hierarchy is
absent, partial, or unavailable. Read every selected issue, keep native/declared/inferred edge
provenance distinct, and disclose failed relation reads honestly; declared membership never becomes
an actual parent or a fabricated native receipt. Plan holds the same bar for what it writes, and
reports a native relationship it could not create as missing rather than waived.

- Publication targets the one resolved destination: the canonical repository for repository-scoped
  work, or the exact selected Project for Project-only content. Orchestrate may receive an issue URL as a
  convenience hint, but admission is resolved from the understood conversation, repository, and
  tracker context.
- `--project <exact canonical Project URL>` is the one optional selector. It requires one exact
  caller-supplied Project and only the capabilities needed for the selected operation. When status
  mutation is explicitly requested, require its mappings and capabilities; never infer a Project
  from configuration, create a destination from a goal, or make Project access a condition for
  other work.
- Exact issue association is read-only context until the owning Commit path records its verified
  closing reference. It never selects a publication destination.

Use an authorized native GitHub capability when the host exposes a suitable interface; the
host-authenticated `gh` CLI is supported. Do not invent tool names, read credentials, forward tokens,
or add another transport layer. Scope every operation to its exact selected destination and, for
repository-scoped work, the canonical repository.

Publication is read-only until the request asks for a write, and a planning-only request performs no
GitHub mutation at all.

## Capabilities and native relationships

Prove each operation's capabilities independently through the selected authorized GitHub interface.
Prove only what the selected operation needs: writing issue content requires issue reads/writes,
pagination to the end of the relevant query, and independent read-back, while native sub-issue and
dependency reads/writes are proven only when a relationship is actually requested. Issue-write
access alone does not prove sub-issue or dependency-write access. Preflight every required write
family without a test mutation; unsupported or unknown capability blocks only the operation that
requires it. Project read/write, membership, and Status capabilities are required only for selected
Project operations.

When a native sub-issue link is requested and available, use GitHub's native sub-issue semantics
through the selected host capability. The REST route forms below describe the required resource and
identity semantics, not a mandatory transport: `GET repos/{owner}/{repo}/issues/{number}/sub_issues`
must exhaust all pages; read the actual parent independently (`GET .../parent` or an explicitly
selected nullable GraphQL `parent`). An HTTP or tool error is not proof of `parent = null`. A link
operation takes the child's numeric REST `id` as `sub_issue_id`, not its issue number or GraphQL node
ID. Never set `replace_parent` to true. API permission to link another repository's issue does not
widen the canonical-repository scope. Require native reads in both directions after a link write.

Normalize a requested dependency as `[prerequisite, dependent]`. Read both endpoint collections to
the end of the relevant query, verify repository and scope, then write only the declared edge and
independently read both endpoint identities back. Do not infer a missing edge from prose, adopt a
foreign issue, or treat display order as a dependency.

Orchestrate resolves each executable task from the conversation, repository, tracker/specification,
and real issue evidence, keeping native, declared, and inferred edge provenance distinct in its own
resolution. A complete readable index can declare the executable set without a native child
hierarchy; every named issue must still be independently readable and context-only references must
be excluded. Reject foreign prerequisite references, self-dependencies, cycles, and edges whose
endpoints were not independently read in the exact scope. A blocked external prerequisite remains
blocked; it never widens the scope or becomes an invented task. An omitted administrative field is
not a blocker.

## Direct issue publication

Write the requested issues into the resolved scope, or synchronize only the exact explicit Project
span. A parent, container, or ordinal is never required, and a written issue is not by itself a
task, worker, branch, PR, or dependency endpoint. Existing unrelated issue fields, Project state,
labels, views, links, and historical resources are preserved. Publication never closes issues or
Projects, changes product acceptance, or grants merge authority.

Before writing, read the relevant existing resources in that scope and reuse an exact match rather
than creating a near-duplicate. After each create or update, independently read the issue back and
verify its canonical identity and actual content. A changed or incomplete read blocks instead of
expanding scope, and an unchanged repeat performs no write.

Each issue carries what a reader needs to act on it: the outcome, the constraints that matter,
acceptance with how to verify it, and the dependencies that actually exist. The heading set is the
writer's choice.

Relationship links are a separate, requested step. When the request asks for native sub-issues or
dependency edges and the capability is present, write them and verify each by two-sided read-back.
When the capability is absent or unsupported, keep the issues that were written plus one explicit
readable index naming them and their real prerequisites, and state plainly which relationships were
not created. That index is the human-readable record, not a native graph: a publication that was
required to produce native links and did not is reported incomplete.

Orchestrate still performs its own issue, contract, dependency, and repository validation before it
resolves a task set, and bounded Execute admits one complete task.

## Selected Project content

The managed specification lives in `ProjectV2.readme` between the existing whole-line markers
`<!-- woostack-spec-start -->` and `<!-- woostack-spec-end -->`. Preserve every byte outside that span.
Before its first write, retain one UUID for `<!-- woostack-project-mutation:<UUID> -->` inside the span,
bound to the exact Project URL/node ID. This identifies a README mutation, not permission to create a
Project or import a historical record.

Bootstrap's span contains that marker and a `### designApproved` section containing the complete
approved goal, architecture, scope, and decisions. After scaffold verification, add or reconcile a
`### bootstrapVerified` section in the same span with the observed repository URL/branch when a
remote exists, resolved stack and versions, created surfaces, and individual command outcomes,
distinguishing unrun checks.
Preserve the approved design. These are Markdown sections in the README, not Project fields or
separate status-update objects. Plan's explicit Project path uses the same admitted specification span;
its approved reconciliation must preserve unrelated Bootstrap verification and human content.

Read the Project's `id`, `url`, owner, actual visibility, and complete `readme` before mutation; confirm
that visibility is approved for the content. Bootstrap needs Project read/update capability, not issue,
membership, or Status writes. With no existing markers,
append one owned span after the unchanged README. Reuse a span only when its retained marker and
Project binding match; missing paired markers, duplicates, unbound ownership, or conflicting content
block rather than authorizing replacement. Reject supplied content that contains the boundary-marker
lines. Re-read immediately before writing and stop on drift. Bootstrap updates only `readme` through
`updateProjectV2(input: {projectId, readme})` or an equivalent authorized native capability; do not
change title, visibility, lifecycle, or unrelated fields. README replacement has no claimed atomic CAS.
Independently read the same Project and complete README back, verifying identity, the marker, exact
approved/observed content, and preserved outside bytes. On an unknown write, re-read this exact Project:
matching content confirms the same operation without another append; missing, changed, partial, or
ambiguous content blocks pending reconciliation. Never allocate a replacement marker or Project,
repeat an append blindly, or report publication success from the mutation response alone.

## Recovery and delivery boundary

Retain the exact issue/Project identity, any bound span marker, repository, scope, last independently
read boundary, and delivery note needed to recover an interrupted publication. An unknown create,
link, relation, or read-back outcome stops at that boundary and reports the confirmed objects plus
whatever relation is still missing. Rediscovery searches the relevant scope to the end of its query
for that same exact identity, reads the one ownership-valid match, and never duplicates work or
allocates a replacement. For an issue create, retain a distinct preallocated identity and intended
repository/content before the write, prove that identity absent beforehand, and include it in the
created body. Recovery requires the same identity and matching content in the exact repository;
matching title and body without the retained identity is not ownership evidence.

A caller that needs its own recovery checkpoint keeps it private and owner-only; the shared
[run-store reader](../artifact-backends.md#owner-only-local-run-store-reader) only reads retained
records.

Orchestrate owns ordering, concurrency, and in-session observation of its resolved scope; Execute
owns authorized bounded implementation, and Commit owns Git/PR delivery and explicitly requested
issue notes. Git, branches, commits, PRs, reviews, and merge evidence remain authoritative; merge
authority is human-only.
