#!/usr/bin/env bash
# Structural contract: approved task/plan admission is primary; Linear is optional.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path
root = Path(sys.argv[1])
skill = re.sub(r"\s+", " ", (root / "skills/woostack-execute/SKILL.md").read_text())
controller = re.sub(r"\s+", " ", (root / "skills/woostack-execute/references/controller.md").read_text())
checks = [
    (skill, r"approved task/plan is required", "approved input missing"),
    (skill, r"Without artifact flags, make no Linear call", "artifact-free route missing"),
    (skill, r"never assign workers or grant authority", "artifact authority boundary missing"),
    (skill, r"one dependency-ready task per cycle", "one-task cycle missing"),
    (skill, r"Never infer readiness from.*Linear status", "artifact state can select work"),
    (controller, r"Artifact-free execution is the default", "controller defaults to artifacts"),
    (controller, r"selection admits one task per controller cycle", "controller can admit multiple tasks"),
    (controller, r"Optional artifact IDs are context only", "worker packet grants artifact authority"),
]
failures=[msg for text,pat,msg in checks if not re.search(pat,text,re.I|re.S)]
for text,label in ((skill,"skill"),(controller,"controller")):
    if re.search(r"`--issue` is required|Linear is the only development-record|must create.*issue",text,re.I|re.S):
        failures.append(f"{label}: mandatory issue prerequisite returned")
if failures:
    print("execution admission contract violations:", file=sys.stderr)
    print("\n".join(f"- {f}" for f in failures), file=sys.stderr)
    raise SystemExit(1)
print("repository-first execution admission: ok")
PY
