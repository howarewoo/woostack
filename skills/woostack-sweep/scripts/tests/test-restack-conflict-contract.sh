#!/usr/bin/env bash
# Structural contract for collision-safe stack-scoped restacks.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path
text=re.sub(r"\s+"," ",(Path(sys.argv[1])/"skills/woostack-sweep/SKILL.md").read_text())
checks={
 "descendant inventory":r"inventory every descendant branch/PR.*including descendants above the requested display range",
 "fresh state":r"deterministic path.*git worktree list.*current local/remote head, base, Graphite parent, canonical PR.*dirty/index/diff state.*approved task/dependency contract",
 "collision gate":r"disjoint worktrees and no competing operation, duplicate checkout/branch/PR, unpushed work, unexplained checkout, ancestry mismatch, or collision",
 "operation identity":r"bind one operation identity to the exact affected set and current heads",
 "fresh reread":r"re-read all facts immediately before mutation",
 "Graphite only":r"stack-scoped `gt restack`; never `gt sync`, force-push, or a repo-wide rewrite",
 "semantic conflict":r"inspect every unmerged index stage and the replayed patch.*Reconcile both PR intents",
 "no side discard":r"never choose an entire `ours` or `theirs` side",
 "exact staging":r"Stage only resolved paths and continue with the exact Graphite command",
 "decision stop":r"Abort and preserve state when the conflict requires a product/scope decision",
 "post verification":r"verify every affected descendant's new head/base/ancestry.*focused checks.*re-review",
 "submit affected":r"Submit only the exact affected stack after all resulting heads are verified",
 "unknown outcome":r"Unknown mutation outcome requires full discovery before retry",
 "reopen guard":r"same PR/head/task contract remains.*deterministic path is free.*no competing checkout exists",
 "no destructive recovery":r"Never delete, reset, stash, overwrite, attach, or create around unexplained state",
}
failures=[name for name,pat in checks.items() if not re.search(pat,text,re.I|re.S)]
if failures:
 print("sweep restack contract violations:",file=sys.stderr)
 print("\n".join(f"- {f}" for f in failures),file=sys.stderr)
 raise SystemExit(1)
print("collision-safe sweep restack: ok")
PY
