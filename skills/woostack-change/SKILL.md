---
name: woostack-change
description: Use for a bounded non-bug enhancement or refactor that can ship as one reviewable PR without the full build or fix loop. Invoke via /woostack-change <goal>.
---

# woostack-change

Runs a bounded non-bug change directly from an explicit goal to one reviewed PR. It creates no
specification, plan, or change artifact and has no approval gate.

## Commands

```text
/woostack-change <goal>
```

`<goal>` must identify the target and desired outcome. If either is ambiguous, ask exactly one
focused clarification question before classifying or writing. Otherwise inspect the repository,
classify the request, state the execution intent, and continue without waiting for approval.

## Scope preflight

Inspect repository context and the affected surface before any write, including worktree creation.
Classify from the complete safe work, not from the apparent size of the first edit:

- Route bugs, regressions, incidents, production faults, and any root-cause investigation to
  [`woostack-fix`](../woostack-fix/SKILL.md).
- Route greenfield project creation to
  [`woostack-bootstrap`](../woostack-bootstrap/SKILL.md).
- Route work that cannot remain one coherent, reviewable PR to
  [`woostack-build`](../woostack-build/SKILL.md).
- Proceed here for a bounded non-bug enhancement or refactor when its complete safe implementation,
  verification, and documentation fit one reviewable PR. User-visible behavior and API changes
  qualify when they meet that boundary.

Classification and routing happen before the worktree exists. Routing is a workflow decision, not
an approval gate. A dirty or conflicting worktree, branch collision, or unresolved base blocks the
run before editing; never guess, overwrite, or silently select another workflow.

## Procedure

1. **Resolve isolation.** Use the canonical
   [worktree and base-branch authority](../woostack-init/references/worktrees.md) only for primary
   root/base resolution, worktree creation, and successful-PR removal. Resolve the installed
   `woostack-init/scripts` directory as `<wi>`, the primary repository root as `WOOSTACK_ROOT`,
   and `base="$(bash <wi>/resolve-base.sh)"`. If root resolution fails, stop and report the failed
   resolver and that no worktree path was established. Once the root resolves, choose a short slug
   and establish the intended path `$WOOSTACK_ROOT/.woostack/worktrees/change-<slug>`. Create the
   fresh `change/<slug>` branch there from the resolved base, then run
   `gt track --parent "$base"` from that worktree. Abort before edits if base resolution, creation,
   or Graphite tracking fails. Preserve any recoverable branch or worktree state, never
   auto-delete it, and report the blocker plus the exact intended/preserved worktree path. Every
   subsequent write, command, and skill invocation uses that worktree as its cwd; self-assert its
   normalized `git rev-parse --show-toplevel` first.

2. **State intent and implement.** State the goal, bounded files/surface, and planned verification
   concisely in the conversation. This is informative: do not wait for approval. Implement the
   complete change using the least-code standard in
   [`patterns.md §10`](../woostack-bootstrap/references/patterns.md#10-least-code--comments).
   For new observable behavior, follow the linked
   [`woostack-tdd` kernel](../woostack-tdd/SKILL.md) through red → green → refactor. For
   documentation, configuration, or no-runner work, name and run an exact concrete verification
   instead; never invent a runner or claim TDD occurred.

3. **Verify the changed path.** Run the narrow checks relevant to every changed contract, then
   smoke-test the changed path as a user or caller exercises it. Record the exact commands and
   observed results. A narrowed check does not replace the changed-path smoke test.

4. **Review the current diff inline.** Define the reviewed state as the complete base-to-HEAD diff
   plus all staged, unstaged, and untracked changes. Its complete identity includes the branch,
   resolved base ref and commit, HEAD commit, binary-safe hashes for the base-to-HEAD, staged, and
   unstaged states, and the path plus Git object hash of every untracked non-ignored file. Review
   that exact state through both explicit lenses:
   - **Intent/specification compliance:** the diff fulfills the stated goal and scope, updates every
     affected caller or contract, and introduces nothing outside the one-PR boundary.
   - **Code/skill quality:** the implementation is correct, minimal, maintainable, safe at edges,
     and supported by the verification evidence.

   Resolve findings and re-review the resulting state. Emit a receipt whose status is exactly
   `PASS` only when both lenses have no blockers. Otherwise emit exactly `BLOCKED`, list every
   concrete finding anchored to its file and line or diff hunk, preserve the worktree, and stop.
   Every receipt names the branch, resolved base ref and commit, HEAD commit, binary-safe
   base-to-HEAD, staged, and unstaged hashes, and each untracked path plus Git object hash. A
   missing or state-incomplete receipt is `BLOCKED`; only `PASS` may proceed.

5. **Commit and submit.** On `PASS`, supply that exact receipt identity and invoke
   [`woostack-commit`](../woostack-commit/SKILL.md) from the same `change/*` worktree. It must
   recognize and reuse this canonical isolated, Graphite-tracked branch without asking or creating
   `feature/*`. This verified change path is artifact-neutral under either Markdown or Linear: add
   no spec, plan, project, or issue attribution, while preserving every non-change Linear rule.
   If `commit.pre_commit` changes any base-to-HEAD, staged, unstaged, or untracked state,
   `woostack-commit` stops before staging and returns here. Re-run changed-path verification and
   smoke testing, review both lenses over the new complete state, issue a fresh receipt, and
   reinvoke `woostack-commit`; repeat until the hook's before/after state is stable. It then owns
   commit, push, and one-PR submission. Require observed success and read the PR back to verify its
   URL, head branch, base, and current commit; a successful push alone proves no PR.

6. **Close out.** Only after successful PR read-back, remove the change worktree using the
   successful-PR removal procedure in the canonical worktree authority; retain the branch and PR.
   On every earlier stop, follow that authority's explicit `woostack-change` preservation
   exception. Return the branch, commit, PR URL, narrow verification and smoke-test evidence, and
   the matching `PASS` review receipt. Never merge.

<HARD-STOP>
If primary-root resolution fails, stop and report the failed resolver and that no worktree path was
established. Otherwise do not commit, submit, or remove the worktree when creation or Graphite
tracking fails; scope expands beyond one reviewable PR; a check or smoke test fails; the review
receipt is missing or BLOCKED; or commit, push, submission, or PR read-back fails. Stop truthfully,
preserve every recoverable branch or worktree state, never auto-delete it, and report the blocker
plus the exact intended/preserved `$WOOSTACK_ROOT/.woostack/worktrees/change-<slug>` path. After
writes begin, never silently fall back to fix/build, auto-create a stack, downgrade verification
or review, or delete the worktree.
</HARD-STOP>

## Hard constraints

- **No approval gate.** State intent and proceed; clarification of an ambiguous goal is not an
  approval request.
- Create no spec, plan, change artifact, `.woostack/changes/` directory, workflow schema, lifecycle
  record, or new dependency.
- Perform no write before scope classification; after classification, perform no content write
  until the isolated worktree is successfully created and asserted.
- Use exactly one `change/<slug>` branch and one PR; never split, stack, or create a closeout PR.
- Never silently change workflows or weaken TDD, concrete verification, smoke testing, or either
  inline-review lens.
- On root-resolution failure, report the failed resolver and that no path was established. After
  root resolution, preserve every recoverable branch or worktree state on creation/tracking
  failure, expanded scope, or any verification, review, commit, push, submit, or PR read-back
  failure; report the exact intended/preserved path and never auto-delete it. Teardown requires a
  verified PR.
- **Never merge.** This skill stops after verified PR submission and worktree teardown.
