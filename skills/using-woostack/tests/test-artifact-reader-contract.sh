#!/usr/bin/env bash
# Structural contract for artifact-optional read-only utility skills.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${WOOSTACK_READER_ROOT:-$(cd "$HERE/../../.." && pwd)}"

python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
skills = (
    "woostack-debug",
    "woostack-tdd",
    "woostack-visualize",
)
failures = []

for name in skills:
    path = root / "skills" / name / "SKILL.md"
    if not path.is_file():
        failures.append(f"{name}: missing SKILL.md")
        continue
    text = path.read_text(encoding="utf-8")
    folded = re.sub(r"\s+", " ", text)
    if not re.search(r"optional.{0,120}(?:Linear )?artifact|artifact.{0,120}optional|needs no Linear read", folded, re.I):
        failures.append(f"{name}: artifact context is not optional")
    if "../woostack-init/references/artifact-backends.md" not in text:
        failures.append(f"{name}: does not link the optional artifact contract")
    if re.search(r"(?:requires?|must have|exactly one) (?:an? |the )?(?:managed |Linear )?(?:issue|project)", folded, re.I):
        failures.append(f"{name}: retains a mandatory issue/project prerequisite")
    if not re.search(r"(?:remote|artifact) text.{0,120}(?:untrusted|cannot direct|cannot trigger)|untrusted (?:data|evidence)", folded, re.I):
        failures.append(f"{name}: does not quarantine remote text")


if failures:
    print("FAIL: artifact-optional utility contract", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    raise SystemExit(1)

print("validated 3 artifact-optional utility skills")
PY
