#!/usr/bin/env bash
# Structural contract for the read-only repository-derived status board.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import json, re, sys
from pathlib import Path
root=Path(sys.argv[1])
skill=re.sub(r"\s+"," ",(root/"skills/woostack-status/SKILL.md").read_text())
conv=re.sub(r"\s+"," ",(root/"skills/woostack-status/references/conventions.md").read_text())
checks=[
 (skill,r"Always read-only","description is not read-only"),
 (skill,r"no issue, project, trailer, owner, assignment, lifecycle receipt, or artifact mutation is required|projects/issues may supply optional|projects/issues/work items\s*may supply optional","artifact optionality missing"),
 (skill,r"Status makes no artifact write","artifact mutation still allowed"),
 (skill,r"Git, Graphite, and canonical GitHub evidence define","repository authority missing"),
 (skill,r"A PR needs no Linear attribution|never infer an artifact","implicit artifact discovery possible"),
 (skill,r"review-clean.*not product acceptance","review/acceptance boundary missing"),
 (skill,r"\| `review-clean` \| current head has full review evidence and no unresolved blocking thread \|","skill review-clean check independence missing"),
 (conv,r"No row state comes from a (?:Linear|Linear or Plane)","artifact state can define repository state"),
 (conv,r"Status performs no artifact mutation","conventions allow artifact writes"),
 (conv,r"Missing.*artifact data.*omits the artifact columns only","artifact failure blocks board"),
 (conv,r"Check outcomes and check-read completeness are observable-only and do not alter row state","conventions observable-only check contract missing"),
 (conv,r"fully paginate canonical GitHub PRs, commits, reviews, threads, and merge evidence.*Read available checks separately as best-effort observable data; their missing or incomplete state cannot derive `unknown` or another row state","observable-only check snapshot rule missing"),
 (skill,r"complete pagination: number/URL,\s*state,\s*head/base branches and SHAs,\s*draft state,\s*reviews,\s*unresolved threads,\s*and merge evidence.*Read available checks separately as best-effort observable data for display; missing or incomplete check pages never reject the snapshot or affect row state derivation","skill observable-only checks snapshot rule missing"),
]
failures=[msg for text,pat,msg in checks if not re.search(pat,text,re.I|re.S)]
for text,label in ((skill,"skill"),(conv,"conventions")):
 if re.search(r"must.*(?:issueDone|assignmentAccepted|Linear PR relation)|terminal reconciliation",text,re.I|re.S):
  failures.append(f"{label}: obsolete Linear lifecycle gate returned")
if re.search(r"failed/unknown required check|required checks passing", skill + conv, re.I):
 failures.append("obsolete check gating remains in status skill/conventions")
if re.search(r"reviews,\s*checks,\s*threads", conv, re.I):
 failures.append("combined mandatory reviews/checks/threads remains in status conventions")
if re.search(r"fully paginate[^.;]{0,200}\bchecks\b", conv, re.I):
 failures.append("mandatory check pagination remains in status conventions snapshot")
if re.search(r"complete pagination:[^.;]{0,200}\bchecks\b", skill, re.I):
 failures.append("checks remain inside mandatory complete-pagination in status skill")
if re.search(r"draft state,\s*checks", skill, re.I):
 failures.append("mandatory check pagination remains in status skill")

evals = json.loads((root / "skills/woostack-status/evals/evals.json").read_text())
status_cases = {case["id"] for case in evals["cases"]}
required_status_cases = {
 "status-derives-review-clean-with-failed-checks",
 "status-derives-review-clean-with-pending-checks",
 "status-independent-failure-blocks-despite-checks",
}
if not required_status_cases <= status_cases:
 failures.append(f"missing status eval cases: {sorted(required_status_cases - status_cases)}")
for check_case_id in ("status-derives-review-clean-with-failed-checks", "status-derives-review-clean-with-pending-checks", "status-independent-failure-blocks-despite-checks"):
 case = next((c for c in evals["cases"] if c["id"] == check_case_id), None)
 if case:
  assertions = {a["pointer"]: a["expected"] for a in case["assertions"]}
  if assertions.get("/checkCausedBlockers") != []:
   failures.append(f"{check_case_id}: checkCausedBlockers is not empty")

if failures:
 print("status contract violations:",file=sys.stderr)
 print("\n".join(f"- {f}" for f in failures),file=sys.stderr)
 raise SystemExit(1)
print("repository-derived status contract: ok")
PY
