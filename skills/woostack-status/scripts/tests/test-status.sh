#!/usr/bin/env bash
# Structural contract for the read-only repository-derived status board.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path
root=Path(sys.argv[1])
skill=re.sub(r"\s+"," ",(root/"skills/woostack-status/SKILL.md").read_text())
conv=re.sub(r"\s+"," ",(root/"skills/woostack-status/references/conventions.md").read_text())
checks=[
 (skill,r"Always read-only","description is not read-only"),
 (skill,r"no issue, project, trailer, owner, assignment, lifecycle receipt, or artifact mutation is required|projects/issues may supply optional","artifact optionality missing"),
 (skill,r"Status makes no artifact write","artifact mutation still allowed"),
 (skill,r"Git, Graphite, and canonical GitHub evidence define","repository authority missing"),
 (skill,r"A PR needs no Linear attribution|never infer an artifact","implicit artifact discovery possible"),
 (skill,r"review-clean.*not product acceptance","review/acceptance boundary missing"),
 (conv,r"No row state comes from a Linear","artifact state can define repository state"),
 (conv,r"Status performs no artifact mutation","conventions allow artifact writes"),
 (conv,r"Missing.*artifact data.*omits the artifact columns only","artifact failure blocks board"),
]
failures=[msg for text,pat,msg in checks if not re.search(pat,text,re.I|re.S)]
for text,label in ((skill,"skill"),(conv,"conventions")):
 if re.search(r"must.*(?:issueDone|assignmentAccepted|Linear PR relation)|terminal reconciliation",text,re.I|re.S):
  failures.append(f"{label}: obsolete Linear lifecycle gate returned")
if failures:
 print("status contract violations:",file=sys.stderr)
 print("\n".join(f"- {f}" for f in failures),file=sys.stderr)
 raise SystemExit(1)
print("repository-derived status contract: ok")
PY
