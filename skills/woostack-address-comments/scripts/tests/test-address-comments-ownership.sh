#!/usr/bin/env bash
# Structural contract for exact-PR thread addressing.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

text = re.sub(r"\s+", " ", (Path(sys.argv[1]) / "skills/woostack-address-comments/SKILL.md").read_text())
checks = {
    "exact PR required": r"`PR#` is required.*exactly one existing open PR",
    "no inference": r"never infers a PR from a branch, title, activity, or search result",
    "deterministic order": r"Sort unresolved top-level threads by path, line, and stable thread ID",
    "valid fix": r"Valid concern\.\*\* Apply the smallest complete correction",
    "focused verification": r"Run focused verification for the changed behavior",
    "invalid no edit": r"Invalid, obsolete, or out-of-scope\.\*\* Do not edit source",
    "unsafe stays open": r"Unsafe decision\.\*\* Do not edit or resolve.*Leave the thread open",
    "evidence reply": r"Evidence reply\.\*\* After the relevant evidence is verified",
    "resolution readback": r"Resolve and read back\.\*\* Resolve only after the reply exists",
    "all threads": r"Continue until every discovered thread is handled",
    "never merge": r"Never reset, stash, overwrite, force-push, or merge",
}
failures = [name for name, pattern in checks.items() if not re.search(pattern, text, re.I | re.S)]
for forbidden in ("Linear", "artifact", "--interactive"):
    if forbidden.lower() in text.lower():
        failures.append(f"obsolete {forbidden} path")
if failures:
    print("address-comments contract violations:", file=sys.stderr)
    print("\n".join(f"- {failure}" for failure in failures), file=sys.stderr)
    raise SystemExit(1)
print("exact-PR address-comments contract: ok")
PY
