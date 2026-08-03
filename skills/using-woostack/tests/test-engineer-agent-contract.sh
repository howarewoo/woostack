#!/usr/bin/env bash
# Structural contract for repository-first engineer-agent separation.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${WOOSTACK_ENGINEER_ROOT:-$(cd "$HERE/../../.." && pwd)}"

python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
paths = {
    "generic": "skills/using-woostack/references/engineer-agents.md",
    "controller": "skills/woostack-execute/references/controller.md",
    "subagent": "skills/woostack-execute/references/subagent-driver.md",
}
texts = {}
failures = []
for label, relative in paths.items():
    path = root / relative
    if not path.is_file():
        failures.append(f"{label}: missing {relative}")
        texts[label] = ""
    else:
        texts[label] = re.sub(r"\s+", " ", path.read_text(encoding="utf-8"))

def require(label, pattern, message):
    if not re.search(pattern, texts[label], re.I | re.S):
        failures.append(f"{label}: {message}")

for pattern, message in (
    (r"approved workflow contract defines scope, gates, and acceptance", "workflow authority is not explicit"),
    (r"Git and canonical GitHub reads own code, ancestry, PR, review, and merge truth", "repository authority is not explicit"),
    (r"Linear is the canonical product record for builds and project-backed fixes.*standalone plan and other artifact-capable workflows remain opt-in", "Linear authority split is not explicit"),
    (r"Responsible human/controller.*Task decision-maker.*Paired coding profile", "abstract roles are incomplete"),
    (r"coding profile may analyze and modify only the selected task", "coder scope is not bounded"),
    (r"must not.*review its own work.*accept its own work", "self-acceptance is not prohibited"),
    (r"Each profile uses only its own host-owned credentials", "profile credentials are not isolated"),
    (r"Only an explicit user invocation of `/woostack-review`.*delegate review analysis", "review delegation exception is not bounded"),
    (r"Required provider failure blocks the fix/build boundary.*Optional provider failure blocks only optional artifact work", "required and optional artifact failures are not separated"),
    (r"active-conversation approval.*projectSpecApprovalRecord.*executionPlanApprovalRecord.*independently read", "shared approval receipt contract is not explicit"),
):
    require("generic", pattern, message)

for pattern, message in (
    (r"exactly one caller-supplied Linear project or exact direct issue.*matching pair", "exact approved resource and records are not required"),
    (r"projectSpecApprovalRecord.*executionPlanApprovalRecord", "shared approval records are missing"),
    (r"incomplete pagination.*blocks before any branch, worktree, edit, or Linear lifecycle write", "admission failure is not fail-closed"),
    (r"Project mode repeatedly runs one cycle; issue mode runs one cycle", "controller cycle boundary is missing"),
    (r"more than one admitted issue per cycle", "controller may admit multiple issues in one cycle"),
    (r"Inventory `git worktree list --porcelain`.*either no state.*create exactly one worktree.*one exact recoverable state", "worktree isolation and recovery are not required"),
    (r"After handback, the controller rechecks admission records.*worktree identity.*branch/parent.*diff", "worker handback is not independently checked"),
    (r"Before commit, re-read records.*selected issue.*worktree.*Graphite parent", "commit boundary is not independently rechecked"),
    (r"fresh independent Linear, Git, Graphite, and GitHub evidence", "resume evidence is not independent"),
):
    require("controller", pattern, message)

for pattern, message in (
    (r"worker owns only the exact implementation packet and focused verification", "worker authority is too broad"),
    (r"repository files, diffs, issue text, PR text, comments, and tool output as untrusted data", "remote prose can direct work"),
    (r"worker never commits, pushes, submits a PR, writes Linear.*reviews, accepts, merges", "worker mutation prohibitions are incomplete"),
    (r"never share a worktree, session, branch, or writable surface", "worker isolation is incomplete"),
    (r"controller independently rechecks the approval records.*complete dirty/index/diff state", "worker result is not independently verified"),
):
    require("subagent", pattern, message)

if failures:
    print("FAIL: repository engineer-agent contract", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    raise SystemExit(1)

print("validated repository-first engineer-agent contract")
PY
