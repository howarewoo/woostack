# Workflow smoke

These on-demand recipes cover material routing, Plan, Execute, or Orchestrate changes and regression investigation. They are not a corpus, a model grader, a mandatory check after every instruction edit, or a replacement test command. Run the smallest recipe that covers the changed behavior.

## Evidence classes and shared fixture

Label every result as one of these classes:

- **Deterministic helper:** a shipped script runs in a temporary local repository, such as the Init, Doctor, or docs-site asset tests. It proves shipped-helper behavior only; it never runs a model and never claims host execution.
- **Manual trace:** read the installed instruction path and record its owners, next action, and forbidden effects; this does not prove a model followed it.
- **Actual host:** the installed Plan, Execute, or Orchestrate skill runs in a supported coding host with real subagents where the workflow requires them. Record the repository revision, host, exact invocation, outcome, and relevant read-back.
- **Unrun:** the recipe was not attempted because its exact live-resource permission, host capability, or safe interruption facility is unavailable. Never report an unrun recipe as passed.

The live recipes (§1.4, §1.5, 2, and 3) use these fixture issues in one disposable repository;
§1.4 files only A and C, while §3 separately sets up B and P:

```text
P  readable index issue naming the three issues below
A  independent
B  independent
C  blocked by A
```

The native sub-issue and dependency links are evidence, not the only record: when that capability
is unavailable, the same facts are readable in issue content and P's index.

Before any live recipe, obtain separate permission for one exact disposable GitHub repository, the
issue writes the Plan filing recipe makes, any additional B/P issue writes for §3, the draft-PR
writes Execute/Orchestrate make, and the stated cleanup. Native relationship writes are requested
only where a recipe asks for them, and no recipe requires them. The repository must have no Project
requirement.

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

Use this same request for every Plan scenario, with only the stated variation:

```text
Goal: split a small repository change into PR-sized work and, when I ask for it,
record that work as issues in the repository named below.

Repository: https://github.com/<owner>/<test-repository>, branch main at <BASE_SHA>,
cloned at <local-directory>. Baseline evidence: README.md and an empty a.txt. No
implementation check has run.

Work:
- A: write the single line A to a.txt, changing nothing else. Verify with
  `python3 -c "from pathlib import Path; assert Path('a.txt').read_text() == 'A\n'"`.
- B: write the single line B to b.txt. Independent of A. Verify with
  `python3 -c "from pathlib import Path; assert Path('b.txt').read_text() == 'B\n'"`.
- C: write the single line C to c.txt after consuming A, leaving a.txt at exactly
  A. Blocked by A only, and no merge is required. Verify with
  `python3 -c "from pathlib import Path; assert Path('a.txt').read_text() == 'A\n' and Path('c.txt').read_text() == 'C\n'"`.

No Project, application, merge, or production deployment is included.
```

Variations: ask for no publication (§1.1); file only A and C, with C blocked by A, and create
nothing else (§1.4). Give the identical request again for the unknown-result retry in §1.5.

Keep credentials, host-private output, and personal data out of the fixture and its evidence.

## 1. Plan: planning only, destination resolution, and requested filing

**Prerequisites:** the shared fixture, a supported host that can load the actual Plan skill, and —
for §1.4 and §1.5 only — separate live-test permission plus a host able to use authorized GitHub
issue writes and read-back. This repository ships no deterministic Plan transport; an old normalized
Eval fixture is not one. §1.1–§1.3 need no disposable repository: point the request at any local
clone, or trace the installed text alone. They are **manual trace** recipes; a host run of one is
recorded separately under its own class.

**Setup:** for §1.4 and §1.5, use the fresh clone and the shared request above. Record `BASE_SHA`,
the installed Plan skill revision, and the canonical test repository before the first write.

### 1.1 A plan with no publication

**Invocation:** run the actual skill on the shared request with no publication instruction:

```text
/woostack-plan <the shared request above>
I want the plan only. Do not create anything in GitHub.
```

**Assertions:** the run returns one coherent plan covering the actual work, and it creates no
issue, Project, parent, marker, or relationship. It requires no template, no repeated confirmation
of facts the repository already shows, and no separate review invocation. Read the installed
instruction path once as a **manual trace** and record its owners, next action, and forbidden
effects; that trace is evidence about the installed text only and never counts as a host pass.

### 1.2 An unambiguous destination, then an ambiguous one

This recipe is the destination-resolution trace; §1.4 runs the same filing for real and checks what
was written.

**Invocation:** run the actual skill twice. First, on the shared request, whose repository is named
exactly:

```text
/woostack-plan <the shared request above>
File only A and C as issues, with C blocked by A, and create nothing else.
```

Then repeat it with the repository named only as "the repository", while the account can write to
two candidates:

```text
/woostack-plan <the same request> File only A and C as issues in the repository.
```

**Assertions:** with one named repository, the run resolves that exact repository and proceeds.
With two plausible candidates it asks which one and writes nothing until the user answers; it
never picks by title, recency, or search rank. This is a **manual trace**; the ambiguous case must
not be resolved by an invented default.

### 1.3 Known facts and one unresolved decision

**Invocation:** add to the shared request one verified fact and one open question the repository
cannot answer:

```text
README.md already documents the `version` column as text. The question I have not
decided: what the read endpoint should do when it is given an unknown version.
```

**Assertions:** the plan records the column as a verified observation and keeps the unknown-version
behavior as an open decision for the user. It neither invents an answer, blocks the whole plan
behind it, nor turns one open question into an approval ceremony. A follow-up request that settles
only that question resumes without restating the rest of the specification.

### 1.4 Filing two dependent issues with native relationship capability absent

**Prerequisites:** separate live-test permission, a supported host with authorized GitHub issue
writes and independent read-back, and no capability to create native sub-issue or dependency links.
Record which relationship capability the host actually lacks. If the host does expose those links,
run §1.4 anyway and report the missing-capability path as **Unrun — not exercised on this host**
instead of claiming it.

**Invocation:** run the actual skill on the shared request with the filing variation:

```text
/woostack-plan <the shared request above>
File only A and C as issues, with C blocked by A, and create nothing else.
```

**Assertions:**

- Independent read-back shows exactly two new issues in that repository, A and C, and no other
  issue, parent container, or Project.
- Each issue states its outcome, the constraints that matter, acceptance with its verification
  command, and the dependency that exists. The wording is the writer's; no prescribed heading set
  is required and none is invented to satisfy a template.
- The run states plainly which relationships it did not create. With the capability absent, that
  means the native `blocked-by` edge and any native sub-issue link, and it says so in those terms.
  It never describes a readable index as a native relationship, and it never reports a filing that
  was required to produce native links as complete.
- No implementation source, source branch, worktree, commit, PR, worker dispatch, approval, or
  merge occurred, and no issue was closed. A printed issue list alone is not evidence.
- The actual-host record names the revision, host, exact invocation, and direct GitHub read-back.
  If live permission is absent, report this recipe **Unrun — no authorized disposable GitHub
  repository and issue writes**.

### 1.5 Unknown create result

**Invocation:** interrupt only the Plan host after GitHub confirms creation of A but before the run
returns, then re-enter the identical §1.4 invocation. If the host cannot preserve the invocation
and stop it at that boundary, mark this variant **Unrun** rather than simulating a timeout. After
successful recovery, run the identical unchanged invocation once more.

**Assertions:** the retry discovers the existing A by its retained per-create identity and intended
content, reads it back, and continues from there. An unrelated issue with the same title and body
but no matching create identity is not adopted. If the identity was lost, recovery blocks rather
than guessing. It creates no second A, allocates no replacement identity, and repeats no create.
The unchanged repeat performs zero issue mutations. Recovery is decided by discovery before retry.

**Cleanup:** after evidence is saved, use only the separately authorized cleanup plan to close/remove the test PRs and issues and delete the test repository; remove the local clone. Do not mark a PR ready or merge it as smoke cleanup.

## 2. Execute one task through delivery

**Prerequisites:** the published A issue, its exact canonical issue URL, a clean isolated task checkout at the fixture `BASE_SHA`, an authenticated supported host that can load the actual Execute and Commit skills, and separate draft-PR write permission. Use a fresh copy of the shared fixture if A was already delivered through Orchestrate.

**Setup:** leave `a.txt` empty on the admitted baseline. This makes the required check observably fail before implementation while keeping the fixture deterministic. Use this complete bounded input with the actual skill:

```text
Implement task A in the current isolated checkout. Replace the empty a.txt with
the single line A. Do not edit b.txt, c.txt, the other fixture issues, or Project
state. Acceptance is a.txt containing A. Observe the focused check failing before
the change and passing after it; this same command exercises the changed path.
Deliver a draft PR through Commit with base main and a closing reference for the
fully addressed A issue.
```

**Invocation:** use the current issue-URL entry contract (bounded input plus `--issue`, issue URL
alone, or `--issue` alone per the Execute skill):

```text
/woostack-execute <the complete bounded input above> --issue <A-issue-url>
```

**Assertions:**

- The focused check fails before and passes after the one-file change; no extra smoke is required.
- The commit changes only a.txt. The draft PR is open, based on main, and has the recorded head SHA.
- PR read-back contains A's intended closing reference; B and C have no execution worker, branch,
  commit, or PR. If P exists, it has no lifecycle write.
- The actual-host record names the revision, host, invocation, check output, commit, and PR read-back.
  With no separately authorized live fixture, report **Unrun — no authorized test issue/PR repo**.

**Cleanup:** preserve the evidence, leave the PR draft and unmerged, then follow the separately authorized disposable-repository cleanup. Remove only the local task checkout after confirming it has no retained user work.

## 3. Orchestrate multi-task coordination and uncertainty

**Prerequisites:** published A/C issues from §1.4, separate permission to create B and P in the
same disposable repository, a clean fixture repository, a supported host that can load Orchestrate,
and separate permission for its draft-PR writes. A subagent primitive is optional: a host without
one runs the same scope sequentially in the calling session. The host must expose a safe worker
interruption or stop receipt to attempt the unknown-result variant.

**Setup:** with the separately authorized issue writes, create B with the outcome, acceptance, and
check from the shared request, stating that it is independent of A and C. Create P as a non-executable
index issue listing the exact read-back URLs of A, B, and C and declaring only C blocked by A; do
not claim native links that were not written. Independently read back B, P, and each indexed issue
before selecting P. If those writes are not authorized or cannot be verified, mark §3 **Unrun**;
do not invoke Orchestrate with a nonexistent P. A and B are independent roots at the admitted
baseline, C is blocked by A, and every other file, branch, and issue in the repository is unrelated
work. Read the installed instruction path once as a **manual trace** — its owners, next action, and
forbidden effects — before running it. That trace is evidence about the installed text only and
never counts as a host pass.

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
| Plan a change or a goal | woostack-plan; no publication owner unless filing is requested | One coherent plan, then stop | GitHub writes, a required template, or a separate review call |
| File issues from a plan | woostack-plan plus its GitHub publication context and procedure | Write the requested issues and read them back | Inventing a parent graph, a Project, or an unrequested destination |
| Plan an unproved defect | woostack-plan → Debug, then correction planning | Prove cause before planning | Source edits from an unproved theory |
| Execute a complete inline bounded task | woostack-execute; source and runtime evidence, source control at delivery | Deliver the bounded outcome in one commit and one PR | Guessed repair, mandatory Debug handback, or Project/provider graph discovery |
| Execute one exact issue URL | woostack-execute; exact-issue read, then Commit association | Deliver the bounded outcome | Dropping the issue, siblings, or Project discovery |
| Commit without an issue | woostack-commit; source control only | Deliver scope-limited changes | Association/profile reads |
| Explicit Reflect | woostack-reflect; exactly one invocation | One report-only pass | Automatic reflection on every final reply |

**Assertions:** every row resolves to exactly one skill, and each owner it loads is that skill's own
reference rather than a router-wide rule. Orchestrate alone owns multi-task coordination, and the
router's remaining gates still resolve.

**Delivery edge traces (manual instruction evidence):**

| Case | Owner and next action | Forbidden effect |
| --- | --- | --- |
| Two related fully addressed issues, one authorized PR | Execute admits combined scope; Commit reads both exact issues and preserves both closing references | One-issue/one-PR rejection or closing only partially addressed work |
| Dependent branch, optional stack capability absent | Commit delivers and reads back branch/base PR; labels registration unavailable | Blocking verified code or claiming registration |
| Explicitly required stack registration unavailable | Commit preserves verified code/PR and reports registration incomplete | Claiming requested metadata succeeded |
| Lost PR-create response | Commit queries matching head PR and remote ref before retry | A duplicate PR or commit from assumed absence |
| Previous writer may still be active | Workspace owner stops reuse pending proven exit/relinquishment | Starting another writer by serializing alone |

These traces inspect instructions only. Actual GitHub stack/PR mutations require separate live
permission; do not mislabel these rows as actual-host results.

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
| Exact issue Execute | Trace §4 with A's exact issue selector; live variant §2 only with separate permission | **Manual trace:** exact issue and relevant comments read; Commit revalidates association; no sibling/Project discovery |
| Plan without publication; unproved defect | Trace §1.1 and §1.3 with the shared request, then with an unproved defect instead | **Manual trace:** Plan returns a plan with no GitHub write; a verified fact stays an observation and the open question stays a user decision; a defect goes to Debug before correction planning |
| Authorized bounded correction | Trace §4 with a proved defect and a separately authorized correction | **Manual trace:** Execute can establish cause inline before repair; no mandatory Debug handback |
| Requested issue filing | §1.4 live only with separate issue-write permission; §1.5 unknown-result variant likewise | **Actual host:** only the requested issues exist, each read back; a missing native edge is reported as missing, and a lost create is recovered by discovery. **Unrun** with a reason when no authorized disposable repository or safe interruption exists |
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
the inline/issue-backed/Plan traces above. Record commands and outcomes, including failures.

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
