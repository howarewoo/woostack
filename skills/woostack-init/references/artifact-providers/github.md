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

Select the exact GitHub scope before any provider read or write:

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

Prove the minimum capabilities for the selected operation independently. Issue reads/writes do not
prove native sub-issue or dependency writes. Project reads/writes, membership, and Status capabilities
are required only for explicit Project operations. Unknown, partial, foreign, or unavailable
capabilities fail closed at that operation; unrelated writes need not be available for Doctor's fixed
read-only receipt.

Use GitHub's native sub-issue API through the admitted host interface. Exhaust every page, read the
parent independently, and pass a child's numeric REST `id` when linking. Never use an HTTP error as
proof that a parent is null and never set `replace_parent` to true. Read both sides after a link write.

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

## Recovery and delivery boundary

Retain the exact issue/Project identity, marker, repository, scope, last independently read boundary,
and delivery note needed to recover an interrupted publication. Unknown create, link, relation, or
read-back outcomes stop at that boundary; rediscovery uses the same identity and never duplicates work.
Persist local checkpoints with the shared run-store locking/CAS contract when a caller requires them.

Orchestrate owns scheduling and independent delivery-note recovery for an admitted parent hierarchy.
Execute owns one bounded task through one PR. Git, branches, commits, pull requests, reviews, and merge
evidence remain authoritative; merge authority is human-only.
