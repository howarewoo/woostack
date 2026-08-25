#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
shared = root / "skills/woostack-init/references/artifact-backends.md"
profiles = {
    "linear": root / "skills/woostack-init/references/artifact-providers/linear.md",
    "plane": root / "skills/woostack-init/references/artifact-providers/plane.md",
}
entrypoints = {
    "using": root / "skills/using-woostack/SKILL.md",
    "init": root / "skills/woostack-init/SKILL.md",
    "bootstrap": root / "skills/woostack-bootstrap/SKILL.md",
    "build": root / "skills/woostack-build/SKILL.md",
    "fix": root / "skills/woostack-fix/SKILL.md",
    "plan": root / "skills/woostack-plan/SKILL.md",
    "execute": root / "skills/woostack-execute/SKILL.md",
    "commit": root / "skills/woostack-commit/references/provider-attribution.md",
    "debug": root / "skills/woostack-debug/SKILL.md",
    "audit": root / "skills/woostack-audit/SKILL.md",
    "status": root / "skills/woostack-status/SKILL.md",
    "visualize": root / "skills/woostack-visualize/SKILL.md",
}
failures = []

for path in (shared, *profiles.values(), *entrypoints.values()):
    if not path.is_file():
        failures.append(f"missing reference: {path.relative_to(root)}")

texts = {name: path.read_text(encoding="utf-8") for name, path in profiles.items()}
shared_text = shared.read_text(encoding="utf-8")

required_sections = (
    "Configuration and scope",
    "Capabilities",
    "Projects and labels",
    "Lifecycle and closure",
    "Workflow procedures",
)
for provider, text in texts.items():
    for heading in required_sections:
        if f"## {heading}" not in text:
            failures.append(f"{provider}: missing parallel section {heading!r}")
    if "../artifact-backends.md" not in text:
        failures.append(f"{provider}: missing shared contract link")

for literal in (
    "artifact-providers/linear.md",
    "artifact-providers/plane.md",
    "load only the selected profile",
    "Adding a provider requires a new profile",
):
    if literal not in shared_text:
        failures.append(f"shared contract missing {literal!r}")

for leaked in (
    r"artifacts\.linear",
    r"artifacts\.plane",
    r"external_source",
    r"projectStatuses",
    r"issueStates",
    r"official Linear MCP",
    r"official Plane MCP",
):
    if re.search(leaked, shared_text, re.I):
        failures.append(f"shared contract leaks provider implementation: {leaked}")

linear_requirements = (
    "canonical issue reference",
    "workspace", "team", "projectStatuses", "issueStates",
    "Woostack project mutation ID", "[woostack-mutation:<UUID>]",
)
plane_requirements = (
    "baseUrl", "workspace", "external_source", "external_id",
    "readable identifier", "parent = null", "direct project membership",
    "Never mutate, synthesize",
)
for literal in linear_requirements:
    if literal not in texts["linear"]:
        failures.append(f"linear profile missing {literal!r}")
for literal in plane_requirements:
    if literal not in texts["plane"]:
        failures.append(f"plane profile missing {literal!r}")

for name, path in entrypoints.items():
    text = path.read_text(encoding="utf-8")
    if "artifact-providers/linear.md" not in text:
        failures.append(f"{name}: missing Linear profile dispatch")
    if name != "init" and "artifact-providers/plane.md" not in text:
        failures.append(f"{name}: missing Plane profile dispatch")

if failures:
    print("provider profile contract failed:", file=sys.stderr)
    for failure in failures:
        print(f"- {failure}", file=sys.stderr)
    raise SystemExit(1)

print("test-artifact-provider-profiles: ok")
PY
