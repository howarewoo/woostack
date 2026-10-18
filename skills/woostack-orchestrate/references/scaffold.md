# Initial scaffold admission

Apply only within explicitly authorized creation scope. This procedure grants no document-writing,
configuration, Git, remote-resource, or publication authority. The active workflow owns the requested
outcome and its approval and completion boundaries.

Before the first mkdir, write, or generator invocation, resolve one unambiguous intended target
and its physical parent. Use fresh no-follow metadata and a complete directory listing: reject
symlinks in the target or ancestors, non-directory objects, unreadable or ambiguous paths, unsafe
ownership/permissions, and a target claimed by another writer. The new target must be absent or
empty; for an existing repository apply [workspace ownership](worktrees.md#workspace-and-ownership)
and preserve every existing file. A collision or changed admission result blocks writing there,
not permission to delete, overwrite, reset, or scaffold around it. Never redirect to another target
silently.

Reuse settled product and technology decisions, the selected ecosystem's native structure,
[implementation patterns](patterns.md), and applicable [infrastructure guidance](infrastructure.md).
Create only the requested working slice. Remove unrequested generated demos and omit speculative
shared packages or adapters. Resolve selected or changed dependencies from authoritative current
sources rather than memory. Run applicable real checks and smoke each requested surface through a
meaningful path under [verification guidance](tdd.md).

Inspect the resulting tree for unexpected files, secrets, build output, leftover demos, and missing
ecosystem-required lockfiles. Record accurate setup prerequisites, selected technologies and lookup
sources, non-secret environment names, material choices, and observed commands/results in the
project's documentation when that output is within the authorized scope. Never invent commands.

A local-only target needs no GitHub account, Project, remote, Git initialization, commit, push, or
PR. Initialize local Git only when requested or needed for authorized delivery. Missing delivery
permission blocks publication, not otherwise authorized local work, and grants no permission to
create a remote repository or Project.
