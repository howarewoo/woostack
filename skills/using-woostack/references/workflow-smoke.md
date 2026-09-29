# Workflow smoke

Short, on-demand recipes for a material Plan, Execute, Commit, or Orchestrate change, or for
regression investigation. They are not a corpus, a grader, a mandatory gate after every edit, or a
test command: run the smallest recipe that covers the changed behavior, and report honestly what you
did not run.

The [router](../SKILL.md) and each owner skill — [Plan](../../woostack-plan/SKILL.md),
[Execute](../../woostack-execute/SKILL.md), [Commit](../../woostack-commit/SKILL.md), and
[Orchestrate](../../woostack-orchestrate/SKILL.md) — own their contracts. This guide only says how to
observe them; it never restates one. Retired commands and protocols stay retired: do not
reintroduce an alias, a replay path, or a compatibility shim to make a smoke pass.

## Evidence classes

Label each result with the class that actually produced it:

- **Deterministic helper:** a shipped script or the production asset parser runs locally. It proves
  that helper only; it never runs a model and never claims host execution.
- **Manual trace:** you read the installed instruction path and recorded its owners, next action,
  and forbidden effects. It says nothing about whether a model followed it, and it is never host
  enforcement.
- **Actual host:** the installed skill runs in a supported coding host, with real subagents where
  the workflow requires them. Record the revision, host, exact invocation, outcome, and relevant
  read-back.
- **Unrun:** not attempted, because the host capability, a safe interruption, or separate permission
  was unavailable. Name the reason; an unrun recipe is never reported as passed.

## Shared local fixture

Every recipe starts from a disposable local repository with one file and one check. It needs no
remote, no Project, and no live resource:

```bash
REPO=$(mktemp -d)
cd "$REPO"
git init -q -b main
git config user.name 'Workflow Smoke'
git config user.email 'workflow-smoke@example.invalid'
printf 'alpha\nbeta\n' > lines.txt
git add lines.txt
git commit -qm 'Seed smoke fixture'
```

Focused check for A (run before and after its edit):

```bash
python3 -c 'from pathlib import Path; assert Path("lines.txt").read_bytes() == b"alpha\n"'
```

Work only inside `$REPO`, and keep credentials, host-private output, and personal data out of it and
its evidence. Any remote write — a draft PR, an issue, a cleanup deletion — needs separate permission
for that one exact disposable repository first; no recipe below assumes it. When permission is
absent, record the remote step **Unrun** and keep the local observation. After saving evidence,
delete `$REPO`; if a remote fixture was created under permission, follow the authorized cleanup and
never mark a PR ready or merge it as cleanup.

## 1. Bounded local refactor or bug repair

**Invocation:** run the actual Execute skill on this bounded input, with no issue URL and no
Project:

```text
/woostack-execute
In this repository, `lines.txt` currently holds two lines, `alpha` and `beta`. Remove
`beta`, leaving exactly `alpha` and its trailing newline, and change nothing else. Run
the focused check above before and after the edit. Do not publish to a remote without
separate permission.
```

**Observe:**

- The focused check observably fails before the change and passes after it; that same command
  exercises the changed path, so no extra smoke is needed.
- The diff touches only the named file. There is no issue, Project, or provider-graph discovery and
  no source edit from an unproved theory.
- No commit or PR is requested, so the verified local diff is completion, not a failed delivery.
  Report the focused check and that no PR was submitted; GitHub access is unnecessary.

## 2. Plan ordinary content with unavailable relationship metadata

**Invocation:** run the actual Plan skill on a small goal covering two independent tasks and a third
that needs the first, asking for issues only when an authorized repository exists:

```text
Goal: tidy this repository. Task A: remove `beta` from `lines.txt`, leaving `alpha`.
Task B: add `notes.txt` describing the file. Task C: once A's change is available,
document the accepted single-line format in `README.md`; C depends on A only. Return
a plan; do not publish issues yet.
```

For an authorized live issue variant, name the exact disposable GitHub repository and request
publication. Exercise missing optional relationship writes only on a host that actually lacks
them; otherwise label that variant **Unrun**.

**Observe:**

- For published issues, verify their outcomes, constraints, out-of-scope, acceptance,
  verification, and real prerequisites against [What an issue carries](../../woostack-plan/SKILL.md#what-an-issue-carries),
  without imposing a heading template.
- Where the host cannot create a native sub-issue or dependency link, Plan keeps the issues it wrote
  plus a readable index and reports the missing relationships in those terms. It never calls a
  readable index a native edge, and it never calls an explicitly required native graph complete
  because it was not created.
- No source edit, branch, worktree, commit, PR, worker dispatch, or merge happened, and no issue was
  closed. A printed issue list is not evidence; [read-back](../../woostack-plan/SKILL.md#publishing-and-read-back)
  is.
- Without an authorized repository, record publication **Unrun** and keep the plan itself as the
  evidence.

## 3. Grouped, delegated Orchestrate delivery

**Invocation:** extend a clean copy of the shared fixture with a small helper and consumer:

```bash
cat > helper.py <<'PY'
def parse_lines(text):
    return text.splitlines()
PY
cat > consumer.py <<'PY'
from helper import parse_lines

def consume(text):
    return len(parse_lines(text))
PY
git add helper.py consumer.py
git commit -qm 'Seed helper and consumer'
```

In an authorized disposable GitHub repository, run the installed candidate in an actual coding
host with worker, task-worktree, and native stack capabilities. Record the exact installed revision
and resolved skill path. Keep a harmless unrelated sentinel edit in the primary checkout. Supply
only this explicit command and task descriptions, without a reminder to plan, delegate, or stack:

```text
/woostack-orchestrate

A1: Add `single_line(text)` to `helper.py`. Return the one nonempty line from input ending in a
newline; raise ValueError for empty or multiple lines. Keep `parse_lines` available.
A2: Add focused regression coverage for `single_line`: one accepted line, empty input, and two
lines. Run the checks with Python's unittest runner.
B: Change `consumer.py` to use the strict `single_line` behavior and return the accepted line
in uppercase. Keep this consumer change in a separately reviewable PR; check both accepted and
rejected input. The current consumer calls `parse_lines`.
C: Add `notes.txt` explaining the existing `lines.txt` fixture. Keep this unrelated change
separately reviewable.
```

No issue metadata supplies an edge. `B` names the new helper behavior and the source confirms the
consumer currently uses `parse_lines`; its dependency must be discovered before dispatch.
Without an authorized remote, mark the positive PR and native-stack steps **Unrun**. Do not call
local checks verified PR delivery.

**Observe:**

- The evidence-based plan precedes the first source write and worker dispatch. It groups A1/A2
  into one helper PR, keeps B as a separate dependent PR and C as an independent PR, states the
  required changes, intended parents and landing order, and safe parallel work. The source-level
  prerequisite for B is discovered without a declared edge; shared files alone create none.
- Each group gets a real worker in its own task worktree and topic branch. Sequential delegation is
  valid, including for one grouped PR; neither task implementation nor the sentinel touches the
  primary HEAD/index, and no two writers share a physical workspace.
- The B worker starts from the verified A1/A2 head containing `single_line`. Read back the root
  helper PR against trunk, B against the helper head branch, and independent C against trunk.
  Inspect their scoped diffs, draft state, head/base, checks, review, and task coverage. Native
  stack read-back confirms helper then B in order and the configured trunk; C is not a fake
  prerequisite. A chained base or a "depends on" comment is not stack membership.
- Re-enter the same completed scope and verify reuse/read-back without duplicate workers, branches,
  PRs, or stacks. If a required stack operation is genuinely unavailable, preserve valid work and
  report the unfinished delivery; do not simulate an outage or substitute another transport.
- Bare-reference/read-only input dispatches no implementation worker or publication. An explicit
  local-only Orchestrate run uses isolated workers but makes no commit, push, PR, or stack write,
  even if a task mentions a PR scenario. A host genuinely lacking workers reports the limitation
  rather than implementing inline; mark unavailable restricted-capability variants **Unrun**.
- If an actual worker result or write is lost, rediscover native worker state and Git/PR facts
  before retrying. Without a safe interruption point, mark this variant **Unrun**. Preserve unknown
  branches and unrelated edits. Nothing is marked ready, queued, force-pushed, merged, or closed.

## 4. Commit preparation, delivery, and content

**Invocation:** on a fresh copy of the shared fixture, prepare the intended removal yourself — drop
`beta` and run the focused check — then run the actual Commit skill on the already-prepared change,
issue-free and local-only. Repeat it with an unrelated unstaged sentinel, then with an unrelated
pre-existing staged sentinel. Add one run started from a nested directory. Finally, set
`commit.command` to a script that normalizes the intended file, and separately to one that exits
nonzero.

```text
/woostack-commit --no-pr-update
Commit the already-prepared removal of `beta` from `lines.txt`, leaving `alpha` and its
trailing newline. The focused check above is the required verification. Nothing else is in scope.
```

**Observe:**

- Only the intended change reaches the commit, and the reported SHA, subject, and verification match
  an actual `git show`. Unrelated unstaged bytes and a pre-existing staged blob keep their content,
  mode, and staging across the commit; their presence is not a blocker. Genuinely ambiguous mixed
  hunks in one file are left exactly as found, in whatever staging state they started in, and
  explained instead of guessed.
- A run started from a nested directory behaves identically, with no working-directory requirement.
- A `commit.command` that rewrites the intended file is reviewed, the affected check runs again on
  the new content, and the commit proceeds with the verified result. A required command or check
  that cannot pass blocks the commit and is reported unresolved. No check is skipped, no assertion
  weakened, and no side-effectful command rerun blindly.
- The local-only run performs no push, PR, stack, or issue write, reads no remote state, and says
  so in its report.

**With an authorized disposable remote, in that one repository:** cover an update to an existing
open PR, a branch whose earlier PR is closed or merged, a lost write response, and optional versus
required native-stack registration. Ask for `commit this and link #N` for one issue and for two
related issues, and for a PR update that must keep existing human text and readiness while a second
issue is only partially addressed. Include one repeat invocation with no new evidence and one
genuinely ambiguous issue reference.

**Observe:**

- The open PR for the branch is reused and the delivered diff is the whole cumulative PR. A closed
  or merged match is inspected and reasoned about, not a refusal. An ambiguous issue reference is
  asked about instead of guessed.
- A lost response is rediscovered before any retry, and no commit, PR, or comment is duplicated.
- Optional stack registration that is genuinely unavailable still leaves a valid commit and PR;
  required registration that cannot be verified is reported incomplete rather than assumed.
- Title and body describe the cumulative PR and are confirmed present as written after the write;
  human text and readiness survive untouched, a repeat adds no duplicate section, and a closing
  reference appears only for fully addressed work while partial work gets a non-closing one.
  Writing a reference is never reported as closing an issue, and no assignment, label, or Project
  state changes.
- Without the remote permission, mark these steps **Unrun** and keep the local observation.

## Installed integration

`pnpm -C site test` covers the catalog, the production parser, and the installed-collection case: it
copies the candidate under edit — the working tree's installable skill assets and retained
`.claude/skills` links, including uncommitted, staged, and untracked changes — into a disposable
directory, validates that copy with the checkout's production validator and catalog, resolves the
copied links, and rejects a link target that escapes the collection even when that target exists
nearby. It never writes to the checkout, and it reports on the candidate, never on a released
installation. `pnpm -C site build` checks the documentation application, not the installed runtime.

To validate an immutable committed release instead, run this from the source checkout on a
supported Unix host with Git, Node, and Bash. The parser is the checkout's production validator; the
assets it validates come from the export, and the printed revision is the release under test:

```bash
INSTALL=$(mktemp -d)
printf 'Installed release: %s\n' "$(git rev-parse HEAD)"
git archive HEAD skills | tar -x -C "$INSTALL"
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
# After saving the native output, remove only this disposable copy:
rm -rf "$INSTALL"
```

Those three runtime fixtures build their own disposable consumer repositories, so they need neither
the source checkout nor the docs application. They exist to prove preservation of retained and
legacy user bytes: point them at scratch directories, never at a real user's store. An unsupported
capability must fail before it writes, not fall back to another interpreter, lock implementation,
model, or transport. The [historical reader](../../woostack-init/references/artifact-backends.md)
owns retained-data capability failures.

**Checkout-only audits.** These need this repository and are never installed-runtime evidence:
`pnpm -C site build`, the direct `.claude/skills` link-discovery case that reads this checkout rather
than the disposable copy above, and the full Init runner
(`bash skills/woostack-init/scripts/tests/run-tests.sh`), whose ignore-file audit reads this
repository's own `.gitignore` rather than an installed template. The full Doctor runner
(`bash skills/woostack-doctor/scripts/tests/run-tests.sh`) is static and needs no checkout.

## Optional controlled comparison

Optional, and only on already-authorized execution resources — no paid benchmark run, no new live
test resources, and no new script, service, or committed metrics registry. Compare the previous
release, the new skills, and a no-Woostack baseline on the same task:

- Freeze the task text, repository state, model, host, permissions, and budget; vary only
  the installed skill condition (previous, new, or absent). Report a comparison **Unrun**
  when you cannot hold those constants.
- Record the outcomes that matter for the task, plus tool calls, retries, available tokens,
  elapsed time, and human corrections. A smaller prompt with more errors or retries is not an
  improvement, and greater autonomy is not a performance result without data.
- `wc -c` counts file bytes, not loaded context. List the files a run actually loaded, count each
  once, and record total package size separately from loaded instruction size.
- Keep the results in the task PR evidence, mark anything unavailable `unrun` with its reason, and
  report an unvalidated harness as unvalidated instead of claiming portability.
