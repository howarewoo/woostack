#!/usr/bin/env bash
# Structural contract: Linear stores optional artifacts; it never gates repository work.
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

contract_path = root / "skills/woostack-init/references/artifact-backends.md"
contract = re.sub(r"\s+", " ", contract_path.read_text(encoding="utf-8"))
for pattern, message in (
    (r"Linear projects and issues are optional durable artifacts", "optional provider role missing"),
    (r"not development authority", "artifact authority boundary missing"),
    (r"host's authenticated official Linear MCP", "official transport boundary missing"),
    (r"stable client-generated operation ID", "idempotent mutation rule missing"),
    (r"perform a new independent complete read", "read-back rule missing"),
    (r"blocks only requested artifact use", "artifact-independent degradation missing"),
):
    if not re.search(pattern, contract, re.I):
        failures.append(f"artifact-backends.md: {message}")

config = json.loads((root / "skills/woostack-init/templates/config.json").read_text(encoding="utf-8"))
if "linear" in config and config["linear"] != {}:
    failures.append("templates/config.json: Linear defaults must be absent or opt-in and empty")

for name in ("woostack-commit", "woostack-fix", "woostack-change", "woostack-build", "woostack-plan", "woostack-execute"):
    text = re.sub(r"\s+", " ", (root / "skills" / name / "SKILL.md").read_text(encoding="utf-8"))
    if not re.search(r"Linear (?:is )?(?:an )?optional|optional Linear|artifact-free|Without (?:it|artifact flags), make no Linear call", text, re.I):
        failures.append(f"{name}: does not state artifact-free operation")

if failures:
    print("Artifact-optional contract violations:", file=sys.stderr)
    for failure in failures:
        print(f"  {failure}", file=sys.stderr)
    raise SystemExit(1)

print("artifact-optional contract: ok")
PY
