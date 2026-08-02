#!/usr/bin/env bash
# Structural contract for bounded bottom-up review rounds.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path

text = re.sub(
    r"\s+",
    " ",
    (Path(sys.argv[1]) / "skills/woostack-sweep/SKILL.md").read_text(),
)
checks = {
    "bottom up": r"Process PRs bottom-up",
    "identity": r"canonical PR number, head SHA, base SHA/branch, complete thread set, changed paths, and approved task contract",
    "full review": r"woostack-review --full.*exact PR/head",
    "independent reviewer": r"implementing coder cannot act as the independent reviewer",
    "clean classification": r"clean only when.*no blocking findings.*checks pass.*no unresolved blocking thread",
    "fail closed": r"missing reviewer, partial result, unknown check, or changed head is `blocked`",
    "transition gate": r"\*\*Address once before any transition\.\*\*",
    "current-head refresh": r"Before moving to another PR or returning any terminal result, refresh the exact current-head unresolved-thread snapshot",
    "address before transition": r"snapshot is nonempty.*invoke.*woostack-address-comments.*once before advancing or stopping",
    "independent threads": r"canonical loop.*other independent threads.*one blocked thread.*skip",
    "post-attempt refresh": r"After the attempt, refetch.*canonical PR/head.*complete unresolved-thread set",
    "address result snapshot": r"changes attributable to the completed addressing attempt are the expected refreshed state for the next decision",
    "unexpected drift discovery": r"Only unexpected or concurrent head or thread-set drift invalidates the round.*restarts discovery.*fresh stable snapshot",
    "no-thread flow": r"snapshot is empty.*do not invoke.*solely for this gate.*existing no-thread flow",
    "truthful unsafe stop": r"unsafe, failed, or decision-blocked attempt may stop truthfully, but only after the attempt",
    "verify": r"focused verification.*unchanged addressed diff",
    "follow-up decision question": r"Before dispatching.*generic post-address follow-up review.*distinct decision question.*each proposed assignment",
    "one focused follow-up reviewer": r"Default to one focused skeptical reviewer over the addressed diff and unchanged acceptance criteria",
    "same-evidence follow-up collapse": r"would accept or reject on the same evidence.*combine them or.*only the stronger reviewer",
    "confidence and symmetry prohibit duplication": r"Confidence (?:or|and|/) symmetry never justif(?:y|ies) duplication",
    "cost cancellation and quiescence": r"user flags review cost.*cancel overlapping work.*confirm.*quiescent.*minimum required set",
    "generic follow-up scope": r"gate applies only to generic post-address follow-up reviewers",
    "initial angle and chunk workers preserved": r"does not collapse.*initial.*angle/chunk workers.*distinct angle contracts",
    "canonical full re-review preserved": r"Step 6.*canonical current-head full re-review",
    "adversarial validators preserved": r"Prosecutor/Defender validators.*opposing biases.*distinct contracts",
    "fresh re-review": r"Fetch the updated PR/head and run a new full review.*Never reuse a result from a prior head",
    "post-attempt bounds": r"Only after this gate.*required attempt.*review\.max_rounds.*repeated complete finding/thread signature.*no repository progress.*blocker.*required decision",
    "no downgrade": r"Do not silently downgrade full review to self-review",
}
failures = [
    name for name, pattern in checks.items() if not re.search(pattern, text, re.I | re.S)
]

round_tail = re.search(
    r"3\. \*\*Address once before any transition\.\*\*(.*?)## Stack-scoped restack boundary",
    text,
    re.I | re.S,
)
if not round_tail:
    failures.append("transition ordering section")
else:
    ordered = [
        "refresh the exact current-head unresolved-thread snapshot",
        "invoke [`woostack-address-comments`",
        "After the attempt, refetch",
        "changes attributable to the completed addressing attempt",
        "Only unexpected or concurrent head or thread-set drift",
        "Only after this gate",
        "`review.max_rounds`",
    ]
    positions = [round_tail.group(1).find(marker) for marker in ordered]
    if any(position < 0 for position in positions) or positions != sorted(positions):
        failures.append("max-round open-thread address-before-stop ordering")

if failures:
    print("sweep round contract violations:", file=sys.stderr)
    print("\n".join(f"- {failure}" for failure in failures), file=sys.stderr)
    raise SystemExit(1)
print("bounded sweep rounds (open-thread address precedes max-round stop): ok")
PY
