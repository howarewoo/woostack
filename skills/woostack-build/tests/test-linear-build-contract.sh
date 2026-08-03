#!/usr/bin/env bash
# Structural contract for the thin canonical Linear build wrapper.
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
    "## Fixed chain",
    "resolve/create canonical project",
    "Ideate",
    "Harden",
    "project-spec approval in the active conversation",
    "execution-plan approval in the active conversation",
    "normal Execute",
    "## Exactly two approval stops",
    "owns exactly these two stops",
    "projectSpecApprovalRecord",
    "executionPlanApprovalRecord",
    "recorded and independently read back in Linear",
    "no artifact-free fallback",
    "candidate strict sequential direct-issue chain",
    "performs no provider read or mutation",
    "Build always invokes",
    "Build never merges",
    "last verified boundary",
    "repository association",
    "canonical fingerprints",
):
    require("build", needle)

chain_pattern = re.compile(
    r"resolve/create canonical project\s*→\s*"
    r"Ideate\s*→\s*"
    r"Harden\s*→\s*"
    r"project-spec approval in the active conversation.*?→\s*"
    r"Plan\s*→\s*"
    r"Harden\s*→\s*"
    r"execution-plan approval in the active conversation.*?→\s*"
    r"normal Execute",
    re.S,
)
if not chain_pattern.search(text["build"]):
    failures.append("build: fixed chain is missing or out of order")

for pattern in (
    r"terminal choices",
    r"\*\*go\*\*",
    r"run overnight",
    r"hand off",
    r"\breplan\b",
    r"\babandon\b",
    r"parallel",
    r"parent plan",
    r"artifact-free execution handoff",
    r"buildProjectSpecApprovalRecord",
    r"buildExecutionPlanApprovalRecord",
):
    forbid("build", pattern)

require("ideate", "one exact Linear project")
require("harden", "writes only what the user validates")
require("plan", "Delegated planning performs no provider read or mutation")
require("plan", "strict sequential chain")

if failures:
    print("thin canonical Linear build contract violations:", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    raise SystemExit(1)

print("test-linear-build-contract: ok")
PY
