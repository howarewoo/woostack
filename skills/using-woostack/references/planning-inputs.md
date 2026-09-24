# Plain planning inputs and handbacks

Ideate, Harden, and callers that compose them exchange complete plain content. Plan consumes the
same input packet and has a separate issue-contract output. Ideate and Harden may reuse a prior
handback, but neither requires the caller to create a Woostack run, permission-restricted manifest,
second remote record, or hidden phase record.

## Input packet

A caller supplies one packet with these headings (Markdown, structured text, or an equivalent host
message is fine):

```text
## Repository identity
- Canonical repository: <exact URL, or state that no canonical remote exists>
- Baseline: <exact branch plus immutable commit/blob identity, when available>
- Checkout: <exact local checkout/worktree identity, when repository inspection is requested>
## Evidence identity
- <source>: <immutable revision or exact canonical PR/issue URL>; <path/range or scoped field>
- <runtime or command observation>: <exact command/log capture and observation time, if applicable>
- If no evidence is supplied, state `none supplied`; never imply an unperformed read.

## Content
<complete goal, specification, candidate issue plan, or diagnosis>
```

Establish repository identity before repository-grounded planning. Resolve the explicitly selected
or unambiguous active checkout and its immutable Git baseline through read-only evidence; record its
canonical remote when present, or its verified local repository identity when no remote exists.
Do not ask the user to supply facts available from that checkout. Ask only when the target is
ambiguous or inaccessible; never substitute a repository found by fuzzy title or recent activity.

Each `Evidence identity` entry names the source and its scope. Use an immutable Git commit/blob and
path/range, an exact canonical pull-request or issue URL, or an exact captured runtime/command
observation. Mutable titles, search results, conventions, and recommendations are citations or
prompts only; they do not prove a decision. If an explicitly selected remote source cannot be read
completely and independently, report the unavailable or stale evidence instead of guessing.

`Content` is complete for the selected phase's purpose: Ideate receives a goal or existing
specification (and may receive a proved diagnosis); Harden receives a complete specification or a
candidate issue plan. A caller may include a prior phase handback verbatim. The receiver must not
require fields that do not apply, but must identify material omissions before claiming completion.

## Complete handback

A phase returns one self-contained plain handback rather than a delta or a manifest reference:

```text
## Repository identity
<the exact identity used, including the admitted baseline>

## Evidence used
<the complete evidence identities and observations relied upon>

## Content
<the complete specification or candidate issue plan, including unchanged sections>

## Confirmed decisions
<only decisions explicitly verified by the user>

## Unresolved questions or discrepancies
<each missing decision, stale source, or inconsistency; empty only when complete>

## Boundary and next use
<the phase's read/write boundary and the separate possible next consumer>
```

The handback preserves user-owned decisions, distinguishes observation from interpretation, and
never claims an unperformed check. A user may save or pass it to another phase explicitly. Ideate
and Harden never automatically invoke Plan, Execute, Orchestrate, commit, create issues, edit source,
or submit a PR.

For a specification, complete content includes goal, users, behavior, constraints, exclusions,
architecture decisions, acceptance, verification expectations, material risks, and the removal or
reuse-first result. Include one `## Data models` section only when the change introduces or alters
storage/tables or public/internal APIs. In that section, record every applicable entity/table,
field/type, constraint, relationship, index, migration/backfill, method/path, authorization,
request/response/error shape, and compatibility detail. Every detail is user-verified; omit the
section when neither storage nor API changes apply.

For a candidate issue plan, each increment includes a stable task key, positive display ordinal,
outcome, bounded scope, non-goals, affected paths/interfaces, acceptance, verified check and smoke
scenario, risks, prerequisites, and Git-parent-selection policy. The plan is content, not issue or
source-control authority; Plan owns any later publication. If the caller has a model-selected
pre-execution layout, retain it as separate execution context with every selected task exactly once,
its `execution_parent`, rationale, compatibility constraints, and any `merge-checkpoint` fallback
with release condition. This layout is not native relationship evidence and does not replace the
technical prerequisites. Orchestrate owns the final layout and scheduling decision.
