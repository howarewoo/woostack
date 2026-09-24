# Workflow smoke

These are three on-demand recipes for material Plan, Execute, or Orchestrate changes and for regression investigation. They are not a corpus, a model grader, a mandatory check after every instruction edit, or a replacement test command. Run the smallest recipe that covers the changed behavior and add a scenario only after a valuable observed failure.

## Evidence classes and shared fixture

Label every result as one of these classes:

- **Deterministic helper:** the shipped production helper runs in a temporary local repository. `recording_driver.py` supplies recorded reads and consumes the emitted packet; it does not run a model or claim host execution.
- **Actual host:** the installed Plan, Execute, or Orchestrate skill runs in a supported coding host with real subagents where the workflow requires them. Record the repository revision, host, exact invocation, outcome, and relevant read-back.
- **Unrun:** the recipe was not attempted because its exact live-resource permission, host capability, or safe interruption facility is unavailable. Never report an unrun recipe as passed.

The live recipes use this disposable fixture graph:

```text
P specification parent
├── A independent
├── B independent
└── C blocked by A
```

Before Plan, obtain separate permission for one exact disposable GitHub repository, native issue hierarchy and dependency writes, draft-PR writes used by Execute/Orchestrate, and the stated cleanup. The repository must have no Project requirement. In a fresh clone, create the admitted baseline:

```bash
git clone https://github.com/<owner>/<test-repository>.git <local-directory>
cd <local-directory>
git config user.name 'Workflow Smoke'
git config user.email 'workflow-smoke@example.invalid'
: > a.txt
printf '# Workflow smoke fixture\n' > README.md
git add a.txt README.md
git commit -m 'Create workflow smoke fixture'
BASE_SHA=$(git rev-parse HEAD)
git push --set-upstream origin HEAD:refs/heads/main
test "$(git ls-remote origin refs/heads/main | cut -f1)" = "$BASE_SHA"
```

Use this same complete packet for the Plan publication and its retry:

```text
## Repository identity
- Canonical repository: https://github.com/<owner>/<test-repository>
- Baseline: main at <BASE_SHA>
- Checkout: <local-directory>

## Evidence identity
- Git: <BASE_SHA>, README.md and a.txt
- Runtime: none; this planning fixture has not run an implementation check.

## Content
Approved specification: publish one top-level specification parent P for three
PR-sized tasks in a disposable repository. A writes `A` to a.txt. B writes `B`
to b.txt. C writes `C` to c.txt and verifies that A remains available in a.txt.
A and B are independent; only C is blocked by A. No Project, application, merge,
or production deployment is included.

Candidate issue plan:

1. Stable task ID A, ordinal 1. Goal: write `A` to a.txt.
   Scope: a.txt. Non-goals: b.txt, c.txt, siblings, Project state.
   Acceptance: a.txt is exactly the single line A.
   Check: `python3 -c "from pathlib import Path; assert Path('a.txt').read_text() == 'A\n'"`.
   Smoke: the same command. Parent policy: admitted main baseline.
   Risk: none; the baseline file is intentionally empty.
2. Stable task ID B, ordinal 2. Goal: write `B` to b.txt.
   Scope: b.txt. Non-goals: a.txt, c.txt, siblings, Project state.
   Acceptance: b.txt is exactly the single line B.
   Check: `python3 -c "from pathlib import Path; assert Path('b.txt').read_text() == 'B\n'"`.
   Smoke: the same command. Prerequisite set: empty. Parent policy: admitted main baseline.
   Risk: none; b.txt is created by this task.
3. Stable task ID C, ordinal 3. Goal: write `C` to c.txt while consuming A.
   Scope: a.txt, c.txt. Non-goals: b.txt, siblings, Project state.
   Acceptance: a.txt is exactly the single line A and c.txt is exactly the single line C.
   Check: `python3 -c "from pathlib import Path; assert Path('a.txt').read_text() == 'A\n' and Path('c.txt').read_text() == 'C\n'"`.
   Smoke: the same command. Prerequisite set: A. Parent policy: use the verified
   delivered A branch and SHA selected by Orchestrate; no merge is required.
   Risk: A and C both name a.txt, so C must not start before A is proved.
```

Keep credentials, host-private output, and personal data out of the fixture and its evidence.

## 1. Plan publication and stop

**Prerequisites:** the shared fixture, separate live-test permission, a supported host that can load the actual Plan skill and use authorized GitHub issue, native parent/sub-issue, dependency, and complete read-back operations. This repository ships no deterministic Plan transport; an old normalized Eval fixture is not one.

**Setup:** use the fresh clone and complete packet above. Record `BASE_SHA`, the installed Plan skill revision, and the canonical test repository before the first write.

**Invocation:** run the actual skill with one explicit new-parent selector:

```text
/woostack-plan <the complete shared packet above> --parent-issue new
```

For the unknown-result variant, interrupt only the Plan host after GitHub confirms creation of P but before Plan returns. Resume with the exact same packet and selector. If the host cannot preserve the invocation and stop it at that boundary, mark this variant **Unrun** rather than simulating a timeout. After successful recovery, run the identical unchanged invocation once more.

**Assertions:**

- Native read-back shows exactly one top-level P, exactly three direct children A/B/C, and no other issue created by this publication.
- Each child has its complete task contract, actual-parent read-back, and stable task identity. The only dependency is C blocked by A; A and B have no dependency edges.
- P is not a task, worker, branch, PR, or dependency endpoint. No implementation source, source branch, worktree, commit, PR, worker dispatch, approval, or merge occurred. A printed issue list alone is not evidence.
- The unknown-result retry reuses P and any already-created child identities without replacement or duplicate objects. The unchanged repeat performs zero issue or relationship mutations.
- The actual-host record names the revision, host, exact invocation, and direct GitHub read-back. If live permission is absent, report this recipe **Unrun — no authorized disposable GitHub repository and native relationship writes**.

**Cleanup:** after evidence is saved, use only the separately authorized cleanup plan to close/remove the test PRs and issues and delete the test repository; remove the local clone. Do not mark a PR ready or merge it as smoke cleanup.

## 2. Execute one task through delivery

**Prerequisites:** a newly published P/A/B/C graph, A's exact canonical issue URL, a clean isolated task checkout at the fixture `BASE_SHA`, an authenticated supported host that can load the actual Execute and Commit skills, and separate draft-PR write permission. Use a fresh copy of the shared fixture if A was already delivered through Orchestrate.

**Setup:** leave `a.txt` empty on the admitted baseline. This makes the required check observably fail before implementation while keeping the fixture deterministic. Use this complete bounded input with the actual skill:

```text
Implement task A in the current isolated checkout. Replace the empty a.txt with
the single line A. Do not edit b.txt, c.txt, sibling issues, Project state, or
parent P. Acceptance is a.txt containing A. Observe the required check failing
before the change, then pass it after the minimum change; run the same command as
the smoke scenario. Commit and deliver exactly one draft PR through Commit with
base main and exactly one Resolves line for the selected A issue.
```

**Invocation:** use the current issue-URL entry contract (bounded input plus `--issue`, issue URL
alone, or `--issue` alone per the Execute skill):

```text
/woostack-execute <the complete bounded input above> --issue <A-issue-url>
```

**Assertions:**

- The focused check first fails with the empty baseline and later passes after the one-file change; the smoke is the passing focused command. No final pass is substituted for Red evidence.
- The commit changes only a.txt. The draft PR is unique, open, based on main, and has the recorded task head SHA.
- Full PR read-back contains exactly `Resolves <A-issue-url>` once. B and C have no execution worker, branch, commit, or PR, and P has no lifecycle write.
- The actual-host record names the revision, host, exact invocation, check output, commit, and canonical PR read-back. With no separately authorized live issue/PR fixture, report this recipe **Unrun — no authorized A issue and draft-PR test repository**.

**Cleanup:** preserve the evidence, leave the PR draft and unmerged, then follow the separately authorized disposable-repository cleanup. Remove only the local task checkout after confirming it has no retained user work.

## 3. Orchestrate scheduling and recovery

**Prerequisites:** a newly published P/A/B/C graph, a clean fixture repository, a supported host with the actual Orchestrate skill and delivery-capable Execute subagents, and separate permission for their draft-PR writes. The host must expose a safe worker interruption or stop receipt if the unknown-result variant is attempted.

**Setup:** first run the focused deterministic regression through the shipped production helper:

```bash
PYTHONPATH=skills/woostack-orchestrate/scripts/tests \
python3 -m unittest -v \
  test_orchestrate_behavior.OrchestrateBehavior.test_full_issue_smoke_uses_real_git_and_concurrent_execute_packets \
  test_orchestrate_behavior.OrchestrateBehavior.test_ci_failure_dispatches_one_bounded_repair_and_rechecks_new_head \
  test_orchestrate_behavior.OrchestrateBehavior.test_verified_repaired_parent_releases_dependent_task \
  test_orchestrate_behavior.OrchestrateBehavior.test_ci_repair_reopens_only_after_authoritative_release_proof \
  test_orchestrate_behavior.OrchestrateBehavior.test_reconcile_existing_pr_verifies_without_second_worker \
  test_orchestrate_behavior.OrchestrateBehavior.test_fresh_reuse_blocks_unowned_dirty_existing_worktree \
  test_orchestrate_behavior.OrchestrateBehavior.test_fresh_reuse_blocks_unowned_committed_existing_branch
```

This is **deterministic helper evidence**, not model evidence. It crosses
`scripts/orchestrate.py` through `recording_driver.py` in temporary Git
repositories: A/B scheduling, C stacking on unmerged A, one same-PR CI repair
with stale-head rejection and fresh dependent release, safe released-worktree
reopening, unknown-result reconciliation without a second worker, and
preservation of unrelated dirty and committed work. Recorded mock checks and
repairs prove controller coordination only — never model diagnosis or live
GitHub execution — and must be labeled as a deterministic controller simulation,
not an actual-host pass.

**Invocation:** run the actual skill in the supported host:

```text
/woostack-orchestrate --issue <P-issue-url> --max-parallel 2
```

The first wave must schedule A and B, not C. Preserve each native host/session/worker identity and the controller's reservation. The run stays active after A/B workers stop: it keeps observing their admitted PRs' remote checks while the session continues. For the recovery variant, stop only B after its branch or PR may exist but before its result is accepted. Resume the same scope only after direct evidence proves the worker stopped. If the host cannot stop and identify B safely, mark the actual-host recovery **Unrun**. No new live resources beyond the already-authorized disposable repository and draft-PR writes are required by this recipe.

**Assertions:**

- C is absent from the first wave. After A's PR, focused checks, independent validation, and delivery-note read-back pass, C is scheduled on A's verified unmerged branch/SHA; no merge is required.
- Unknown B retains its original reservation and ownership. Reconciliation reuses one matching branch/PR and never creates a duplicate. Only a complete proved PR-absence receipt may release one same-identity repair worker on the same branch/workspace.
- A later actionable remote-check failure on A's current head is diagnosed and coalesced into at most one Execute repair on A's retained branch/PR under the shared cap; unrelated work continues. Stale-head results never validate the new head, and pending or unreadable checks never count as a pass. Observation ends with the session: no daemon, merge, or post-session monitoring.
- An unrelated dirty or committed worktree remains byte-for-byte intact and blocks reuse. No controller, parent, sibling, or user workspace is overwritten.
- The actual-host record names the revision, host, exact invocation, worker identities, A/B/C schedule order, recovery receipt, and canonical PR read-backs. The recording-driver run is reported separately and never as an actual model/host pass.

**Cleanup:** leave delivered PRs draft and unmerged, stop task-owned workers, retain controller evidence until the run is recorded, then use only the separately authorized disposable-repository cleanup. Remove task worktrees only after verifying they contain no user work.
