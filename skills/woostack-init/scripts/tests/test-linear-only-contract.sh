#!/usr/bin/env bash
# Structural contract: init auto-configures safe defaults; persistence remains caller-selected.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"

python3 - "$ROOT" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
failures = []
paths = list((root / "skills").glob("*/SKILL.md")) + [
    path for path in (root / "site/content/docs").rglob("*.mdx")
    if "skills" not in path.relative_to(root / "site/content/docs").parts
]
for path in paths:
    text = re.sub(r"\s+", " ", path.read_text(encoding="utf-8"))
    for pattern in (
        r"Linear is the only development-record",
        r"mandatory official Linear",
        r"repository mutation without one exact managed issue",
        r"exact Linear input required",
    ):
        if re.search(pattern, text, re.I):
            failures.append(f"{path.relative_to(root)}: mandatory artifact language: {pattern}")

flag_paths = paths + [root / "AGENTS.md", root / "README.md"]
for path in flag_paths:
    if re.search(r"(?<![\w-])--linear(?![\w-])", path.read_text(encoding="utf-8")):
        failures.append(f"{path.relative_to(root)}: obsolete --linear init flag remains")

init_path = root / "skills/woostack-init/SKILL.md"
init = re.sub(r"\s+", " ", init_path.read_text(encoding="utf-8"))
for pattern, message in (
    (r"Every run attempts automatic Linear setup", "default init does not attempt Linear setup"),
    (r"Authenticated read access is sufficient", "read-only authenticated setup is not sufficient"),
    (r"never selects artifact mode", "init setup can appear to select persistence"),
    (r"continue ordinary local initialization", "Linear setup can appear to block local init"),
    (r"independently reopen and parse the file, compare", "local config write lacks read-back validation"),
    (r"configured, preserved, skipped, or setup-blocked", "separate Linear setup outcomes are missing"),
):
    if not re.search(pattern, init, re.I):
        failures.append(f"woostack-init: {message}")

contract_path = root / "skills/woostack-init/references/artifact-backends.md"
contract = re.sub(r"\s+", " ", contract_path.read_text(encoding="utf-8"))
for pattern, message in (
    (r"Linear projects and issues are optional durable artifacts", "optional provider role missing"),
    (r"not development authority", "artifact authority boundary missing"),
    (r"Artifact mode is selected only when", "explicit persistence selection rule missing"),
    (r"automatic authenticated read-only setup discovery", "automatic init exception missing"),
    (r"does not select artifact mode, authorize later provider access, or permit issue/project reads or any provider mutation", "init authority exception is too broad"),
    (r"tracked .* policy cannot select artifact mode, authorize a provider operation", "policy authority boundary missing"),
    (r"exact caller-supplied resource always takes precedence over creation", "exact-resource precedence missing"),
    (r"canonical repository association.*caller-selected workspace/team", "repository/workspace write verification missing"),
    (r"host's authenticated official Linear MCP", "official transport boundary missing"),
    (r"stable client-generated operation ID", "idempotent mutation rule missing"),
    (r"perform a new independent complete read", "read-back rule missing"),
    (r"blocks only the selected artifact operation", "artifact-independent degradation missing"),
    (r"projectStatuses\.canceled.*native canceled-category project status", "canceled-status preflight missing"),
    (r"Explicit abandonment is a terminal workflow action, distinct from handoff, replan, or a blocker", "abandonment distinction missing"),
    (r"Do not archive or delete the project, bulk-change issue states, or create a project merely to cancel it", "safe project closure missing"),
    (r"Closure failure or an unknown outcome produces a truthful artifact blocker", "closure failure boundary missing"),
):
    if not re.search(pattern, contract, re.I):
        failures.append(f"artifact-backends.md: {message}")

for pattern, message in (
    (r"Authenticated read capability sufficient .* is enough", "artifact contract requires provider writes for init setup"),
    (r"provider write and post-mutation read-back capability are neither required nor probed", "init setup probes mutation capability"),
    (r"never blocks local initialization", "Linear setup failure can block local init"),
    (r"independently reopens, parses, and compares any local config write", "artifact contract lacks local config read-back"),
):
    if not re.search(pattern, contract, re.I):
        failures.append(f"artifact-backends.md: {message}")

config = json.loads((root / "skills/woostack-init/templates/config.json").read_text(encoding="utf-8"))
if "linear" in config and config["linear"] != {}:
    failures.append("templates/config.json: Linear defaults must be absent or opt-in and empty")

for name in ("woostack-build", "woostack-fix", "woostack-plan"):
    text = re.sub(r"\s+", " ", (root / "skills" / name / "SKILL.md").read_text(encoding="utf-8"))
    if not re.search(r"Without .*make no Linear (?:read or write|call)|Otherwise make no Linear read or write", text, re.I):
        failures.append(f"{name}: does not require explicit artifact selection")
    if not re.search(r"policy.*(?:cannot|never).*authorize.*provider (?:read or )?write|policy alone.*no provider", text, re.I):
        failures.append(f"{name}: repository policy can still appear to authorize provider access")

change = re.sub(r"\s+", " ", (root / "skills/woostack-change/SKILL.md").read_text(encoding="utf-8"))
if not re.search(r"never reads or writes Linear", change, re.I):
    failures.append("woostack-change: does not remain Linear-free")

if failures:
    print("Linear plan contract violations:", file=sys.stderr)
    for failure in failures:
        print(f"  {failure}", file=sys.stderr)
    raise SystemExit(1)

print("Linear plan contract: ok")
PY
