#!/usr/bin/env bash
# Structural contract for collision-safe descendant restacks.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

text = re.sub(r"\s+", " ", (Path(sys.argv[1]) / "skills/woostack-sweep/SKILL.md").read_text())
checks = {
    "descendant inventory": r"inventory every descendant that can move, including descendants outside the display range",
    "worktree evidence": r"deterministic worktree path, `git worktree list --porcelain` entry.*branch/head/base",
    "collision gate": r"disjoint worktrees, no competing operation, no duplicate checkout or branch, no unpushed work",
    "operation identity": r"Bind the operation to the exact affected set and current heads",
    "fresh reread": r"re-read all facts immediately before mutation",
    "Graphite only": r"stack-scoped `gt restack`; never run `gt sync`",
    "semantic conflict": r"inspect every unmerged index stage and replayed patch, reconcile both PR intents",
    "exact staging": r"stage only resolved paths",
    "decision stop": r"stop when a product or scope decision is required",
    "post verification": r"read every affected descendant's head/base/ancestry and re-run focused checks",
    "unknown recovery": r"Unknown mutation outcomes require complete discovery before retry",
}
failures = [name for name, pattern in checks.items() if not re.search(pattern, text, re.I | re.S)]
if failures:
    print("sweep restack contract violations:", file=sys.stderr)
    print("\n".join(f"- {failure}" for failure in failures), file=sys.stderr)
    raise SystemExit(1)
print("collision-safe sweep restack contract: ok")
PY
