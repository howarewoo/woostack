#!/usr/bin/env bash
# Structural boundaries for the direct, bounded one-PR Change workflow.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
change = re.sub(r"\s+", " ", (root / "skills/woostack-change/SKILL.md").read_text())
route = re.sub(r"\s+", " ", (root / "skills/using-woostack/SKILL.md").read_text())

required = {
    "command": r"/woostack-change <goal>",
    "bounded admission": r"small bounded non-bug.*one reviewable PR",
    "clarify before mutation": r"Clarify only what is needed.*Do not create a branch, worktree, or file change while classifying or clarifying",
    "direct ownership": r"makes no Linear call and invokes no other woostack workflow.*owns implementation and delivery",
    "bug reroute": r"bug, regression.*woostack-fix",
    "multi-pr reroute": r"multiple PRs.*woostack-build",
    "preflight": r"git worktree list --porcelain.*local and remote branches.*Graphite ancestry.*canonical GitHub PR state",
    "direct isolation": r"Create one isolated worktree.*one Graphite branch",
    "direct implementation": r"implement every change needed for the accepted bounded scope",
    "focused smoke": r"focused verification and the changed-path smoke scenario",
    "one PR": r"submit at most one PR",
    "delivery readback": r"read back the exact repository, branch, parent, commit.*PR URL.*head/base",
    "success cleanup": r"only after successful delivery.*verified clean",
    "failure retention": r"fails, is blocked, or has an unknown outcome, retain the worktree",
    "resume evidence": r"exact Git, Graphite, and GitHub resume evidence",
}
failures = [name for name, pattern in required.items() if not re.search(pattern, change, re.I | re.S)]

forbidden = [
    "artifact",
    "approval record",
    "project record",
    "woostack-execute",
    "woostack-commit",
    "woostack-review",
    "woostack-address-comments",
    "woostack-sweep",
    "woostack-ideate",
    "woostack-harden",
    "woostack-plan",
]
failures.extend(f"forbidden surface: {term}" for term in forbidden if re.search(re.escape(term), change, re.I))
if not re.search(r"/woostack-change <goal>.*small bounded non-bug.*isolated worktree.*reviewable PR", route, re.I | re.S):
    failures.append("routing row")

if failures:
    print("change contract violations:", file=sys.stderr)
    print("\n".join(f"- {failure}" for failure in failures), file=sys.stderr)
    raise SystemExit(1)
print("direct bounded Change contract: ok")
PY
