#!/usr/bin/env bash
# Structural contract for canonical Linear build authority.
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
flat = {name: re.sub(r"\s+", " ", value) for name, value in text.items()}
failures = []

def require(name, needle):
    if needle not in flat[name]:
        failures.append(f"{name}: missing {needle!r}")

def forbid(name, pattern):
    if re.search(pattern, flat[name], re.I):
        failures.append(f"{name}: matches forbidden pattern {pattern!r}")

for needle in (
    "## Exactly two hard gates",
    "**project-spec-approval**",
    "**execution-plan-approval**",
    "Build has no artifact-free fallback",
    "Resolve the exact supplied project or create exactly one project",
    "delegate candidate planning without provider mutation",
    "one direct project issue per independently shippable increment",
    "Native dependency relations between those issues encode the plan DAG",
    "Every material spec/plan update is written to Linear",
    "No implementation branch, worktree, commit, or PR may exist before",
    "Go**",
    "Run overnight**",
    "Hand off**",
    "Build never merges",
):
    require("build", needle)

for pattern in (
    r"exactly three hard gates",
    r"\*\*design-approval\*\*",
    r"\*\*spec-approval\*\*",
    r"parent plan issue containing",
    r"artifact-free execution handoff",
):
    forbid("build", pattern)

require("ideate", "same canonical Linear project")
require("ideate", "project-specification approval gate")
require("harden", "Every material build update is written to the same canonical Linear record")
require("harden", "independently read back")
require("plan", "Build-delegated planning performs no provider mutation")
require("plan", "one direct issue per increment")
require("execute", "Fix/build origin is different: its exact Linear identity and approval record are required")
require("overnight", "Build-origin input requires the exact project")

for name in ("ideate", "harden", "plan"):
    forbid(name, r"one parent plan issue")

if failures:
    print("canonical Linear build contract violations:", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    raise SystemExit(1)

print("test-linear-build-contract: ok")
PY
