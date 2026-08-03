#!/usr/bin/env bash
# Structural contract for direct-issue planning and optional standalone persistence.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
paths = {
    "plan": root / "skills/woostack-plan/SKILL.md",
    "build": root / "skills/woostack-build/SKILL.md",
    "harden": root / "skills/woostack-harden/SKILL.md",
    "artifact": root / "skills/woostack-init/references/artifact-backends.md",
    "context": root / "skills/woostack-build/references/linear-context.md",
    "procedure": root / "skills/woostack-build/references/linear-procedure.md",
}
text = {
    name: re.sub(r"\s+", " ", path.read_text(encoding="utf-8"))
    for name, path in paths.items()
}
failures = []

def require(name, needle):
    if needle not in text[name]:
        failures.append(f"{name}: missing {needle!r}")

def forbid(name, pattern):
    if re.search(pattern, text[name], re.I):
        failures.append(f"{name}: matches forbidden pattern {pattern!r}")

for needle in (
    "One approved specification in, one coherent plan out",
    "Every increment contains",
    "an ordered, concrete implementation sequence detailed enough for a fast execution model",
    "one direct issue per increment",
    "native dependency relations",
    "no parent plan issue or child containment",
    "Build-delegated planning performs no provider mutation",
    "build synchronizes after graph hardening",
    "unique positive ordinal",
    "duplicate task IDs or ordinals",
    "unknown predecessors",
    "uncovered acceptance criteria",
    "a Git parent the DAG and intended Graphite ancestry cannot represent",
):
    require("plan", needle)

for needle in (
    "one direct project issue per independently shippable increment",
    "approve exact project-spec revision",
    "approve exact execution-plan revision set",
):
    require("build", needle)

require("harden", "same direct project issue")
require("artifact", "Do not create a parent plan issue")
require("artifact", "one direct project issue per increment")
require("artifact", "buildProjectSpecApprovalRecord")
require("artifact", "buildExecutionPlanApprovalRecord")
require("context", "complete exact issue fingerprints")
require("context", "normalized native dependencies")
require("procedure", "complete executor-ready issue descriptions")
require("procedure", "Independently read the complete relation set back")
require("procedure", "Without explicit persistence, standalone planning makes no provider call")
require("procedure", "Explicit abandonment follows the shared")

for name in text:
    forbid(name, r"one project, one parent plan issue")

retired_planning = root / "skills/woostack-plan/references/linear-planning.md"
if retired_planning.exists():
    failures.append("plan: orphaned duplicate linear-planning.md must remain deleted")

if failures:
    print("direct-issue planning contract violations:", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    raise SystemExit(1)

print("test-linear-plan-contract: ok")
PY
