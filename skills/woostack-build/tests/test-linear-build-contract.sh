#!/usr/bin/env bash
# Structural contract for the thin canonical Linear build wrapper.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
paths = {
    "build": root / "skills/woostack-build/SKILL.md",
    "context": root / "skills/woostack-build/references/linear-context.md",
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

require("build", "name starts with `[Build] `")
require("build", "Supplied projects retain their existing names")
require("context", "name starts with `[Build] `")
fixture = json.loads(
    (root / "skills/woostack-build/evals/fixtures/project-admission.json").read_text()
)
expected_project_name = "[Build] Bound cache freshness"
if fixture["createResponse"]["name"] != expected_project_name:
    failures.append("build: create request does not use the [Build] project prefix")
if fixture["independentRead"]["name"] != expected_project_name:
    failures.append("build: independent read does not verify the prefixed project name")

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
require(
    "ideate",
    "Ask every currently known independent question together in one clearly numbered batch",
)
require(
    "ideate",
    "A batch may contain one question only when it is the sole currently eligible question",
)
require(
    "ideate",
    "A later batch may contain only questions that become dependent after verified answers or questions that remained unresolved or ambiguous in an earlier batch",
)
require(
    "ideate",
    "After each user reply that contains one or more verified decisions, perform exactly one synchronization cycle",
)
require("ideate", "one read, one write, and one independent read-back cycle")
forbid("ideate", r"Ask \*\*one question per message\*\*")
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
