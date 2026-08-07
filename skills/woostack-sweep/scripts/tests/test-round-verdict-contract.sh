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
    "branch command target": r"/woostack-sweep \[PR#\|branch\]",
    "exact branch binding": r"With `branch`, require one exact branch-name match.*bind that submitted branch to its canonical GitHub PR",
    "reject inferred branch": r"never infer the branch from a title, activity, issue data, or search order",
    "reject unsubmitted branch": r"Reject an unsubmitted branch.*ambiguous membership",
    "bottom-up": r"Process each in-range PR from oldest dependency to tip",
    "pre-existing address": r"Address pre-existing threads.*before review",
    "review exactly once": r"Invoke exactly one canonical multi-angle.*woostack-review <PR#>",
    "new findings": r"Address new findings.*every new finding",
    "all head changes invalidate review": r"Any explained head change produced by Address invalidates the prior Review for every finding severity",
    "restack changed head": r"restack affected descendants.*read back every affected head/base/ancestry.*repeat this PR's one Review → Address sequence",
    "unchanged progress": r"On an unchanged head, repeat after a blocking Review only when Address produced new evidence",
    "no-progress stop": r"blocker remains unresolved without new evidence, halt.*do not restack or re-review",
    "advance unchanged nits": r"only nits and every nit was resolved on the unchanged head, advance without re-review",
    "unchanged halt": r"same blocker recurs on an unchanged head with no new code or evidence",
    "clean gate": r"no unresolved blocker or nit.*replies/resolution reads are verified",
    "stack ready": r"every in-range submitted PR is clean and Graphite ancestry and heads are current",
    "fail closed": r"missing/partial review, unknown check, or unsafe decision is blocked",
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
