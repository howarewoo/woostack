#!/usr/bin/env bash
# Structural contract: approved task/plan admission is primary; fix-origin Linear approval is exact.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path
root = Path(sys.argv[1])
skill = re.sub(r"\s+", " ", (root / "skills/woostack-execute/SKILL.md").read_text())
controller = re.sub(r"\s+", " ", (root / "skills/woostack-execute/references/controller.md").read_text())
fix_skill = re.sub(r"\s+", " ", (root / "skills/woostack-fix/SKILL.md").read_text())
checks = [
    (skill, r"approved task/plan is required", "approved input missing"),
    (skill, r"Fix-origin input must carry one complete `fixApprovalRecord` and exact matching `--issue`", "fix exact issue admission missing"),
    (skill, r"fixApprovalRecord.*issueId.*canonicalContentFingerprint.*approvedBy.*approvedAt.*approvalEventRef", "complete fix approval record missing"),
    (skill, r"completely paginate relevant issue relations and approval events.*shared.*fix identity algorithm", "native relation and approval-event proof missing"),
    (skill, r"before implementation.*after every worker handback.*before every redispatch.*immediately before commit", "fix authority recheck cadence missing"),
    (skill, r"material title, description/plan, or admitted native dependency change invalidates approval", "fix stale-plan invalidation missing"),
    (skill, r"no local, conversational, historical-project, or alternate-provider fallback", "fix failure fallback remains"),
    (skill, r"Standalone execution without artifact flags makes no Linear call", "standalone artifact-free route missing"),
    (skill, r"Linear never assigns workers or proves source-control state", "artifact authority boundary missing"),
    (skill, r"one dependency-ready task per cycle", "one-task cycle missing"),
    (skill, r"Never infer readiness from.*Linear status", "artifact state can select work"),
    (skill, r"explicitly abandons a fix/build.*cancel every active.*verify every driver is quiescent", "abandonment does not stop in-flight repository work"),
    (skill, r"projectStatuses\.canceled.*independently read", "build abandonment does not close the selected project"),
    (skill, r"no exact persisted project exists.*nothing to close.*make no provider write", "artifact-free abandonment lacks an explicit no-project handback"),
    (skill, r"Handoff, replanning, blockers, pauses, and failed tasks are not abandonment and leave the project open", "non-abandonment outcomes close the project"),
    (skill, r"Do not create a project merely to cancel it", "abandonment can create a project"),
    (controller, r"Artifact-free execution is permitted only for standalone input", "controller fix-origin route is optional"),
    (controller, r"selection admits one task per controller cycle", "controller can admit multiple tasks"),
    (controller, r"Only caller-selected ordinary artifact mode for standalone work is optional", "worker packet grants artifact authority"),
    (controller, r"fix-origin execution.*exactly one form.*fixApprovalRecord.*invocation must include exact `--issue`", "controller fix approval admission missing"),
    (controller, r"responsible-user stable native principal ID.*provider event timestamp.*stable event reference.*causal order", "controller approval provenance validation missing"),
    (controller, r"before implementation.*after every worker handback.*before every redispatch.*immediately before commit", "controller fix recheck cadence missing"),
    (controller, r"Standalone execution remains artifact-optional only when no fix-origin or build-origin context is present", "standalone execution lost artifact-optional behavior"),
    (fix_skill, r"invoke `woostack-execute.*--issue.*pass exactly one matching `fixApprovalRecord`", "fix producer does not hand off the exact issue and approval record"),
    (fix_skill, r"responsible user.*approve the exact Linear issue revision.*approve-to-execute", "fix gate is not a native issue approval"),
]
failures=[msg for text,pat,msg in checks if not re.search(pat,text,re.I|re.S)]
for text,label in ((skill,"skill"),(controller,"controller"),(fix_skill,"fix")):
    if "historicalProjectBackedFix" in text or "fixApprovalReceipt" in text:
        failures.append(f"{label}: removed compatibility shape remains")
if failures:
    print("execution admission contract violations:", file=sys.stderr)
    print("\n".join(f"- {f}" for f in failures), file=sys.stderr)
    raise SystemExit(1)
print("repository-first execution admission: ok")
PY
