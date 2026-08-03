#!/usr/bin/env bash
# Structural contract: canonical fix/build records, safe init defaults, optional artifacts elsewhere.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"

python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
failures = []

def flat(path):
    return re.sub(r"\s+", " ", path.read_text(encoding="utf-8"))

def require(label, text, pattern, message):
    if not re.search(pattern, text, re.I):
        failures.append(f"{label}: {message}")

flag_paths = list((root / "skills").glob("*/SKILL.md")) + [
    root / "AGENTS.md",
    root / "README.md",
]
for path in flag_paths:
    if re.search(r"(?<![\w-])--linear(?![\w-])", path.read_text(encoding="utf-8")):
        failures.append(f"{path.relative_to(root)}: obsolete --linear init flag remains")

init = flat(root / "skills/woostack-init/SKILL.md")
for pattern, message in (
    (r"Every run attempts automatic Linear setup", "default init does not attempt Linear setup"),
    (r"Authenticated read access is sufficient", "read-only authenticated setup is not sufficient"),
    (r"never selects artifact mode", "init setup can appear to select unrelated artifact use"),
    (r"continue ordinary local initialization", "Linear setup can appear to block local init"),
):
    require("woostack-init", init, pattern, message)

contract = flat(root / "skills/woostack-init/references/artifact-backends.md")
for pattern, message in (
    (r"canonical product records for `woostack-build` and post-diagnosis `woostack-fix`", "canonical fix/build role missing"),
    (r"one project plus one direct project issue per increment", "direct build issue shape missing"),
    (r"Do not create a parent plan issue", "retired build wrapper is not forbidden"),
    (r"A new fix uses one issue", "single fix issue shape missing"),
    (r"not source-control or delivery authority", "source-control authority boundary missing"),
    (r"responsible user's explicit native Linear approval", "native approval authority missing"),
    (r"automatic authenticated read-only setup discovery", "automatic init exception missing"),
    (r"Tracked `.woostack/config\.json` policy never authorizes provider access by itself", "policy authority boundary missing"),
    (r"exact caller-supplied resource always takes precedence over creation", "exact-resource precedence missing"),
    (r"host's authenticated official Linear MCP", "official transport boundary missing"),
    (r"stable client-generated operation ID", "idempotent mutation rule missing"),
    (r"perform a new independent complete read", "read-back rule missing"),
    (r"buildProjectSpecApprovalRecord", "project approval record missing"),
    (r"buildExecutionPlanApprovalRecord", "execution-plan approval record missing"),
    (r"projectStatuses\.canceled", "canceled-status mapping missing"),
):
    require("artifact-backends.md", contract, pattern, message)

build = flat(root / "skills/woostack-build/SKILL.md")
for pattern, message in (
    (r"Build has no artifact-free fallback", "build still appears artifact-optional"),
    (r"Resolve the exact supplied project or create exactly one project", "build project admission missing"),
    (r"Exactly two hard gates", "two-gate build contract missing"),
    (r"one direct project issue per increment", "direct increment shape missing"),
):
    require("woostack-build", build, pattern, message)

fix = flat(root / "skills/woostack-fix/SKILL.md")
for pattern, message in (
    (r"Before root-cause proof.*no provider", "pre-proof provider boundary missing"),
    (r"without `--issue`.*create exactly one native work-item issue", "plain-prompt issue creation missing"),
    (r"approve-to-execute", "single fix approval gate missing"),
):
    require("woostack-fix", fix, pattern, message)
if re.search(r"one project.*parent plan issue.*child increment", fix, re.I):
    failures.append("woostack-fix: project hierarchy remains")

plan = flat(root / "skills/woostack-plan/SKILL.md")
require("woostack-plan", plan, r"Without `--project` or an explicit persistence request.*make no Linear call", "standalone selection boundary missing")
require("woostack-plan", plan, r"one direct issue per increment", "standalone direct-issue persistence missing")

change = flat(root / "skills/woostack-change/SKILL.md")
require("woostack-change", change, r"never reads or writes Linear", "change is not Linear-free")

if failures:
    print("Linear authority contract violations:", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    raise SystemExit(1)

print("Linear authority contract: ok")
PY
