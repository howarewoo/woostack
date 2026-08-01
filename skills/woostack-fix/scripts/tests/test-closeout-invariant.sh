#!/usr/bin/env bash
# Structural contract for diagnosis, approval, conditional plan persistence, and delivery.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path
text=re.sub(r"\s+"," ",(Path(sys.argv[1])/"skills/woostack-fix/SKILL.md").read_text())
checks={
 "conditional project":r"When repository Linear availability is proved, the fix plan is persisted as one project",
 "one gate":r"exactly one hard gate.*approve-to-execute",
 "project hierarchy":r"one project containing the proved diagnosis.*one parent plan issue.*one native child issue",
 "proved root cause":r"root cause and causal chain",
 "no patch in debug":r"Do not patch during diagnosis",
 "hardened contract":r"Produce one reviewable bounded contract",
 "explicit approval":r"request explicit.*approve-to-execute",
 "no preapproval write":r"Do not create a branch, worktree, edit, commit, PR, or artifact write before approval",
 "isolated execute":r"dispatch exactly the approved bounded increment to `woostack-execute`",
 "red green":r"observes the failing reproduction.*observes it passing",
 "scope invalidates":r"scope expansion.*invalidates approval",
 "review and commit":r"Require task-wide contract and quality review.*woostack-commit",
 "artifact narrow exception":r"Except for the workflow-owned canceled project transition on explicit abandonment.*do not mutate assignment, ownership, status",
 "abandon any phase":r"Explicit abandonment may occur at any phase",
 "closure preflight":r"including canceled project-status resolution, project update, stable mutation identity, and independent read-back",
 "cancel persisted project":r"exact persisted fix project exists.*native status must be set to the validated.*projectStatuses\.canceled",
 "no project no creation":r"no project exists.*nothing to close.*never create one merely to cancel",
 "non-abandon outcomes":r"distinct from handoff, replanning, and blocker handling.*leave project status unchanged",
 "closure failure":r"failed or unknown closure.*artifact blocker.*never resumes repository work",
 "repository readback":r"independently read its commit/head/base/body",
 "never merge":r"never merges",
}
failures=[name for name,pat in checks.items() if not re.search(pat,text,re.I|re.S)]
if re.search(r"--issue|Linear-Issue:|must.*exactly one managed issue",text,re.I|re.S):
 failures.append("legacy issue-only lifecycle returned")
if failures:
 print("fix contract violations:",file=sys.stderr)
 print("\n".join(f"- {f}" for f in failures),file=sys.stderr)
 raise SystemExit(1)
print("conditional fix plan contract: ok")
PY
