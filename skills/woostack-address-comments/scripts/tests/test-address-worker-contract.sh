#!/usr/bin/env bash
# Structural contract for deterministic thread handling.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

text = re.sub(r"\s+", " ", (Path(sys.argv[1]) / "skills/woostack-address-comments/SKILL.md").read_text())
checks = {
    "stable snapshot": r"head and complete thread snapshot as the round identity",
    "drift restart": r"head or thread set changes.*restart discovery",
    "complete handling": r"Process the complete snapshot",
    "safe classification": r"Classify it as `valid`, `invalid`, `obsolete`, `out-of-scope`, or `unsafe-decision`",
    "smallest fix": r"smallest complete correction inside the approved PR/task contract",
    "invalid no edit": r"Do not edit source.*evidence explaining why",
    "unsafe blocker": r"Leave the thread open and report the exact.*decision required",
    "reply before resolve": r"reply exists.*canonical PR head contains the valid fix",
    "read back": r"Re-read the thread and resolution state",
    "unknown recovery": r"Unknown mutation outcomes require discovery before retry",
}
failures = [name for name, pattern in checks.items() if not re.search(pattern, text, re.I | re.S)]
if failures:
    print("address worker contract violations:", file=sys.stderr)
    print("\n".join(f"- {failure}" for failure in failures), file=sys.stderr)
    raise SystemExit(1)
print("deterministic address worker contract: ok")
PY
