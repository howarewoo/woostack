# Workflow smoke

These on-demand recipes cover material routing, Plan, Execute, or Orchestrate changes and regression investigation. They are not a corpus, a model grader, a mandatory check after every instruction edit, or a replacement test command. Run the smallest recipe that covers the changed behavior.

## Evidence classes and shared fixture

Label every result as one of these classes:

- **Deterministic helper:** a shipped script runs in a temporary local repository, such as the Init, Doctor, or docs-site asset tests. It proves shipped-helper behavior only; it never runs a model and never claims host execution.
- **Manual trace:** read the installed instruction path and record its owners, next action, and forbidden effects; this does not prove a model followed it.
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

## 3. Orchestrate multi-task coordination and uncertainty

**Prerequisites:** a newly published P/A/B/C graph, a clean fixture repository, a supported host that
can load the actual Orchestrate skill, and separate permission for the draft-PR writes its tasks
make. A subagent primitive is optional: a host without one runs the same scope sequentially in the
calling session. The host must expose a safe worker interruption or stop receipt to attempt the
unknown-result variant.

**Setup:** none beyond the shared fixture. A and B are independent roots at the admitted baseline, C
is blocked by A, and every other file, branch, and issue in the repository is unrelated work. Read
the installed instruction path once as a **manual trace** — its owners, next action, and forbidden
effects — before running it. That trace is evidence about the installed text only and never counts as
a host pass.

**Invocation:** run the actual skill in the supported host:

```text
/woostack-orchestrate --issue <P-issue-url>
```

On a parallel-capable host, start A and B independently, not C. On a sequential host, start one
ready root at a time. Each task runs in its own workspace and branch; record the host, session, and
worker identity actually used, if any. While the session stays active, use native completion/check
events or bounded observation of delivered PRs to fix failures in scope and reuse finished work.

For the unknown-result variant, stop only B after its branch or PR may exist but before its result
was accepted, then re-enter the same scope. Rediscover B's actual outcome from Git, PR, and native
worker state before acting on it. If the host cannot stop and identify B safely, mark the actual-host
variant **Unrun** instead of simulating a timeout. No live resource beyond the already-authorized
disposable repository and draft-PR writes is required by this recipe.

For the sequential variant, run the same scope in a host or mode that exposes no subagent primitive,
or one task at a time, and record which shape actually executed.

**Assertions:**

- C does not start until A's own delivery is verified at its current head and the required change is
  actually available in the base selected for C, with its check passing there. No merge is required.
- B's uncertain result is rediscovered rather than repeated: the run reuses the one matching
  branch/PR or continues the stopped task, never launches a second writer or a duplicate PR, and
  reports what it could and could not prove.
- Unrelated and unknown work stay intact. A dirty or committed worktree the run does not own is never
  reused, overwritten, or cleaned, and no parent, sibling, or user workspace is disturbed.
- The sequential variant completes the same scope one task at a time and labels itself sequential. It
  never reports one-at-a-time work as a parallel wave and never offers it as the independent review
  the user explicitly asked for.
- Each delivery is a draft PR whose repository checks and required review are read back at the
  current head; pending, stale, or unreadable results never count as a pass. Orchestrate never marks
  a PR ready, queues one, force-pushes, merges, or closes an issue, and the run ends with the session.
- The actual-host record names the revision, host, exact invocation, task start order, worker
  identities when the host exposed them, the uncertainty outcome, and canonical PR read-backs. The
  manual trace is reported separately and never as a host pass.

**Cleanup:** leave delivered PRs draft and unmerged, stop task-owned workers, retain evidence until
the run is recorded, then use only the separately authorized disposable-repository cleanup. Remove
task worktrees only after verifying they contain no user work.

## 4. Routing and reference-loading matrix

Read the router's table, follow each row to its named skill, and record the references that skill
loads on that path, its next action, and its prohibited side effects. Nothing live is required; the
result is **manual instruction-text evidence**, never a host result.

| Request | Route and loaded owners | Next action | Must not happen |
| --- | --- | --- | --- |
| Adopt/choose a workflow | using-woostack; project rules | Name one matching skill | Init, GitHub access, or loading all skills |
| Prepare a complete specification | woostack-prepare → Harden/Plan; publication references | Publish one issue graph and stop | Repeated Ideate questions; Execute/Orchestrate dispatch |
| Prepare an unproved defect | woostack-prepare → Debug, then correction planning | Prove a cause first | Source edits from an unproved theory |
| Execute a complete inline bounded task | woostack-execute; source control at delivery | One commit and one PR | Project/provider graph discovery |
| Execute one exact issue URL | woostack-execute; exact-issue read, then Commit association | One task's one PR | Dropping the issue, siblings, or Project discovery |
| Commit without an issue | woostack-commit; source control only | One commit; PR per the caller | Association/profile reads |
| Explicit Reflect | woostack-reflect; exactly one invocation | One report-only pass | Automatic reflection on every final reply |

**Assertions:** every row resolves to exactly one skill, and each owner it loads is that skill's own
reference rather than a router-wide rule. Orchestrate alone owns multi-task coordination, and the
router's remaining gates still resolve.

## 5. Installed integration matrix

Run from the candidate checkout on a supported Unix environment with Node, pnpm, Python 3,
Bash, and Git. The [historical reader](../../woostack-init/references/artifact-backends.md) owns
retained-data capability failures. No live GitHub fixture or paid model experiment is authorized by
this recipe; a live variant stays **Unrun** until separate permission exists.

First run `pnpm -C site test`: its installed-collection case exports committed skills and copies
retained Claude links to a temporary directory, invokes the production asset parser, and rejects
a checkout-only reference even when that target exists. The checkout test covers discovery too.
`pnpm -C site build` separately checks the documentation application, not the installed runtime.

From a committed candidate, export only tracked installable assets outside the checkout:

```bash
INSTALL=$(mktemp -d)
CANDIDATE=$(git rev-parse HEAD)
printf 'Installed candidate: %s\n' "$CANDIDATE"
git archive "$CANDIDATE" skills | tar -x -C "$INSTALL"
node --input-type=module -e '
  import { validateSkillAssets } from "./site/scripts/skill-assets.mjs";
  import { PUBLIC_ORDER } from "./site/scripts/gen-skills.mjs";
  await validateSkillAssets(process.argv[1], PUBLIC_ORDER);
' "$INSTALL/skills"
(
  cd "$INSTALL"
  bash skills/woostack-init/scripts/tests/test-config-precedence.sh
  bash skills/woostack-init/scripts/tests/test-run-store.sh
  bash skills/woostack-doctor/scripts/tests/test-health-checks.sh
)
# After saving native output, remove only this task-owned disposable copy:
rm -rf "$INSTALL"
```

These runtime fixtures create disposable consumer repositories and need neither the source checkout
nor the docs application. Run the full Init and Doctor runners in the actual checkout: Init also
audits checkout-only ignore files, which are not installed-runtime evidence. Keep output and the
exact candidate identity before cleanup. The retained reader, config and Doctor fixtures cover
preservation of user bytes; do not point
these scenarios at a real user's legacy store. Unsupported capabilities must fail before writes,
not trigger another interpreter, lock implementation, model, or transport fallback.

| Case | Reproducible setup / existing command | Expected observation and evidence class |
| --- | --- | --- |
| Checkout and installed layout | `pnpm -C site test`; disposable copy above | **Deterministic:** catalog and retained Claude links resolve, retired links are absent, local runtime references remain within installed assets; missing/escaping targets reject |
| Inline Execute; issue-free Commit | Trace §4 with shared task A, omitting issue selection | **Manual trace:** Execute implements; Commit owns submission; no issue/Project/profile load or artifact calls |
| Exact issue Execute | Trace §4 with A's exact issue selector; live variant §2 only with separate permission | **Manual trace:** exact issue and paginated comments read, Commit revalidates association; no sibling/Project discovery |
| Settled Prepare; unproved defect | Trace §4 with complete shared packet, then with an unproved defect instead | **Manual trace:** reuse settled decisions; defect goes to Debug before correction planning; Plan stops before implementation |
| Multi-task coordination without a subagent | Trace §4 into Orchestrate, then read §3's sequential variant | **Manual trace:** one skill owns order, concurrency, and each task's base; sequential execution is an allowed outcome that is reported as sequential, never as a parallel wave or independent review |
| Uncertain worker result | §3 unknown-result variant, live only with separate permission | **Actual host:** outcome rediscovered before any repeat; no second writer or duplicate PR. **Unrun** with a reason when the host exposes no safe interruption |
| Host inheritance, unsupported override, Unix helper | Trace installed host-mechanics/model-selection owners; run the installed Init/Doctor fixtures | **Manual trace:** native defaults inherited; unsupported exact override blocks without invented arguments. **Deterministic:** missing Unix capability rejects before mutation; legacy/config bytes preserved |

For each manual row record the actual relative paths read, next action and forbidden effects,
not a regex assertion on instruction wording. Actual-host/model trials remain **Unrun** unless
separately authorized and observed. A deterministic helper fixture is not a host trial.

## 6. Bounded same-task before/after measurement

Use audit baseline `e073b35f630b82de4d9361b596af2ed8da3743e8` and the exact final candidate
commit (record its binary diff hash). Export each revision with `git archive` into separate
disposable directories, without changing either source worktree. Use the same A/B/C tasks and
the inline/issue-backed/Prepare traces above. Record commands and outcomes, including failures.

Count UTF-8 bytes with `wc -c` for `AGENTS.md`, the router, and each selected workflow
`SKILL.md`. For each manual path, list its mandatory references explicitly and sum each loaded
file once; record conditional/unloaded references separately. Count all installed package files
separately: package size is not loaded context. Use `git diff --numstat BASE CANDIDATE -- skills`
and classify production `.py`/`.sh` changes separately from tests, docs and assets to report
added/deleted code lines.

Retain one evidence table with columns **metric/scenario**, **baseline**, **candidate**,
**command/paths**, **outcome/class**. Include root/router/workflow and mandatory-reference bytes,
total package bytes, production code additions/deletions, the installed smoke outcomes, and every
recipe class above. Use `unrun` with a reason instead of empty cells. Keep measurements outside hot
runtime instructions, for example in the task PR evidence. Run `git diff --check` on the final task
diff.

An optional actual-model comparison needs separate authorization. Freeze task text, consumer
repository commit, model/version, harness/version, tools, permissions/sandbox/network policy,
token/time budgets and sampling settings; change only the skill revision. Use equivalent fresh
sessions and three paired trials per chosen scenario, not a claim of statistical significance.
Record success/regressions, loaded instruction paths, host-supplied input/output tokens, tool
calls, retries, elapsed time, unnecessary clarifications, permission violations and human review
corrections. Separate the intentional reporting-policy improvement from behavior-preserving
comparisons. No Observe installation, model grader, service, telemetry prompts or CI trigger is
needed. Never infer tokens from bytes, unavailable latency gains or universal portability.
A smaller prompt with more errors or retries is not an improvement.
