#!/usr/bin/env bash
# Structural contract for artifact-free diagnosis, approval, and delivery.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path
text=re.sub(r"\s+"," ",(Path(sys.argv[1])/"skills/woostack-fix/SKILL.md").read_text())
checks={
 "artifact optional":r"Linear is an optional artifact.*no issue, assignment, owner, lifecycle state, receipt, or PR trailer is required",
 "one gate":r"exactly one hard gate.*approve-to-execute",
 "no implicit issue":r"Without it, make no Linear call and never create an issue implicitly",
 "proved root cause":r"root cause and causal chain",
 "no patch in debug":r"Do not patch during diagnosis",
 "hardened contract":r"Produce one reviewable bounded contract",
 "explicit approval":r"request explicit.*approve-to-execute",
 "no preapproval write":r"Do not create a branch, worktree, edit, commit, PR, or artifact write before approval",
 "isolated execute":r"dispatch exactly the approved bounded task to `woostack-execute`",
 "red green":r"observes the failing reproduction.*observes it passing",
 "scope invalidates":r"scope expansion.*invalidates approval",
 "review and commit":r"Require task-wide contract and quality review.*woostack-commit",
 "artifact narrow":r"Do not mutate assignment, ownership, status, acceptance, relations, or project membership",
 "repository readback":r"independently read its commit/head/base/body",
 "never merge":r"never merges",
}
failures=[name for name,pat in checks.items() if not re.search(pat,text,re.I|re.S)]
if re.search(r"Linear-Issue:|must.*exactly one managed issue|create.*issue.*when no issue",text,re.I|re.S):
 failures.append("mandatory issue lifecycle returned")
if failures:
 print("fix contract violations:",file=sys.stderr)
 print("\n".join(f"- {f}" for f in failures),file=sys.stderr)
 raise SystemExit(1)
print("artifact-free fix closeout contract: ok")
PY
