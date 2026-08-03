#!/usr/bin/env bash
# Structural contract for repository-first unattended execution.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path
text=re.sub(r"\s+"," ",(Path(sys.argv[1])/"skills/woostack-execute-overnight/SKILL.md").read_text())
checks={
 "commands":r"/woostack-execute-overnight <approved plan>.*--project",
 "no implicit Linear":r"Standalone input without an exact artifact flag makes no Linear call",
 "repository authority":r"Git, Graphite, and canonical GitHub reads own source, ancestry, PR, review, and delivery truth",
 "approved plan":r"one complete explicitly approved implementation plan",
 "complete DAG":r"stable task IDs.*acyclic dependency graph",
 "repo preflight":r"deterministic task paths.*git worktree list.*dirty/index/diff state.*Git/Graphite ancestry.*GitHub PR/review/check/thread state",
 "artifact conflict":r"For selected standalone artifacts, conflict blocks only artifact use/synchronization and never rewrites the approved plan",
 "fixed loop":r"derive the currently dependency-ready task set.*Red → Green → Refactor.*specification review then quality review.*woostack-commit.*woostack-sweep",
 "no dependent concurrency":r"Never process two dependent tasks concurrently",
 "bounded autonomy":r"must not invent or change.*product behavior.*architecture.*security/privacy posture.*dependency edges",
 "independent continuation":r"continue another dependency-independent track only when",
 "failure isolation":r"task-local failure.*track-local review or submission failure.*shared invariant failure.*required build provider failure.*optional standalone artifact failure.*unknown mutation outcome",
 "no destructive recovery":r"Never reset, clean, stash, delete, overwrite, reassign, force-push",
 "bounded sweep":r"full review.*restack only through Graphite.*re-review",
 "no self review":r"implementing coder never acts as its own reviewer",
 "artifact narrow":r"Except for project closure, do not mutate assignee, delegate, native status, relations, membership, or archival state",
 "abandonment quiescence":r"decision to abandon the fix/build.*cancels every active.*verify every driver is quiescent",
 "abandonment closure":r"projectStatuses\.canceled.*independently read",
 "no-project handback":r"no exact persisted project exists.*nothing to close.*make no provider write",
 "no synthetic cancellation":r"Never create a project merely to cancel it",
 "non-abandonment stays open":r"task failure, blocker, pause, ordinary handoff, or replan is not abandonment and leaves the project open",
 "fresh handback":r"Return one truthful report derived from fresh reads",
 "states":r"completed.*blocked.*skipped-dependent.*not-started",
 "never merge":r"No self-review, self-acceptance, force-push, protected-primary edit, or merge",
}
failures=[name for name,pat in checks.items() if not re.search(pat,text,re.I|re.S)]
if re.search(r"(?:requires?|must have).*Linear (?:project|issue).*before (?:execution|admission)|Linear (?:project|issue) is required",text,re.I|re.S):
 failures.append("mandatory Linear authority")
if failures:
 print("overnight contract violations:",file=sys.stderr)
 print("\n".join(f"- {f}" for f in failures),file=sys.stderr)
 raise SystemExit(1)
print("repository-first overnight contract: ok")
PY
