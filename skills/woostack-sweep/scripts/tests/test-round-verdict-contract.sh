#!/usr/bin/env bash
# Structural contract for bottom-up sweep rounds.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
text = re.sub(r"\s+", " ", (root / "skills/woostack-sweep/SKILL.md").read_text())
evals = json.loads((root / "skills/woostack-sweep/evals/evals.json").read_text())
max_round_case = next((case for case in evals["cases"] if case.get("id") == "max-rounds-blocks-next-head-review"), None)
fixture_failures = []
if not max_round_case:
    fixture_failures.append("max-rounds fixture missing")
else:
    prompt = max_round_case.get("prompt", "").lower()
    expected = max_round_case.get("expected", "").lower()
    if "blocker" not in prompt or "nit" in prompt:
        fixture_failures.append("max-rounds prompt must encode blockers, not nits")
    if "block" not in expected or "nit" in expected:
        fixture_failures.append("max-rounds expected outcome must encode blocking, not nits")
checks = {
    "branch command target": r"/woostack-sweep \[PR#\|branch\]",
    "exact branch binding": r"With `branch`, require one exact branch-name match.*bind that submitted branch to its canonical GitHub PR",
    "reject inferred branch": r"never infer the branch from a title, activity, issue data, or search order",
    "reject unsubmitted branch": r"Reject an unsubmitted branch.*ambiguous membership",
    "bottom-up": r"Process each in-range PR from oldest dependency to tip",
    "pre-existing address": r"Address pre-existing threads.*before review",
    "review exactly once": r"Invoke exactly one canonical multi-angle.*woostack-review <PR#>",
    "new findings": r"Address new findings.*every new finding",
    "blocker-only head invalidation": r"explained head change.*only when.*blocker|blocker.*explained head change.*invalidates.*prior Review",
    "zero-blocker changed head advances": r"zero-blocker.*(correction-only|changed-head).*advance.*without re-review",
    "native comment cannot override": r"computed zero-blocker outcome.*actor-gated native COMMENT|computed.*zero-blocker.*over.*native COMMENT",
    "qualified head/thread drift": r"external, unexplained, or unverified head or thread-set change invalidates.*verified Address/restack transitions.*round-outcome branch",
    "frozen review classification": r"freeze the zero-blocker/blocker classification.*complete just-completed Review result.*resolution cannot erase a blocker",
    "unsafe correction delta blocks": r"unrelated, partial, or unverified deltas.*block",
    "correction-only proof": r"correction-only delta proof",
    "complete address evidence": r"full reply/resolution evidence",
    "focused verification": r"focused (checks|verification)",
    "restack descendants before advance": r"descendant restack",
    "complete changed-head read-back": r"complete head/base/ancestry/thread read-back",
    "blocker changed head reruns": r"blocker.*(mixed|explained head).*rerun|blocker.*repeat.*Review",
    "unchanged blocker progress": r"On an unchanged head, repeat after a blocking Review only when Address produced new evidence",
    "no-progress stop": r"blocker remains unresolved without new evidence, halt.*do not restack or re-review",
    "unchanged halt": r"same blocker recurs on an unchanged head with no new code or evidence",
    "clean gate": r"no unresolved blocker or nit.*replies/resolution reads are verified",
    "stack ready": r"every in-range submitted PR is clean and Graphite ancestry and heads are current",
    "fail closed": r"missing/partial review, unknown check, or unsafe decision is blocked",
}
failures = [name for name, pattern in checks.items() if not re.search(pattern, text, re.I | re.S)]
failures.extend(fixture_failures)
for forbidden in ("Linear", "artifact", "--interactive", "--full", "every finding severity", "only nits and every nit", "a head or thread-set change invalidates that round"):
    if forbidden.lower() in text.lower():
        failures.append(f"obsolete {forbidden} path")
if failures:
    print("sweep round contract violations:", file=sys.stderr)
    print("\n".join(f"- {failure}" for failure in failures), file=sys.stderr)
    raise SystemExit(1)
print("bottom-up sweep round contract: ok")
PY
