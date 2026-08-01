#!/usr/bin/env bash
# Structural contract for repository-enabled Linear persistence of specifications and plans.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
files = {
    "plan": root / "skills/woostack-plan/SKILL.md",
    "build": root / "skills/woostack-build/SKILL.md",
    "harden": root / "skills/woostack-harden/SKILL.md",
    "artifact": root / "skills/woostack-init/references/artifact-backends.md",
    "context": root / "skills/woostack-build/references/linear-context.md",
    "procedure": root / "skills/woostack-build/references/linear-procedure.md",
}
text = {
    name: re.sub(r"\s+", " ", path.read_text(encoding="utf-8"))
    for name, path in files.items()
}
failures = []

def require(name, needle):
    if needle not in text[name]:
        failures.append(f"{name}: missing {needle!r}")

for needle in (
    "One approved specification in, one coherent plan out",
    "Repository-enabled persistence uses one project, one parent plan issue, and one child per increment",
    "independently read every mutation and hierarchy edge back",
    "never use artifact assignment/state/comments to authorize execution or prove completion",
):
    require("plan", needle)

for needle in (
    "Linear artifact contract",
    "A complete preflight makes plan persistence",
    "They do not",
):
    require("build", needle)
require("harden", "Artifact-free hardening")
require("harden", "blocks only artifact synchronization")
require("artifact", "optional durable artifacts for specifications, implementation plans")
require("artifact", "untrusted data")
require("context", "independent complete read-back")
require("artifact", "## Fix/build project closure")
require("artifact", "If no project exists, report that there is nothing to close")
require("context", "projectStatuses.canceled")
require("context", "exact project-status update, stable mutation identity, and independent")
require("procedure", "## Explicit abandonment")
require("procedure", "update only that project's native status")
require("procedure", "native identity, current status, and")
require("procedure", "stable closure mutation identity")
require("procedure", "canceled status name/ID and")
require("procedure", "first unproved closure")
require("procedure", "Do not archive or delete the project and do not bulk-change issue states")
require("procedure", "Handoff, replan, and blocker handling are not abandonment")
require("procedure", "never resume repository work")
require("procedure", "Independently read every")

if failures:
    print("repository-enabled planning artifact contract violations:", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    raise SystemExit(1)

print("test-linear-plan-contract: ok")
PY
