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
mergeability_case = next((case for case in evals["cases"] if case.get("id") == "stale-parent-mergeability-matrix"), None)
fixture_failures = []
actions_case = next((case for case in evals["cases"] if case.get("id") == "actions-checks-do-not-gate"), None)
if not actions_case:
    fixture_failures.append("Actions/check independence fixture missing")
else:
    action_assertion_ids = {assertion.get("id") for assertion in actions_case.get("assertions", [])}
    required_action_ids = {
        "bottom-up-order", "pending-check-input", "failed-check-input",
        "zero-check-blockers", "clean-prs", "ready-stack",
    }
    missing_action_ids = required_action_ids - action_assertion_ids
    if missing_action_ids:
        fixture_failures.append(f"Actions/check independence assertions missing: {sorted(missing_action_ids)}")
    action_prompt = actions_case.get("prompt", "").lower()
    action_expected = actions_case.get("expected", "").lower()
    if "pending" not in action_prompt or "failed" not in action_prompt or "check" not in action_prompt:
        fixture_failures.append("Actions/check independence prompt must encode pending and failed checks")
    if "bottom-up" not in action_expected or "ready" not in action_expected:
        fixture_failures.append("Actions/check independence expected outcome must encode bottom-up readiness")

if not max_round_case:
    fixture_failures.append("max-rounds fixture missing")
else:
    prompt = max_round_case.get("prompt", "").lower()
    expected = max_round_case.get("expected", "").lower()
    if "blocker" not in prompt or "nit" in prompt:
        fixture_failures.append("max-rounds prompt must encode blockers, not nits")
    if "block" not in expected or "nit" in expected:
        fixture_failures.append("max-rounds expected outcome must encode blocking, not nits")
if not mergeability_case:
    fixture_failures.append("stale-parent mergeability fixture missing")
else:
    assertion_ids = {assertion.get("id") for assertion in mergeability_case.get("assertions", [])}
    required_ids = {
        "mergeable-review-once", "mergeable-no-restack", "mergeable-clean-eligible",
        "stale-sync-informational", "stale-sync-does-not-invalidate",
        "conflicting-no-review", "conflicting-no-address", "conflicting-not-clean-eligible",
        "conflicting-guarded-restack", "unknown-no-review", "unknown-no-address", "unknown-not-clean-eligible",
        "unknown-no-restack", "unknown-blocked",
        "direct-review-independent", "direct-review-no-conflict-authority",
    }
    missing_ids = required_ids - assertion_ids
    if missing_ids:
        fixture_failures.append(f"stale-parent mergeability assertions missing: {sorted(missing_ids)}")
checks = {
    "branch command target": r"/woostack-sweep \[PR#\|branch\]",
    "exact branch binding": r"With `branch`, require one exact branch-name match.*bind that submitted branch to its canonical GitHub PR",
    "reject inferred branch": r"never infer the branch from a title, activity, issue data, or search order",
    "bottom-up": r"Process each in-range PR from oldest dependency to tip",
    "reject unsubmitted branch": r"Reject an unsubmitted branch.*ambiguous membership",
    "pre-existing address": r"Address pre-existing threads.*before review",
    "review exactly once": r"Invoke exactly one canonical multi-angle.*woostack-review <PR#>",
    "new findings": r"Address new findings.*every new finding",
    "blocker-only head invalidation": r"explained head change.*only when.*blocker|blocker.*explained head change.*invalidates.*prior Review",
    "qualified head/thread drift": r"external, unexplained, or unverified head or thread-set change invalidates.*verified Address/restack transitions.*round-outcome branch",
    "frozen review classification": r"freeze the zero-blocker/blocker classification.*complete just-completed Review result.*resolution cannot erase a blocker",
    "clean gate": r"no unresolved blocker or nit.*replies/resolution reads are verified",
    "parent identity membership split": r"Graphite parent identity and ancestry membership separately from parent-head synchronization",
    "exact mergeability pair": r"canonical GitHub mergeability for the exact PR/current Graphite parent pair",
    "mergeable permits review": r"`MERGEABLE` permits exactly one canonical Review sequence and clean eligibility",
    "conflicting guarded restack": r"`CONFLICTING` enters the existing guarded restack/reconciliation boundary",
    "unknown mergeability blocks": r"non-conclusive mergeability evidence, including `UNKNOWN`, blocks",
    "sync mismatch informational": r"Parent-head synchronization mismatch alone is informational, does not invalidate a round, and never triggers restack",
    "fail closed": r"missing/partial review or unsafe decision is blocked",
    "stack ready": r"Graphite parent identity and ancestry membership.*canonical GitHub mergeability.*conclusive and `MERGEABLE`",
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
}
failures = [name for name, pattern in checks.items() if not re.search(pattern, text, re.I | re.S)]
failures.extend(fixture_failures)
for forbidden in ("Linear", "artifact", "--interactive", "--full", "every finding severity", "only nits and every nit", "a head or thread-set change invalidates that round", "unknown check"):
    if forbidden.lower() in text.lower():
        failures.append(f"obsolete {forbidden} path")
if failures:
    print("sweep round contract violations:", file=sys.stderr)
    print("\n".join(f"- {failure}" for failure in failures), file=sys.stderr)
    raise SystemExit(1)
print("bottom-up sweep round contract: ok")
PY
