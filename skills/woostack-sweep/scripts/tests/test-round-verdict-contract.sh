#!/usr/bin/env bash
# Structural contract for bottom-up sweep rounds.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

text = re.sub(r"\s+", " ", (Path(sys.argv[1]) / "skills/woostack-sweep/SKILL.md").read_text())
checks = {
    "bottom-up": r"Process each in-range PR from oldest dependency to tip",
    "pre-existing address": r"Address pre-existing threads.*before review",
    "review exactly once": r"Invoke exactly one canonical multi-angle.*woostack-review <PR#>",
    "new findings": r"Address new findings.*every new finding",
    "re-review needs progress": r"repeat this same PR's Address → one Review → Address sequence only when Address produced new code or new evidence",
    "restack changed head": r"When the head changed, restack affected descendants.*read back every affected head/base/ancestry",
    "no-progress stop": r"blocker remains unresolved without new code or evidence, halt.*do not restack or re-review",
    "advance nits": r"only nits and all nits are resolved, advance to the next PR without re-review",
    "unchanged halt": r"same blocker recurs on an unchanged head with no new code or evidence",
    "clean gate": r"no unresolved blocker or nit.*replies/resolution reads are verified",
    "stack ready": r"every in-range submitted PR is clean and Graphite ancestry and heads are current",
    "fail closed": r"missing/partial review, unknown check, changed head, or unsafe decision is blocked",
}
failures = [name for name, pattern in checks.items() if not re.search(pattern, text, re.I | re.S)]
for forbidden in ("Linear", "artifact", "--interactive", "--full"):
    if forbidden.lower() in text.lower():
        failures.append(f"obsolete {forbidden} path")
if failures:
    print("sweep round contract violations:", file=sys.stderr)
    print("\n".join(f"- {failure}" for failure in failures), file=sys.stderr)
    raise SystemExit(1)
print("bottom-up sweep round contract: ok")
PY
