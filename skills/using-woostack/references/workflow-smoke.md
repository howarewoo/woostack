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
git init -q
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
- Commit owns the commit and PR submission; without authorized remote access, report
  that delivery boundary **Unrun**, retaining the local check output and diff as evidence,
  not claiming a delivered Execute run.

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

## 3. A and B with C blocked by A, an interrupted writer, and sequential fallback

**Invocation:** run the actual Orchestrate skill on the same three tasks given as prose, in a clean
copy of the fixture. Prose, an issue list, and a tracker are all valid inputs; the host that cannot
open a worker is still a supported host.

With no authorized PR destination, local task ordering can be observed, but delivery and its
dependent-release gate remain **Unrun**; do not call local commits verified PR delivery.

**Observe:**

- C does not start until A's own delivery is verified and the required change is actually available
  in the base C selects, with its check passing there. No merge is required. A and B are
  independent roots.
- Parallel work is demonstrated only where the host gives safe isolation — separate workspaces and
  branches, never two writers in one workspace. On a host without that, the run completes the same
  scope one task at a time and labels itself sequential; one-at-a-time work is never reported as a
  parallel wave or as the independent review the user asked for.
- Interrupted-writer variant: stop one worker after its branch or PR may exist but before its result
  was accepted, then re-enter the same scope. The outcome is rediscovered from native worker state
  and current Git and PR facts before anything repeats — no second writer, no duplicate PR, and an
  honest report of what it could and could not prove. If the host has no safe interruption, record
  this variant **Unrun** rather than simulating a timeout.
- Work the run does not own survives: a dirty or committed worktree, an unknown branch, and
  unrelated issues stay intact and are never reused, overwritten, or cleaned.
- Each delivery is a draft PR whose checks and required review are read back at its current head;
  pending, stale, or unreadable results never count as a pass. Nothing is marked ready, queued,
  force-pushed, merged, or closed.

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
