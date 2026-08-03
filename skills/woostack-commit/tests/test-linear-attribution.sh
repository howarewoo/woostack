#!/usr/bin/env bash
# Structural contract: commit stays artifact-optional and closes supplied issues only after merge.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
skill = (root / "skills/woostack-commit/SKILL.md").read_text(encoding="utf-8")
artifact = (root / "skills/woostack-commit/references/linear-attribution.md").read_text(encoding="utf-8")
pr_body = (root / "skills/woostack-commit/references/pr-body.md").read_text(encoding="utf-8")
graphite = (root / "skills/woostack-commit/references/graphite.md").read_text(encoding="utf-8")
fold = lambda text: re.sub(r"\s+", " ", text)
failures = []

def require(text, pattern, message):
    if not re.search(pattern, fold(text), re.I | re.S):
        failures.append(message)

def forbid(text, pattern, message):
    if re.search(pattern, fold(text), re.I | re.S):
        failures.append(message)

for pattern, message in (
    (r"no issue, project, assignment, lifecycle event, receipt, or attribution trailer is required", "commit does not declare artifact-free operation"),
    (r"`--issue` associates the verified Linear issue with the PR, adds its merge-closing reference", "--issue does not require merge-closing association"),
    (r"never creates one implicitly", "commit can create an artifact implicitly"),
    (r"Do not add a Linear reference in artifact-free mode", "artifact-free PR body is not protected"),
    (r"append one verified `Resolves <issue identifier>` line", "supplied issue lacks closing reference"),
    (r"moves the issue to its configured merged state only after the PR merges", "closing reference claims an early lifecycle transition"),
    (r"Artifact failure does not invalidate the verified commit or PR", "artifact failure can invalidate repository delivery"),
    (r"Graphite for history mutation", "Graphite mutation boundary missing"),
    (r"independently read the canonical GitHub PR", "PR read-back missing"),
):
    require(skill, pattern, message)

for pattern, message in (
    (r"normal commit/PR path is artifact-free", "optional association reference lacks artifact-free default"),
    (r"Never infer an issue", "optional artifact identity can be inferred"),
    (r"`Resolves <issue identifier>` line", "optional association lacks closing reference"),
    (r"Do not add a project reference", "project could be incorrectly closed by an issue PR"),
    (r"only after the PR merges", "association claims issue closure before merge"),
    (r"Never change scope, assignment, delegate, owner, status, acceptance", "artifact mutation is too broad"),
):
    require(artifact, pattern, message)

require(pr_body, r"exactly one matching `Resolves <issue identifier>` line when an issue was supplied", "PR body closing-reference cardinality missing")
require(pr_body, r"merged PR resolves its issue, not the containing project", "PR body may resolve a Linear project")
require(graphite, r"task/branch based; Linear is not required", "Graphite path still requires an issue")
for text, label in ((skill, "skill"), (artifact, "artifact"), (pr_body, "pr-body"), (graphite, "graphite")):
    forbid(text, r"`--issue` is always required|Linear is the only development-record|must identify exactly one.*issue", f"{label}: mandatory Linear prerequisite returned")

if failures:
    print("artifact-optional commit contract violations:", file=sys.stderr)
    for failure in failures:
        print(f"- {failure}", file=sys.stderr)
    raise SystemExit(1)
print("artifact-optional commit contract: ok")
PY
