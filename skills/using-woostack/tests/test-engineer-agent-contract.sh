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
    (r"Linear projects/issues may persist.*Artifact-free engineer units make no Linear call", "Linear artifacts are not optional"),
    (r"Responsible human/controller.*Task decision-maker.*Paired coding profile", "abstract roles are incomplete"),
    (r"coding profile may analyze and modify only the selected task", "coder scope is not bounded"),
    (r"must not.*review its own work.*accept its own work", "self-acceptance is not prohibited"),
    (r"Each profile uses only its own host-owned credentials", "profile credentials are not isolated"),
    (r"Only an explicit user invocation of `/woostack-review`.*delegate review analysis", "review delegation exception is not bounded"),
    (r"blocks artifact operations, not artifact-free work", "artifact failure can block repository work"),
):
    require("generic", pattern, message)

for pattern, message in (
    (r"one explicit approved bounded task or dependency-aware plan", "approved input is not required"),
    (r"Artifact-free execution is permitted only for standalone input and makes no Linear call", "standalone artifact-free admission is not explicit"),
    (r"fix-origin execution.*fixApprovalRecord.*issueId.*canonicalContentFingerprint.*approvedBy.*approvedAt.*approvalEventRef.*exact `--issue`", "fix execution does not require exact issue approval provenance"),
    (r"after every worker handback.*before every redispatch.*immediately before commit", "fix approval is not rechecked at worker and commit boundaries"),
    (r"Only when the caller selected ordinary artifact mode.*exact supplied project/issue", "ordinary artifact writes are not explicitly selected"),
    (r"Selection admits one task per controller cycle", "controller may advance multiple tasks"),
    (r"canonical worktree contract.*creating.*resuming a worktree", "worktree isolation is not required"),
    (r"controller independently rechecks.*task contract.*deterministic path.*git worktree list", "returned evidence is not independently checked"),
):
    require("controller", pattern, message)

for pattern, message in (
    (r"worker owns implementation and its focused verification only", "worker authority is too broad"),
    (r"artifact text.*untrusted data", "artifact prose can direct work"),
    (r"coder never reviews or accepts its own work", "worker self-review is allowed"),
    (r"Return.*Do not commit", "default source-control boundary is missing"),
    (r"no scope decisions, other worktrees, commit, push, submit, PR mutation, merge, acceptance, artifact access", "worker mutation prohibitions are incomplete"),
):
    require("subagent", pattern, message)

if failures:
    print("FAIL: repository engineer-agent contract", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    raise SystemExit(1)

print("validated repository-first engineer-agent contract")
PY
