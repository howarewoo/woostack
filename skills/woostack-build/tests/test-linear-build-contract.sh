#!/usr/bin/env bash
# Structural contract for the artifact-optional build loop.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
paths = {
    "build": root / "skills/woostack-build/SKILL.md",
    "ideate": root / "skills/woostack-ideate/SKILL.md",
    "harden": root / "skills/woostack-harden/SKILL.md",
    "plan": root / "skills/woostack-plan/SKILL.md",
    "execute": root / "skills/woostack-execute/SKILL.md",
    "overnight": root / "skills/woostack-execute-overnight/SKILL.md",
}
text = {name: path.read_text(encoding="utf-8") for name, path in paths.items()}
failures = []

def require(name, needle):
    if needle not in text[name]:
        failures.append(f"{name}: missing {needle!r}")

def forbid(name, pattern):
    if re.search(pattern, text[name], re.I | re.S):
        failures.append(f"{name}: matches forbidden pattern {pattern!r}")

for needle in (
    "## Exactly three hard gates",
    "**design-approval**",
    "**spec-approval**",
    "**execution-handoff**",
    "Linear persistence is opt-in",
    "Without explicit artifact",
    "No implementation Git artifact exists before an explicit `Go` or",
):
    require("build", needle)

require("ideate", "approved design lives in the conversation")
require("ideate", "optional Linear persistence")
require("harden", "Linear is never required and never owns approval")
require("plan", "Without `--project`, return the complete plan in the conversation and do not contact Linear")
require("execute", "Exact Linear project/issue artifacts are optional")
require("overnight", "Optional Linear artifacts may mirror the plan and evidence")

for name in text:
    forbid(name, r"(?:requires?|must have) (?:an? |one |exact )?(?:managed )?Linear (?:issue|project)")

if failures:
    print("artifact-optional build contract violations:", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    raise SystemExit(1)

print("test-linear-build-contract: ok")
PY
