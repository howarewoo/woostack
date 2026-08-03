#!/usr/bin/env bash
# Structural contract for repository-first unattended execution.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path

raw=(Path(sys.argv[1])/"skills/woostack-execute-overnight/SKILL.md").read_text()
text=re.sub(r"\s+"," ",raw)
checks={
 "project-only command":r"/woostack-execute-overnight <approved project> --project <exact Linear URL\|UUID>",
 "explicit project-only":r"explicit project-only",
 "repository authority":r"Git, Graphite, and canonical GitHub reads own source, ancestry, PR, review, and delivery truth",
 "exact project admission":r"one exact approved project identity supplied by URL or UUID",
 "shared approval records":r"projectSpecApprovalRecord.*executionPlanApprovalRecord",
 "canonical Execute admission":r"woostack-execute.*admission",
 "complete DAG":r"stable task IDs.*acyclic dependency graph",
 "repo preflight":r"deterministic task paths.*git worktree list.*dirty/index/diff state.*Git/Graphite ancestry.*GitHub PR/review/check/thread state",
 "approval rechecks":r"re-read the complete project specification.*require exact equality with both approval records.*Repeat at every boundary",
 "fixed loop":r"derive the currently dependency-ready issue set.*fast implementation worker.*specification review then quality review.*woostack-commit.*woostack-sweep",
 "no dependent concurrency":r"Never process two dependent issues concurrently",
 "bounded autonomy":r"must not invent or change.*product behavior.*architecture.*security/privacy posture.*dependency edges",
 "independent continuation":r"continue another dependency-independent track only when",
 "failure isolation":r"task-local failure.*track-local review or submission failure.*shared invariant failure.*required project provider failure.*unknown mutation outcome",
 "no destructive recovery":r"Never reset, clean, stash, delete, overwrite, reassign, force-push",
 "bounded sweep":r"full review.*restack only through Graphite.*re-review",
 "no self review":r"implementing coder never acts as its own reviewer",
 "artifact narrow":r"Except for project closure, do not mutate assignee, delegate, native status, relations, membership, or archival state",
 "abandonment quiescence":r"decision to abandon the project.*cancels every active.*verify every driver is quiescent",
 "abandonment closure":r"projectStatuses\.canceled.*independently read",
 "no synthetic cancellation":r"Never create a project merely to cancel it",
 "non-abandonment stays open":r"task failure, blocker, pause, ordinary handoff, or replan is not abandonment and leaves the project open",
 "fresh handback":r"Return one truthful report derived from fresh reads",
 "states":r"completed.*blocked.*skipped-dependent.*not-started",
 "never merge":r"No self-review, self-acceptance, force-push, protected-primary edit, or merge",
}
failures=[name for name,pat in checks.items() if not re.search(pat,text,re.I|re.S)]
for retired in ("fixApprovalRecord", "buildProjectSpecApprovalRecord",
                "buildExecutionPlanApprovalRecord", "inline-driver.md",
                "--inline", "--subagent", "artifact-free", "standalone"):
    if retired.lower() in raw.lower():
        failures.append(f"retired mode or approval record: {retired}")
if failures:
 print("overnight contract violations:",file=sys.stderr)
 print("\n".join(f"- {f}" for f in failures),file=sys.stderr)
 raise SystemExit(1)
print("project-only overnight contract: ok")
PY
