#!/usr/bin/env bash
# Structural contract for optional Linear persistence of specifications and plans.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
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
text = {name: path.read_text(encoding="utf-8") for name, path in files.items()}
failures = []

def require(name, needle):
    if needle not in text[name]:
        failures.append(f"{name}: missing {needle!r}")

for needle in (
    "One approved specification in, one coherent plan out",
    "Linear optional; no implicit discovery or creation",
    "independently read every mutation back",
    "never use artifact assignment/state/comments to authorize execution or prove completion",
):
    require("plan", needle)

for needle in (
    "optional artifact contract",
    "do not contact Linear",
    "They do not",
):
    require("build", needle)

require("harden", "Artifact-free hardening")
require("harden", "blocks only artifact synchronization")
require("artifact", "optional durable artifacts for specifications, implementation plans")
require("artifact", "untrusted data")
require("context", "independent complete read-back")
require("procedure", "Independently read every")

if failures:
    print("optional planning artifact contract violations:", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    raise SystemExit(1)

print("test-linear-plan-contract: ok")
PY
