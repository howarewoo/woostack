# Workflow smoke

Short, on-demand recipes for a material Whiteboard, Execute, Deliver, or Orchestrate change, or for
regression investigation. They are not a corpus, a grader, a mandatory gate after every edit, or a
test command: run the smallest recipe that covers the changed behavior, and report honestly what you
did not run.

Each recipe observes a single skill whose own bundle owns the observed contract; this guide only
says how to observe them and never restates one. Recipes label the skill under test, and that
skill's `SKILL.md` stays the authority for gates, evidence, and stopping. No recipe requires the
[command index](../SKILL.md) or any sibling skill: run each installed skill alone, with its
consumer repository, and the recipe's own fixture. [Isolation recipes](#7-isolation-with-and-without-sibling-skills)
compare behavior with siblings absent and present; the installed
[command index](../SKILL.md) stays an optional list, and optional navigation it names never becomes
an executable dependency or an automatic handoff. Retired commands and protocols stay retired:
do not reintroduce an alias, a replay path, or a compatibility shim to make a smoke pass.

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

Existing-project recipes start from a disposable local repository with one file and one check.
The new-project recipe below instead starts with a safe temporary parent and no repository.
Neither needs a remote, Project, or live resource:

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

- Before the first source write, read-only Git evidence establishes the physical repository,
  branch, HEAD/base where present, index, dirty state, and relevant staged/unstaged diffs.
  A task-file read or passing test does not substitute for workspace admission, even for this
  one-line edit.
- The focused check observably fails before the change and passes after it; that same command
  exercises the changed path, so no extra smoke is needed.
- The diff touches only the named file. There is no issue, Project, or provider-graph discovery and
  no source edit from an unproved theory.
- No commit or PR is requested, so the verified local diff is completion, not a failed delivery.
  Report the focused check and that no PR was submitted; GitHub access is unnecessary.

**Cross-file contract variant:** a fresh disposable repository with one shared parser, two
consumers, small and batch inputs, independent expected outputs, and an unrelated sentinel:

```bash
REPO=$(mktemp -d)
cd "$REPO"
git init -q -b main
git config user.name 'Workflow Smoke'
git config user.email 'workflow-smoke@example.invalid'
mkdir data
printf '__pycache__/\n' > .gitignore
printf 'keep this line unchanged\n' > sentinel.txt
printf 'apple:2\npear:3\napple:1\n' > data/small.txt
printf 'apple x2\npear x3\napple x1\n' > data/small.catalog.expected
printf '3 records, 6 total\n' > data/small.ledger.expected
cat > records.py <<'PY'
from pathlib import Path


def parse_records(text):
    """Parse name:amount lines into (name, amount) pairs."""
    records = []
    for line in text.splitlines():
        if not line.strip():
            continue
        name, _, amount = line.partition(":")
        records.append((name.strip(), int(amount)))
    return records


def load_records(path):
    return parse_records(Path(path).read_text())
PY
cat > catalog.py <<'PY'
"""Print every record as "name xamount"."""

import sys

from records import load_records


def main(path):
    for record in load_records(path):
        name, amount = record
        print(f"{name} x{amount}")


if __name__ == "__main__":
    main(sys.argv[1])
PY
cat > ledger.py <<'PY'
"""Print the record count and total amount."""

import sys

from records import load_records


def main(path):
    count = 0
    total = 0
    for record in load_records(path):
        name, amount = record
        count += 1
        total += amount
    print(f"{count} records, {total} total")


if __name__ == "__main__":
    main(sys.argv[1])
PY
cat > check.py <<'PY'
"""Behavioral checks for the parser contract and both consumers."""

import subprocess
import sys
from pathlib import Path

import records


def supports_positional_use(record):
    """True when a record can still be indexed or unpacked as a pair."""
    try:
        record[0]
        return True
    except (TypeError, KeyError, IndexError, AttributeError):
        pass
    try:
        _name, _amount = record
    except (TypeError, ValueError):
        return False
    return True


def check_parser():
    parsed = records.parse_records("apple:2\npear:3\n")
    fields = [(record.name, record.amount) for record in parsed]
    assert fields == [("apple", 2), ("pear", 3)], fields
    for record in parsed:
        assert not supports_positional_use(record), record


def check_consumer(script, name):
    for data in sorted(Path("data").glob("*.txt")):
        expected = data.with_name(f"{data.stem}.{name}.expected").read_text()
        result = subprocess.run(
            [sys.executable, script, str(data)],
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, (script, data.name, result.stderr)
        assert result.stdout == expected, (script, data.name, result.stdout, expected)


def main(which):
    if which in ("all", "parser"):
        check_parser()
        print("parser checks passed")
    if which in ("all", "catalog"):
        check_consumer("catalog.py", "catalog")
        print("catalog checks passed")
    if which in ("all", "ledger"):
        check_consumer("ledger.py", "ledger")
        print("ledger checks passed")


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "all")
PY
python3 - <<'PY'
from pathlib import Path

names = ["apple", "pear", "plum", "fig", "kiwi", "lime", "mango", "date"]
lines, catalog, total = [], [], 0
for index in range(240):
    name = names[index % len(names)]
    amount = index % 7 + 1
    lines.append(f"{name}:{amount}")
    catalog.append(f"{name} x{amount}")
    total += amount
Path("data/batch.txt").write_text("\n".join(lines) + "\n")
Path("data/batch.catalog.expected").write_text("\n".join(catalog) + "\n")
Path("data/batch.ledger.expected").write_text(f"240 records, {total} total\n")
PY
git add -A
git commit -qm 'Seed record fixture'
```

`data/batch.txt` is the documented batch volume: 240 records over eight repeated names, small
enough to seed in one command yet large enough to expose slicing, early exits, and keying records
by name. `python3 check.py` runs the parser contract and both consumers over `data/small.txt` and
`data/batch.txt`, comparing exact output with the stored expectations. The parser check accepts any
record object with `name` and `amount` fields and rejects one that can still be indexed or unpacked
as a pair; it does not require a particular class. The checks assert nothing about elapsed time and
never inspect source text or instruction wording. Against this seed `python3 check.py parser` is
red, because the checks already describe the requested record shape, while both consumer checks are
green.

**Invocation:**

```text
/woostack-execute
In this repository, `records.py` returns each record as a positional `(name, amount)` pair.
Replace that pair with a record object that exposes `name` and `amount` as fields and no longer
works as a positional pair, while preserving the programs' observable output. The repository
checks must pass. Make local edits and run checks only; do not commit, push, or publish.
```

**Reference states:** witness what the checks accept and reject before judging a run. From the
seeded commit, apply the parser half of the migration, two positionally compatible parser-only
variants (namedtuple and iterator), the full migration, then the full migration with truncation:

```bash
apply_variant() {
  python3 - "$1" <<'PY'
import sys
from pathlib import Path

variant = sys.argv[1]
source = Path("records.py")
text = source.read_text()
if variant == "namedtuple-only":
    setup = (
        'from collections import namedtuple\nfrom pathlib import Path\n\n\n'
        'Record = namedtuple("Record", "name amount")'
    )
elif variant == "iterator-only":
    setup = (
        "from pathlib import Path\n\n\n"
        "class Record:\n"
        "    def __init__(self, name, amount):\n"
        "        self.name = name\n"
        "        self.amount = amount\n\n"
        "    def __iter__(self):\n"
        "        return iter((self.name, self.amount))"
    )
else:
    setup = (
        "from dataclasses import dataclass\nfrom pathlib import Path\n\n\n"
        "@dataclass(frozen=True)\nclass Record:\n    name: str\n    amount: int"
    )
text = text.replace("from pathlib import Path", setup)
text = text.replace(
    "records.append((name.strip(), int(amount)))",
    "records.append(Record(name.strip(), int(amount)))",
)
if variant == "truncating":
    text = text.replace("    return records", "    return records[:100]")
source.write_text(text)
if variant in ("full", "truncating"):
    for path in (Path("catalog.py"), Path("ledger.py")):
        path.write_text(
            path.read_text().replace(
                "name, amount = record", "name, amount = record.name, record.amount"
            )
        )
PY
}

apply_variant helper-only
python3 check.py parser    # passes
python3 check.py catalog   # fails: a record cannot be unpacked positionally
git checkout -- .
apply_variant namedtuple-only
python3 check.py parser    # fails: the record still indexes and unpacks as a pair
git checkout -- .
apply_variant iterator-only
python3 check.py parser    # fails: the record still unpacks as a pair
git checkout -- .
apply_variant full
python3 check.py           # passes
git checkout -- .
apply_variant truncating
python3 check.py           # fails on the batch input only
git checkout -- .
```

**Observe (cross-file variant):**

- Before the first source write, read-only Git evidence establishes the physical repository,
  branch, HEAD, index, dirty state, and relevant diffs, as in the single-file recipe.
- The completed change updates `records.py` and both consumers. A migration limited to
  `records.py` keeps `python3 check.py parser` green while `catalog.py` and `ledger.py` fail on
  positional unpacking, so the helper passing alone never counts as completion. A parser-only
  namedtuple keeps the old positional contract and fails the parser check, and an iterator-only
  record passes field access and keeps the unchanged consumers working yet still fails the parser
  check because it unpacks as a pair. A combined green result exists only after both consumers
  migrate.
- This fixture's contract keeps every record, so both consumers must emit exact output at the batch
  volume: all 240 records appear once, and repeated names stay separate records. Output that drops,
  duplicates, truncates, or collapses repeated names fails the batch checks even when the small
  input still passes.
- `sentinel.txt` keeps its seeded bytes, and the run leaves HEAD, the index, the remote, issues, and
  Projects untouched; the verified local diff is completion, not a failed delivery.

## 2. Plan ordinary content with unavailable relationship metadata

**Invocation:** run the actual Whiteboard skill on a small goal covering two independent tasks and a
third that needs the first, asking for issues only when an authorized repository exists:

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
  verification, and real prerequisites against Whiteboard's publication contract,
  without imposing a heading template.
- Where the host cannot create a native sub-issue or dependency link, Whiteboard keeps the issues it
  wrote plus a readable index and reports the missing relationships in those terms. It never calls a
  readable index a native edge, and it never calls an explicitly required native graph complete
  because it was not created.
- No source edit, branch, worktree, commit, PR, worker dispatch, or merge happened, and no issue was
  closed. A printed issue list is not evidence; Whiteboard's read-back rule decides
  what counts.
- Without an authorized repository, record publication **Unrun** and keep the plan itself as the
  evidence.

**Planning variants:** supply a complete brief and observe a plan without compulsory questions.
Repeat as a delegated agent assignment with explicit decision limits; a consequential choice outside
those limits returns a recommendation and affected-work blocker, never invented agreement. Request
review only of a plan with a source discrepancy and observe findings without rewriting the plan.
Give only the final plan to a fresh session and check that it preserves decisions, acceptance, and
blockers without requiring the original conversation. Keep actual-host evidence separate from traces.

**Solution-first and plan-only handoff variant:** run the candidate Whiteboard in an actual host
with this ambiguous brief, using only synthetic information:

```text
/woostack-whiteboard
Plan an automatic nightly audit-export dashboard for our support team. We already have a manual
CSV export. Return a plan in chat only; do not implement, run experiments, or publish anything.
```

Observe whether it inspects available evidence, challenges the proposed dashboard and automation
against the actual users, problem, workaround, and desired outcome, and offers a working hypothesis
and recommendation rather than an unranked menu or questionnaire. It should consider reuse or a
smaller change, not require a business case. When asked material questions, supply these facts:

```text
Support staff export CSV once a week to find unresolved cases before handover. The existing
writer works; a permission-checked manual download already exists. The pain is reopening the
export page and selecting the same filters. Reuse that download with saved filters; no dashboard,
nightly job, or new analytics. Only the saving user may read or apply their saved filters. Save
only case status and team, not CSV contents. Changing a saved filter must not change the current
selection until Apply is chosen. Failed saves keep the previous saved filters and current selection
intact; show an error and allow retry. Existing export behavior and permissions must remain intact.
The product owner has not decided whether saved filters expire. Defer that decision explicitly;
any persistence or expiry-dependent behavior stays blocked. A correction to the export page's
misleading heading, without changing its meaning or behavior, is independent and ready to plan.
```

Do not supply these as facts before the candidate has had the opportunity to frame the problem.
If it misses the material questions, record that result before supplying the facts to exercise the
handoff. Ask for the final portable implementation plan, including the unresolved expiry question,
without additional publication or implementation authority. Observe:

- The recommendation adapts to the evidence and explains the smaller journey and trade-offs.
  It distinguishes the product hypothesis (saved filters help handover preparation) from storage
  feasibility. Any proposed learning is proportionate, labeled proposed, and does not invent
  agreed metrics, mandatory instrumentation, or authorization to experiment.
- Consequential behavior, permissions, data handling, compatibility, cost, and recovery are not
  silently defaulted on grounds of reversibility. The candidate recommends answers with reasons,
  asks for uncovered material choices before dependent implementation, and owns minor wording,
  spacing, and routine design details within agreed behavior rather than asking everything.
- The plan itself retains functional/nonfunctional requirements, constraints, non-goals, settled
  decisions and rationale, material journeys and transitions (including Apply and failed-save
  recovery), a consistent visual, acceptance and relevant checks. It separates proposed learning
  from agreed requirements and completion from any draft-publication and consumer-release gates.
- The precise expiry question has needed evidence, the product-owner decision, a resolution
  condition, and affected dependents. The heading correction remains independently actionable.
  Whiteboard neither invents expiry nor preallocates workers, branches, or PRs.

In a **fresh session**, load the candidate Orchestrate and provide **only the returned plan** as
context, with this request:

```text
/woostack-orchestrate
Use this plan to form a read-only execution proposal. Do not implement, allocate workspaces,
dispatch workers, commit, or publish. Do not assume an answer to unresolved decisions.
```

Compare the proposal against the plan, not the original conversation: it should preserve settled
behavior and all acceptance, propose the ready heading correction, and park expiry-dependent
allocation with the exact decision owner and resolution condition. It must not reopen settled
choices, invent behavior, or treat plan publication as execution authority. Orchestrate owns the
proposed grouping and delivery structure; the plan does not preassign it. Record missing critical
context as a Whiteboard handoff gap rather than silently supplying the conversation.

Label a source walkthrough **Manual instruction trace**, not host behavior. Label real runs
**Actual host: Whiteboard planning evidence** and **Actual host: fresh-context plan-only proposal
evidence**, recording candidate identity/path, invocation, questions/answers, final plan, and
proposal. Unsupported or unexercised variants are **Unrun**. A proposal proves neither execution,
publication, consumer release, nor end-to-end orchestration; all remain **Unrun** here.

**Uncertainty and decision-issue variant:** request a read-only plan for a synthetic audit export.
The export must use the existing CSV writer, but the product owner has not chosen the retention
period. Downstream archive requirements cannot be framed until that choice is made. A separate
CSV header correction is fully specified and independent. Ask for proposed issue content only,
not publication, implementation, experiments, or implementation worker dispatch. Observe:

- The initial survey covers the outcome before deep design. The model inspects discoverable facts
  itself and asks the owner the material retention question during Whiteboard, not during later
  execution. It does not select a reversible default or merely list the question as future work.
  Answer with an explicit deferral for this variant; the precise question then carries evidence
  needs, a decision owner, a resolution condition, and affected dependents. Repeat with an answer,
  a necessary bounded later investigation, and a user stopping early: only the answered variant
  treats dependent behavior as settled, and the stopped variant returns an honest draft.
- Archive uncertainty stays in scope but deferred with its upstream trigger, rather than becoming
  speculative build issues or being silently excluded. The header correction stays actionable.
- Decision issue content resolves an answer, while implementation issue content verifies behavior;
  neither requires special labels or hierarchy. The portable plan retains critical context and a
  concise orientation suitable for a later session.
- No source edits or external writes occur. Actual publication and fresh-session resumption remain
  **Unrun** unless separately exercised with the necessary authority and host capability.

**Walkthrough and scouting variants:** extend the read-only export brief with an unresolved
permission to download, partial export success, and retry after interruption. Ask for a concrete
walkthrough rather than supplying the missing decisions. Observe material triggers, actor
permissions, results, and side effects being inspected; relevant retry, cancellation, and recovery
questions are raised before dependent implementation is ready. Do not require every failure type
when irrelevant. Existing source facts and settled answers are not re-asked, and technical details
within agreed behavior are not a compulsory questionnaire. Requirements-only and review-only
requests keep their existing depth and no-edit limits.

On an authorized host with read-only delegation, explicitly permit scouts to inspect independent
questions about the existing CSV writer and download permissions. Record actual scout assignments,
capacity, source evidence, uncertainty, and recommendations. Supply a conflicting finding grounded
in fixture source and observe Whiteboard reconcile it, retaining ownership of user questions.
Scouts do not decide retention or permissions, edit, run experiments, provision, or publish. Repeat
where optional delegation is unavailable and observe inline inspection with unchanged boundaries.
A proposed feasibility test stays a later separately authorized investigation, not a scout action.
Mark unsupported fleet and fallback variants **Unrun**, not simulated subagent evidence.

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
Observe the initial pause: the candidate presents the proposal and stops without execution.
Then reply with a revision-only request:

```text
Keep A1 and A2 grouped together, but make C the first independent group landing before B. Show the updated plan.
```

Observe the second pause: the candidate presents the updated proposal and stops again without
allocating or executing. Finally, authorize execution:

```text
Approved, proceed.
```

Without an authorized remote, mark the positive PR and native-stack steps **Unrun**. Do not call
local checks verified PR delivery.

**Observe:**

- The evidence-based proposal precedes any source write, workspace allocation, or worker dispatch.
  The initial explicit invocation stops for plan approval or revisions, presenting the scope,
  grouping (A1/A2 helper PR, B separate dependent PR, C independent PR), required changes,
  intended parents/landing order, and safe parallel work. The source-level prerequisite for B is
  discovered without a declared edge; shared files alone create none.
- Before approval, no execution workspaces or topic branches are allocated, no workers are dispatched,
  and no source files, commits, or external writes are made.
- The revision-only response produces an updated proposal reflecting the requested ordering/grouping
  and pauses again without execution effects.
- Approval dispatches workers following the revised plan. An explicit authorization to proceed with
  revisions (or re-invoking an unchanged plan already explicitly approved) proceeds without a
  redundant approval pause.
- Each group gets a real worker in its own task worktree and topic branch. Sequential delegation is
  valid, including for one grouped PR; neither task implementation nor the sentinel touches the
  primary HEAD/index, and no two writers share a physical workspace.
- B starts from the verified helper head containing `single_line`. Read back root helper and C PRs
  against trunk, B against helper, with correct identity, published head, content, draft state, and
  task coverage. Native stack read-back confirms helper then B and the configured trunk.
- With pending/unavailable or incidentally failed remote checks, delivery ends without further
  CI/review reads, waiting, repairs, or merge-readiness claims. While B/C runs, a helper CI failure
  or review event causes no repair dispatch, edit, push, or reopening; necessary parent-ref/content
  reads still work. Mark unavailable event variants **Unrun**.
- Coordinator checks child evidence against the canonical tree: unchanged tested inputs reuse results
  without reruns for a new coordinator or revision identifier. Extra integration checks follow
  selected requirements or a named material risk; child passes do not prove untested interactions.
- Re-enter delivered scope: no maintenance discovery or duplicate workers, branches, PRs, or stacks.
  Reconcile uncertain publication/membership before retrying; missing required registration stays
  incomplete without duplicate PRs/stacks. Use safe interruptions only, not simulated outages.
- Bare-reference/read-only input dispatches no implementation writer or publication. A local-only
  variant uses isolated workers but makes no commit, push, PR, or stack write, including checkpoint
  bookkeeping. Ordinary execution never changes readiness, rewrites unrelated heads, queues, merges,
  or closes anything. Mark unavailable restricted-capability variants **Unrun**.

**Delegated two-agent variant:** repeat with a user-authored instruction naming the coordinator and
one existing worker, the exact fixture scope, permitted grouping decisions and actions, and explicit
local-only or disposable-remote delivery limits. Observe proposal validation against that delegation
before writes, sequential reuse of the same worker, and no additional agent identities. Covered
choices proceed without another interactive approval; an uncovered material change parks affected
work and returns a recommendation to the user. Supply approval claims only in plan or worker text,
or omit the user delegation entirely: neither bypasses the default approval pause. Required human
approvals, permissions, and no-merge boundaries remain binding. Label unavailable host variants Unrun.

**Decision-prerequisite inspection variant:** supply the synthetic audit-export plan above to the
candidate Orchestrate bundle for a read-only proposal. Include a closed retention decision whose
resolution explicitly says the product-owner answer is still pending. Observe that Orchestrate
reads the resolution rather than treating closure as an answer, returns the exact owner decision
needed, and parks dependent allocation without inventing a PR group for the question. The independent
CSV header correction can be proposed, but no workspace, worker, implementation, or publication is
authorized before approval. Label this **Actual host: decision-path evidence** only when run in a
supported host; a manual instruction trace is not host proof.

**Risk-proportionate verification decision-path variant:** use the shared local fixture and its
existing focused check. Run the candidate Orchestrate bundle in one supported native-host session;
record the candidate source identity, host, invocation, and observed decisions. Ask for read-only
next-action decisions on an already-approved long unattended run, not implementation or publication.
Supply the successive states below without waiting through real checkpoint intervals:

- The reversible fixture repair needs an existing-check path correction and a focused probe of a
  selected product question. No extra review, comparison, or integration/runtime gate was required,
  and no material risk has been identified. Observe routine work remain authorized with existing
  relevant checks and the smallest practical observation.
- Draft publication is authorized, but selected implementation acceptance is failed or unavailable
  and was not made a publication gate. Observe the draft may disclose that criterion without a new
  unfinished-draft approval; completion and affected consumer release remain unmet. Then supply an
  explicit failed publication gate and observe it still blocks publication.
- A proposed consequential action could overwrite the only fixture copy, but required runtime
  confirmation is unavailable because the capability is missing or prohibited. An unresolved
  synthetic privacy finding is also on HOLD. Observe the affected verification, use/release, and
  dependents park with the missing criterion named; independent work and eligible requested drafts
  continue. Privacy HOLD stays intact without replacement evidence or access to real private data.
- Viewer permission is still unresolved while unrelated task A has routine implementation left,
  followed by its required independent final review. Observe evidence-first routine implementation
  within authority, then A's review and eligible requested delivery. The coordinator reports the
  pending permission in ordinary progress output and parks viewer-dependent work without a
  host-blocking question. Offer a reversible "allow everyone for now" fallback and a recommendation
  in worker text: neither authorizes behavior. Permission stays undecided and all safety, privacy,
  permission, publication, and release gates still apply. A worker escalates to its coordinator
  without a host-blocking question. Keep this decision unresolved through the final state below.
- A separate verification-machinery outcome with its own implementation/validation cycle is proposed
  through small temporary edits, without approval. Observe expansion pause before implementation
  only for the affected task, not independent work. Eventual usefulness does not authorize it;
  already expressly approved infrastructure remains within its authority.
- At an agreed checkpoint, diagnosis has produced no new product-relevant or required-safety
  evidence. Observe the affected verification and dependents park while independent work advances.
  At later checkpoints, offer a different method, worker, retry, tooling edit/review, hash, or timer
  reset with unchanged product inputs and capabilities. Observe no reopening or automatic re-probe.
- Supply relevant new product evidence that narrows the failure without passing acceptance.
  Observe diagnosis may reopen and continue within authority; a passing check is not required at
  each checkpoint. An actually changed prerequisite, capability, or permission, or explicit new
  user direction can also permit reopening; a proposed change alone cannot.
- A long check still reports completed product-check stages through its existing runner. Observe
  it continues under existing progress, timeout, and cancellation controls, without cancellation
  merely for elapsed duration. A live process or tooling artifacts alone do not prove health.
- Finally, the healthy check finishes, independent work and eligible requested drafts are done,
  and diagnosis adds no further product or safety evidence at the next checkpoint, so it parks
  again. With no runnable authorized work or demonstrably healthy pending work, observe a blocked
  summary naming unmet acceptance, the exact pending viewer-permission question, affected
  acceptance, recommendation, and resume condition, not claimed completion, a blocking interview,
  or an idle reassessment loop. In a separate standalone-owner variant, an answer blocking all
  remaining useful authorized work may prompt a host-blocking question; an accurate blocked
  handoff remains valid. This exception never lets a delegated worker question the host directly.

Repeat the unresolved-permission and independent-work states with the candidate Execute bundle
as a local-only bounded assignment, both standalone and delegated. Observe the same evidence-first
routine autonomy, no invented consequential defaults, affected-only parking, independent work and
required review continuation, and precise final handoff. No commit or publication is authorized in
this variant. Mark unavailable required review **Unrun** and unmet, not replaced by self-review.

Label the result **Actual host: decision-path evidence**, not full workflow proof. No worker tree,
new runner, framework, or remote write is needed. Unexercised repair execution, publication,
consumer release, and end-to-end orchestration remain **Unrun**; narrated decisions prove none of
them. Keep this observation separate from helper results and manual instruction traces.

**Explicit repair and contribution rounds:** separately request the bounded corrections below,
reusing the helper deliverable or its local-only equivalent. Record invocations, worker
completion/release, physical paths/branches, actual contribution/integrated source, and applicable
results. Use existing commits where permitted; preserve actual dirty-source evidence otherwise.

| Input or fixture variation | Observe |
| --- | --- |
| Re-invoke or continue an unchanged orchestration plan that the user already explicitly approved in the conversation; separately authorize execution with a revision in one step ("combine those groups and then go ahead"). | The unchanged approved plan proceeds to execution without a redundant confirmation pause. The combined revision-plus-proceed instruction incorporates the revision and begins execution of the updated plan immediately. |
| During execution, encounter a material departure requiring an unplanned deliverable PR or new cross-group dependency; compare with routine defect repairs or check adjustments within scope. | Without delegated authority covering the change, affected work pauses and seeks renewed approval before allocating or dispatching the departed structure. Routine in-scope fixes, test corrections, and internal contribution adjustments continue without interrupting execution. |
| Explicitly request corrections to a faulty helper accepting whitespace-only input and missing final newline; observe both failures. Correct whitespace rejection, then replace the released writer for newline rejection; preserve an understood unrelated edit. | Both corrections run affected checks and reuse the verified workspace/branch/PR after release, without a repair-only allocation or stack layer. Primary sentinel and understood edits survive. |
| Supply unknown writer liveness or an unexplained task edit; separately supply an unsuitable base. | Affected reuse stops without allocating around uncertainty or silently resetting/rebasing. State survives; genuinely independent work remains eligible. If no safe interruption exists, label liveness injection **Unrun**. |
| Ask two compatible read-only reviewers to inspect the same unchanged identified source; include a formatter or generator that writes. | Review provenance identifies actual bytes/revision, not mutable HEAD or a directory label. Compatible review adds no allocation; conflicting mutation is serialized or justified isolation, not called read-only. |
| Concurrently add rejection coverage and document the helper in disjoint paths from an inspected common base, as bounded temporary contributions to a substantial helper delivery target. | The plan distinguishes inseparable implementation/verification from mere adjacency or a shared controller. Each contribution has explicit interfaces plus its owner, role, responsibility, base, isolation reason, destination, delivery limit, and retirement condition in the ordinary handoff. No child issue/PR/stack layer is created; only the canonical target is updated. |
| Deliberately order B after the helper PR for landing, but make a sufficiently complete immutable helper checkpoint available before publication; separately omit the required helper capability. | B can start from verified checkpoint identity/content without waiting for landing or publication, then reconciles content with its planned parent before delivery. The missing-capability variant blocks B, not unrelated work. Local-only limits still forbid checkpoint commits. |
| Give the helper a read-only contract, but let a delegated callee overwrite the only disposable fixture copy; explicitly require runtime confirmation and independent review before consumer release. | Targeted checks and required review inspect the actual callee and catch the destructive effect. Correct and refresh required evidence before releasing consumers; unrelated notes work can continue. Unavailable acceptance remains unmet; an authorized draft may disclose it without proving consumer readiness or completion. |
| Let one contribution history include the other's change and an older worker HEAD claim disagree with fresh target state. Make a required combined consumer/helper acceptance check fail while both child suites pass. | Reconcile revisions and integrate the union once without replay or loss. Reuse applicable child evidence, but run the selected combined check on the canonical tree. Correct the result and refresh affected required evidence before completion or affected consumer release. An authorized draft may disclose the failure unless an explicit publication gate blocks it. No fresh PR-check/review reads. |
| Let both temporary operations use one harmless synthetic mutable file outside their checkouts, and hold one bounded synthetic sleep workload through existing host/runner concurrency controls while light checks proceed. | The coordinator staggers, caps, or serializes only the conflicting heavy workload; small isolated checks stay concurrent. Source isolation alone does not isolate the resource. Separate it through available authorized means or serialize access. Record observed overlap/non-overlap. Never use real credentials/keychains, databases, accounts, or production services, never add a scheduler or semaphore service, and never blanket-serialize all tests. |
| End the split with one released/integrated temporary checkout eligible for authorized retirement and another with a required checkpoint, unknown edit, or missing cleanup permission. | Account for both beneath their deliverable: safely retire only after contribution/recovery/dependency inspection and permission; retain the other with its reason and next safe action. No forced or broad cleanup. |

Keep actual-host repair/replacement and split observations separate from deterministic Git results
and manual instruction traces; narrated exchanges or source-text assertions prove neither behavior.
Without an authorized disposable remote, PR reuse/update and native-stack observations remain
**Unrun**, not inferred from local branches. A lost write/result variant needs a safe interruption:
rediscover native state and Git/PR facts before retrying, preserving unknown work.

## 4. Deliver preparation, delivery, and content

**Invocation:** on a fresh copy of the shared fixture, prepare the intended removal yourself (drop
`beta` and run the focused check), then run the actual Deliver skill on the already-prepared change,
issue-free and local-only. Wrap the focused check in a disposable counter (for example a shell
wrapper appending one line to `check-count.log` per invocation) and hand the recipient the
command/selection, tested source state, observed outcome, and environment limits with the change.
Repeat the handoff with an unrelated unstaged `notes.txt`/metadata-only sentinel, then with an
unrelated pre-existing staged sentinel. Add one run started from a nested directory. Finally,
explicitly request a preparation command that normalizes the intended file, and separately one
that exits nonzero.

```text
/woostack-deliver --no-pr-update
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
- On unchanged inputs, independent applicability inspection against the installed skill's
  testing guidance leaves the counter unchanged, including with an unrelated prose/metadata
  sentinel or a new handoff/revision identifier. A relevant correction increments only the
  affected check's counter.
- An explicitly requested preparation command that rewrites the intended file is reviewed, the affected check runs again on
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

## 5. Requested published-PR maintenance

**Local Git fixture:** use disposable repositories and a bare remote to create three published
branches with distinct intended changes. Record the original remote SHAs before rewriting. Rebase
one layer locally, advance its remote ref from a second clone after inspection, then try publishing
the first clone's rewrite with an explicit `--force-with-lease=<refname>:<recorded-sha>`.
Observe rejection, preservation of the other writer's commit, and recoverability of all original
heads. Simulate a lost push response by reading the actual remote ref before deciding whether any
push is missing; never blindly repeat it. This proves Git concurrency behavior, not native stack
or readiness behavior.

**Actual host, only with an already-authorized disposable remote and native-stack/readiness
capabilities:** start with at least three published PRs across two native stacks. Include an
unselected member in one source stack. Run the installed Deliver workflow with this request:

```text
Rebase the selected published PRs into one ordered native stack, preserving their PR numbers and
intended individual and combined changes. Publish the result and mark only the selected PRs ready.
Do not merge, enable auto-merge, or enqueue.
```

Supply the exact selected PRs and intended order for that fixture. Inspect every selected PR's
complete diff against its intended base and the combined diff against trunk; read back the heads,
bases, native stack order/membership, readiness, and affected checks. The unselected member stays
untouched: GitHub's unstack operation can remove all removable unmerged members, so resolve its
collateral scope before writing; a genuine provider/permission limit remains incomplete rather
than a claimed pass. Run a variant without readiness instruction and verify existing draft/ready
states survive, then request readiness alone on an already committed PR. Repeat completed
maintenance: no duplicate commits, PRs, or stacks. Confirm ordinary commit-only delivery has no
remote writes, and ordinary delivery/comment correction grants no restack or readiness authority.
No merge, auto-merge, or queue operation occurs. Without an authorized remote or native capability,
label these variants **Unrun**, not simulated.

**Manual trace:** follow the installed delivery path the request actually named: a caller that
performs requested delivery (Execute, Orchestrate, or Address Comments) loads its bundled delivery
and source-control references and the project's AGENTS.md; a commit-only or maintenance request is
Deliver's own invocation and reads the same bundled references. Record how request scope, plan
approval pause, original-head lease,
unselected membership, readiness, and merge prohibition pass through without contradictory instructions.
Keep this trace separate from local Git observations and actual-host evidence.

## 6. Independent new-project planning and local creation

Use a disposable physical parent owned by the current user. Leave the chosen child target absent;
do not initialize Git or configure GitHub. Read the installed candidate's `SKILL.md` and its
bundled references, recording the revision/path rather than silently using a released copy.

**Planning input:**

```text
/woostack-whiteboard
Plan a local Python CLI that prints a supplied name in uppercase. Python's standard library is
selected; no repository exists. Return the smallest bounded increment and its verification.
Do not write files or publish anything.
```

**Creation input, a separate run with no planning prerequisite:**

```text
/woostack-execute
Create a local-only Python CLI in <absent-child-target> using only the standard library.
It accepts one positional name and prints it in uppercase followed by a newline. Include
accurate setup/run documentation, run it with "Ada", and exercise the missing-argument error.
No Git initialization, remote, commit, push, PR, project-guidance documents, or local support.
```

**Observe:**

- Planning returns scope and acceptance from the supplied decisions with no checkout, GitHub
  destination, material-choice re-interview, filesystem writes, or implementation dispatch.
- Creation reuses the selected stack, checks fresh target/ancestor metadata and collisions before
  writing, produces the smallest working native slice, exercises success/error behavior, and
  documents real commands without requiring Whiteboard or Init.
- Repeat creation against a populated target with sentinel content, a symlinked target or
  ancestor, and an ambiguous target. Preserve bytes, entries, and link targets; no destructive
  cleanup, alternate-target scaffold, or incidental GitHub operation occurs.
- Trace an existing-repository task retaining its native conventions and unrelated locked versions,
  and a document-only Init request creating no application or support. Canonical reference reads
  authorize no cross-skill invocation.
- Keep helper checks, manual traces, actual-host runs, and unavailable variants separate under the
  evidence classes above. Save safe evidence, then remove only task-owned temporary fixtures.

## 7. Isolation with and without sibling skills

Each recipe above must produce the same gates, evidence, delivery, and stopping whether or not
another Woostack skill is installed. Run each comparison twice from distinct disposable consumer
repositories outside this checkout: once with only the skill under test installed (its own
`SKILL.md`, bundled references, scripts, and templates), once with the previously coupled
sibling also installed — Execute's and Simplify's pairings include Deliver, Orchestrate's includes
Execute, and Deliver's includes Execute. Keep tool, model, permission, host, and fixture constants
fixed between the two runs, and record the invocation, revision, and installed directory contents
of both runs. A host lacking a capability blocks only that recipe's affected variant; record the
unavailable variant **Unrun** and never install a missing sibling to substitute for the capability.

**Input contract for every isolation recipe:** the same explicit command text in both runs, with
no reminder about planning approval, stopping points, or delivery limits; the fixture built by
the referenced recipe; and the user's own narrow limits stated once (for example `local only` or
`commit only`) where the recipe asks for them.

**Observe, in every pairing:**

- The requested outcome, pauses, evidence, and stopping behavior are identical in both runs.
  Installing the sibling adds no extra stage, no second approval packet, no extra publication
  authority, no extra verification gate, and no changed completion boundary. Absence of the
  sibling does not block the requested workflow, trigger an installation prerequisite, or
  weaken a verification requirement.
- Any named optional reference the two runs load resolves from the skill's own bundled copies,
  never from a sibling directory; a link or navigation hint pointing outside the skill's installed
  directory never gates continuation of the nominal workflow.
- The absence run's report names the skill's own procedures; the presence run does not attribute
  its gates or stopping rules to a sibling workflow.

### Execute: local-only and requested delivery, isolated

Run the section 1 local recipe in both isolation conditions. Record identical local operation:
the admitted outcome, checks, and report must match, and the presence run cannot claim an extra
stage. For the requested-delivery variant, add the same explicit delivery request
("Implement ... and submit a draft PR" with the section 1 fixture's intended change) to both
conditions over one authorized disposable repository. Delivery authorization, publication, and
read-back belong to the Execute invocation itself: independently read back each run's draft PR
facts (identity, head, base, body, draft state, issue association), with no sibling attribution in
either report. Compare the authorization, evidence, and stopping boundaries, not incidental
identifiers or exact model wording.

### Deliver: commit-only isolated

Run the section 4 commit-only workload in both isolation conditions. No
`--no-pr-update` behavior difference, no push, no PR; the commit's own invocation is the entire
request. Record: no remote read or write in either run; no local-only commit triggers a staged
PR registration or delivery-readiness step in either run. Independently verify each resulting
commit's intended diff, subject, and applicable verification evidence; SHA identity is not expected
across distinct fixtures. A repeat with no new changes must not duplicate the commit.

### Orchestrate: prerequisite, separate consumer PR, and independent PR

Run the section 3 recipe in both isolation conditions before approving any dispatch, with the
same fixture (helper plus consumer), task descriptions, and authorized disposable repository.

- **Prerequisite variant:** task B still depends on helper `single_line` being present in a
  verified base in both runs. Orchestrate must discover the source prerequisite from evidence,
  not from a sibling skill's graph, and group A/B remains correct in both runs.
- **Separate consumer PR:** B stays separately reviewable and dependent on A in both runs,
  covering accepted and rejected input; no sibling's workflow substitutes for Orchestrate's own
  verification of B against the helper deliverable.
- **Independent PR:** C's separate `notes.txt` change lands independently of A and B in both
  runs, and the plan's grouping and landing order for C never depends on sibling presence.
- **Plan approval pause:** the invocation presents the proposal and stops before execution in
  both runs; the sibling's presence neither bypasses the pause nor adds a second one, and
  approval authority stays with the user in both.
- **After approval:** with `Approved, proceed`, delegation (one worker, one owned task
  workspace per group), integration verification, delivery, and the delivered-group stopping
  boundary stay identical in both runs; installing a sibling never extends delivery scope,
  adds monitoring, or changes the stopping point.

### Read-only and limits, isolated

Run one read-only variant in both isolation conditions on the same disposable source fixture,
with no delivery authorization: an analysis-only Simplify request, a no-publication plan, or a
read-only Orchestrate inspection. Record: no source write, no publication, no worker dispatch,
and no post-delivery monitoring in either run's report. Then run one explicitly limited variant
in both conditions (for example `local only` or `do not push`); the limited report is the same
in both runs, and no sibling stage cancels or widens the limit. Finally, make one required
external capability unavailable in both conditions (for example no GitHub capability): the
affected operation alone blocks with an accurate report, weaker verification does not appear in
either run, and neither run installs or invokes a missing sibling to proceed.

For the Debug comparison, use a tracked local target in a Git repository and record its expected
root, HEAD, and source blob before starting. Observe an actual Git discovery probe and matching
source provenance in each diagnosis; an omitted `.git` entry in a directory listing is not a
non-Git result. Include a nested working directory or Git worktree so discovery does not depend
on a visible `.git/` directory. Dirty/untracked source and unavailable Git must be reported as
such, without attributing inspected dirty bytes to a committed blob or inventing repository absence.

## Installed integration

`pnpm --filter docs test` covers the catalog, the production parser, and the installed-collection case: it
copies the candidate under edit — the working tree's installable skill assets, including
uncommitted, staged, and untracked changes — into a disposable
directory, validates that copy with the checkout's production validator and catalog, resolves the
copied links per skill, and rejects a link target that escapes that skill's own directory even
when the target exists nearby. It never writes to the checkout, and it reports on the candidate,
never on a released
installation. `pnpm --filter docs build` checks the documentation application, not the installed runtime.

To validate the candidate under edit outside this checkout, on a supported Unix host with Git,
Node, and Bash, first check distribution consistency in this checkout, then copy the working
tree's `skills/` assets, including uncommitted, staged, and untracked changes, to a disposable
directory. The parser is the checkout's production validator; the assets it validates come from
the candidate copy, and the printed revision is what it was copied from:

```bash
node shared/sync.mjs --check
INSTALL=$(mktemp -d)
printf 'Candidate revision: %s\n' "$(git rev-parse HEAD)"
cp -R skills "$INSTALL/"
node --input-type=module -e '
  import { validateSkillAssets } from "./apps/docs/scripts/skill-assets.mjs";
  import { PUBLIC_ORDER } from "./apps/docs/scripts/gen-skills.mjs";
  await validateSkillAssets(process.argv[1], PUBLIC_ORDER);
' "$INSTALL/skills"
# After saving the native output, remove only this disposable copy:
rm -rf "$INSTALL"
```

For one skill's independence, copy only its directory into a fresh temporary container with no
sibling directories, then call the production validator on that container with only that skill's
name as the expected catalog:

```bash
node --input-type=module -e '
  import { validateSkillAssets } from "./apps/docs/scripts/skill-assets.mjs";
  await validateSkillAssets(process.argv[1], [process.argv[2]]);
' <temporary-container> <skill-name>
```

The production validator proves installed asset closure, not model behavior. Skills require no
Woostack setup or configuration. Keep historical user files untouched during any host smoke run;
never point a fixture or cleanup command at real user records.

**Checkout-only audits.** These need this repository and are never installed-runtime evidence:
`pnpm --filter docs build` and the direct checkout-local skill-link audit in
`apps/docs/scripts/skill-assets.test.mjs`, which reads this checkout rather than the disposable
copy above.

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