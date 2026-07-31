#!/usr/bin/env bash
# Structural contract for bounded bottom-up review rounds.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path
text=re.sub(r"\s+"," ",(Path(sys.argv[1])/"skills/woostack-sweep/SKILL.md").read_text())
checks={
 "bottom up":r"Process PRs bottom-up",
 "identity":r"canonical PR number, head SHA, base SHA/branch, complete thread set, changed paths, and approved task contract",
 "full review":r"woostack-review --full.*exact PR/head",
 "independent reviewer":r"implementing coder cannot act as the independent reviewer",
 "clean classification":r"clean only when.*no blocking findings.*checks pass.*no unresolved blocking thread",
 "fail closed":r"missing reviewer, partial result, unknown check, or changed head is `blocked`",
 "address":r"woostack-address-comments.*isolated worktree",
 "no broaden":r"Do not broaden the task contract",
 "verify":r"focused verification.*unchanged addressed diff",
 "fresh re-review":r"Fetch the updated PR/head and run a new full review.*Never reuse a result from a prior head",
 "bounds":r"review.max_rounds.*repeated complete finding/thread signature.*no repository progress",
 "no downgrade":r"Do not silently downgrade full review to self-review",
}
failures=[name for name,pat in checks.items() if not re.search(pat,text,re.I|re.S)]
if failures:
 print("sweep round contract violations:",file=sys.stderr)
 print("\n".join(f"- {f}" for f in failures),file=sys.stderr)
 raise SystemExit(1)
print("bounded sweep rounds: ok")
PY
