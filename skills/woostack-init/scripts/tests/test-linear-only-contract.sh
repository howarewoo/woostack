#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
export ROOT

python3 <<'PY'
import json
import os
import re
from pathlib import Path

root = Path(os.environ["ROOT"])
configs = [
    root / ".woostack/config.json",
    root / "skills/woostack-init/templates/config.json",
]
contracts = [
    root / "skills/woostack-init/references/artifact-backends.md",
    root / "skills/woostack-bootstrap/references/development.md",
    root / "skills/woostack-status/references/conventions.md",
]
findings: list[str] = []

for path in configs:
    data = json.loads(path.read_text())
    if "artifacts" in data:
        findings.append(f"{path.relative_to(root)}: artifacts.specPlan/backend selector remains active")
    linear = data.get("linear")
    expected = {"repository", "workspace", "team", "projectStatuses", "issueStates"}
    if not isinstance(linear, dict) or set(linear) != expected:
        findings.append(f"{path.relative_to(root)}: linear policy keys must be exactly {sorted(expected)!r}")
        continue
    expected_project = {
        "designApproved", "specHardened", "specApproved", "planning", "ready",
        "executionApproved", "executing", "inReview", "done", "abandoned", "paused",
    }
    expected_issue = {"planned", "executing", "inReview", "done", "blocked"}
    if set(linear["projectStatuses"]) != expected_project:
        findings.append(f"{path.relative_to(root)}: projectStatuses keys are not canonical")
    if set(linear["issueStates"]) != expected_issue:
        findings.append(f"{path.relative_to(root)}: issueStates keys are not canonical")
    credential = re.compile(r"(?:api.?key|token|secret|password|authorization|credential)", re.I)
    for key in linear:
        if credential.search(key):
            findings.append(f"{path.relative_to(root)}: credential-like linear key {key!r}")

rejection = re.compile(
    r"\b(?:no|not|never|remove[ds]?|reject(?:ed|s)?|forbid(?:den|s)?|legacy|migration|"
    r"obsolete|instead of|rather than|without|unaffected)\b",
    re.I,
)
for path in contracts:
    for number, line in enumerate(path.read_text().splitlines(), 1):
        active_patterns = (
            (r"artifacts\.specPlan", "backend selector"),
            (r"resolve-backend\.sh", "backend resolver"),
            (r"LINEAR_API_KEY", "repository credential"),
            (r"\b(?:Linear )?(?:specification )?document(?:-backed|\s+(?:owns|stores|is the source))", "document-backed development state"),
            (r"\bMarkdown\s+(?:is|remains|as)\s+(?:the\s+)?(?:default\s+)?(?:development\s+)?backend", "Markdown development backend"),
            (r"\blocal\s+(?:spec|plan|artifact)[^.;]*(?:authority|source of truth)", "local development-record authority"),
        )
        for pattern, label in active_patterns:
            if re.search(pattern, line, re.I) and not rejection.search(line):
                findings.append(f"{path.relative_to(root)}:{number}: active {label}: {line.strip()}")

canonical = (root / "skills/woostack-init/references/artifact-backends.md").read_text()
required = [
    "feature", "increment", "work-item",
    "designApproved", "executionApproved", "blockerResolved",
    "assignmentAccepted", "implementationEvidence", "reviewResult",
    "+++ Woostack metadata — managed, do not edit",
    "client-generated UUID", "projectStatuses", "issueStates",
    "Linear-Project: <project UUID>",
    "Linear-Issue: <TEAM-NUMBER>", "a `Spec:` trailer",
]
for value in required:
    if value not in canonical:
        findings.append(f"skills/woostack-init/references/artifact-backends.md: missing canonical contract value {value!r}")

if findings:
    print("Linear-only contract violations:")
    for finding in findings:
        print(f"  {finding}")
    raise SystemExit(1)

print("Linear-only contract: PASS")
PY
