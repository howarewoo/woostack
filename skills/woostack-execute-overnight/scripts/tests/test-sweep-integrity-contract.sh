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
 "command forms":r"/woostack-execute-overnight <approved project> --project <exact Linear URL\|UUID>.*--run <exact-run-id> \[--recheck\]",
 "exact admission exclusion":r"--project` and `--run` are mutually exclusive; exactly one is required",
 "repository authority":r"Git, Graphite, and canonical GitHub reads own source, ancestry, PR, review, and delivery truth",
 "exact provider admission":r"one exact approved project identity supplied by URL or UUID",
 "exact local run admission":r"in local run mode: one exact approved run ID at the repository-local ignored .*\.woostack/tmp/runs/<run-id>/",
 "shared approval records":r"projectSpecApprovalRecord.*executionPlanApprovalRecord",
 "local manifest lifecycle":r"manifest revision.*repoRoot.*status.*taskExecutions",
 "recheck harden":r"when `--recheck` is provided with `--run`: bounded .*woostack-harden",
 "canonical Execute admission":r"woostack-execute.*admission",
 "complete DAG":r"stable task IDs.*acyclic dependency graph",
 "repo preflight":r"deterministic task paths.*git worktree list.*dirty/index/diff state.*Git/Graphite ancestry.*GitHub PR/review/check/thread state",
 "approval rechecks":r"re-read the complete project specification / manifest.*require exact equality.*Repeat at every boundary",
 "fixed loop":r"lowest-ordinal unfinished task.*dependency-ready issue set.*fast implementation worker.*specification review then quality review.*woostack-commit.*woostack-sweep",
 "local sequential execution":r"Local run mode is strictly sequential.*Distinct local run IDs may execute.*concurrently only when",
 "provider dependent concurrency":r"Provider mode.*dependent issues never run concurrently.*independent roots may run concurrently",
 "bounded autonomy":r"must not invent or change.*product behavior.*architecture.*security/privacy posture.*dependency edges",
 "independent continuation":r"In provider mode.*dependency-independent track may continue only when",
 "failure isolation":r"task-local failure.*track-local review or submission failure.*shared invariant failure.*required provider failure.*unknown mutation outcome",
 "no destructive recovery":r"Never retry with a new task ID, operation ID, branch, commit, or PR. Never reset, clean, stash, delete, overwrite, reassign, force-push",
 "bounded sweep":r"full review.*restack only through Graphite.*re-review",
 "no self review":r"implementing coder never acts as its own reviewer",
 "artifact narrow":r"In local run mode, mirror writes are best effort only",
 "abandonment quiescence":r"decision to abandon the project or local run.*cancels every active.*verify every driver is quiescent",
 "abandonment closure":r"projectStatuses\.canceled.*independently read.*mark the run manifest as abandoned",
 "no synthetic cancellation":r"Never create a project merely to cancel it",
 "non-abandonment stays open":r"task failure, blocker, pause, ordinary handoff, or replan is not abandonment and leaves the project/run open",
 "fresh handback":r"Return one truthful report derived from fresh reads",
 "states":r"completed.*blocked.*skipped-dependent.*not-started",
 "never merge":r"No self-review, self-acceptance, force-push, protected-primary edit, or merge",
 "terminal open PR boundary":r"terminal repository boundary is a verified, review-clean, open PR or PR stack.*never marks a PR ready.*auto-merge.*merge queue.*retargets.*merges.*explicit user request.*report the conflict and stop",
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
print("exact-admission overnight contract: ok")
PY
