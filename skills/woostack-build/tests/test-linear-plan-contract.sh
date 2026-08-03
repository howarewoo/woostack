#!/usr/bin/env bash
# Structural contract for strict sequential direct-issue planning.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

plan = (Path(sys.argv[1]) / "skills/woostack-plan/SKILL.md").read_text(encoding="utf-8")
text = re.sub(r"\s+", " ", plan)
failures = []


def require(needle):
    if needle not in text:
        failures.append(f"plan: missing {needle!r}")


def forbid(pattern):
    if re.search(pattern, text, re.I):
        failures.append(f"plan: matches forbidden pattern {pattern!r}")

for needle in (
    "`--project` is mandatory",
    "exact existing Linear project",
    "never creates or selects an implicit project",
    "one complete approved specification",
    "approved specification fingerprint",
    "exactly one direct project issue for each execution increment",
    "Never create a parent, container, checklist, layer, or plan issue",
    "stable task ID, unique positive ordinal",
    "exactly one intended PR",
    "exact scope and explicit non-goals",
    "exact files and symbols, or one bounded first discovery step",
    "ordered, concrete implementation steps",
    "observable acceptance criteria, each mapped to an implementation step",
    "focused checks and one executable smoke scenario",
    "cross-increment effects",
    "risks and active blockers",
    "explicit stop marker",
    "declared Graphite parent",
    "500 or fewer hand-written changed lines",
    "Generated files and lockfiles may exceed",
    "explicitly approved deletion-only PR",
    "strict sequential chain",
    "positive integers `1..N`",
    "ordinal k (2..N): ordinal k-1 → ordinal k",
    "exactly the matching predecessor edge",
    "Independently read every project, issue, membership",
    "Delegated planning performs no provider read or mutation",
    "wrapper hardens the candidate and then synchronizes",
    "owns no approval gate",
    "implementation, source edit, commit, branch, PR, review, merge",
):
    require(needle)

for pattern in (
    r"artifact-free",
    r"conversational-only",
    r"may create (?:a |an )?(?:new |implicit )?project",
    r"parallel(?:izable)? roots?",
    r"general DAG",
    r"one project, one parent plan issue",
):
    forbid(pattern)

if failures:
    print("strict sequential Plan contract violations:", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    raise SystemExit(1)

print("test-linear-plan-contract: ok")
PY
