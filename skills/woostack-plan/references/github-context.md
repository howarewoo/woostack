# GitHub Plan publication context

`woostack-plan` publishes directly to one exact GitHub scope. Parent mode needs only a verified
canonical repository and an explicit `--parent-issue new` or existing-parent URL. Explicit Project
mode resolves one exact supplied Project and applies its Project-specific settings. A caller's local
run, retained record, or unrelated configuration is never required for parent publication and never
becomes a second authority. These are Plan publication boundaries; Orchestrate may later interpret
the complete planning handback or understandable tracker context independently, with or without
native links.

The shared [artifact contract](../../woostack-init/references/artifact-backends.md#direct-publication-and-recovery)
and [GitHub profile](../../woostack-init/references/artifact-providers/github.md#configuration-and-scope)
own common identity, capability, pagination, mutation, recovery, and read-back rules. The [GitHub
publication procedure](github-procedure.md) owns Plan's direct synchronization.

## Repository and scope resolution

1. Resolve `https://github.com/<owner>/<repo>` from trusted Git/GitHub evidence and retain the
   immutable repository/baseline identity supplied by the caller. Never select by title, recent
   activity, or search ranking.
2. If parent mode is selected, validate the exact canonical parent URL or the explicit `new` intent,
   verify owner and native issue identity, and do not resolve Project configuration or call Project
   APIs.
3. If Project mode is selected, resolve the exact canonical Project URL, verify owner/type and
   canonical repository association, and retain its native identity, existing title/visibility, and
   required configured Status option mapping. Do not create or infer a Project.
4. Preflight only the capabilities required by the selected scope. Parent mode requires issue reads
   and writes, native parent/sub-issue reads and writes, dependency reads and writes, complete
   pagination, and independent read-back. Project mode additionally requires Project membership,
   item identity, and configured Status read/write capabilities.

## Project baseline

For explicit Project mode, completely paginate the selected Project's active and archived items and
native dependency relations. Admit only direct members in the canonical repository whose stable
identity and parent state round-trip independently. Preserve parentless historical plans, containers,
unrelated labels, fields, README prefix/suffix, views, and existing relationships. A missing or
foreign endpoint never authorizes importing or creating a replacement task.

Map retained increments by verified canonical URL and native identity, never by title or ordinal. An
explicitly new task retains a null mapping and one preallocated marker UUID until canonical read-back
binds it. Normalize all native `blocked-by` reads as `[prerequisite, dependent]` tuples with both
endpoint identities verified. Ordinal adjacency never alters the admitted edge set.

## Parent baseline

For parent mode, completely read the selected top-level parent (or reserve the distinct parent marker
for `new`), its full managed specification/index span, every paginated direct child, every child's
actual native parent and complete contract, and all dependency pages. The managed index must also
enumerate the exact intended implementation set and prerequisite declarations, so it remains useful
to a later read-only tracker consumer even if native relationship metadata is absent. A readable
index is not native containment. Nested, foreign, conflicting, missing, ambiguous, stale, or
partially paginated state blocks before mutation. The specification parent is stored separately as
`specItem`; it is never a task mapping or dependency endpoint.

Parent and child marker UUIDs are retained in the active Plan handback. On an unknown create response,
repeat complete open/closed canonical-repository discovery for the same marker. Recover one ownership-
valid match; block on zero, duplicate, foreign, partial, or ambiguous matches without a replay or
replacement identity. A missing link on a retained child is drift, not permission to reparent it.

## Evidence and drift

The caller supplies complete specification, candidate content when available, repository identity,
admitted immutable baseline, and evidence identity through the shared [planning input packet](../../using-woostack/references/planning-inputs.md).
Plan validates command/path provenance before publication and uses public Harden once for candidate
reconciliation. Repository conventions or GitHub responses can expose a discrepancy but cannot
silently answer a user-owned decision.

Immediately before each write, re-read the admitted scope and preserve unrelated human content. A
changed specification, candidate, parent, child identity, membership, native link, or edge requires
fresh admission. Keep exact confirmed identities and the last verified boundary across a partial
failure; return actual objects and missing relations without claiming a successful publication.
