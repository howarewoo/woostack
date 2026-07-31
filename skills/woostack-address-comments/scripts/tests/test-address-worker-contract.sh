#!/usr/bin/env bash
# Structural contract for advisory thread analysis workers.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path
text=re.sub(r"\s+"," ",(Path(sys.argv[1])/"skills/woostack-address-comments/prompts/address.md").read_text())
checks={
 "fanout":r"Optional worker fan-out",
 "record":r"threadId, file, line, finding, recommended, reasoning, reply, fix_plan",
 "no worker mutations":r"must not edit files, commit, push, reply, resolve, write memory, mutate GitHub/Linear",
 "gate":r"Phase 2.*Silence is not approval",
 "fix plan":r"fix plan in the FIX option text",
 "override confirmation":r"override becomes FIX.*bounded confirm",
 "head recheck":r"re-read the canonical PR/head",
 "uncommitted batching":r"do not commit per thread",
 "actual pushed sha":r"real pushed head/commit before drafting `Fixed in <sha>`",
 "unknown recovery":r"Unknown outcomes require discovery before retry",
}
failures=[name for name,pat in checks.items() if not re.search(pat,text,re.I|re.S)]
if failures:
 print("address worker contract violations:",file=sys.stderr)
 print("\n".join(f"- {f}" for f in failures),file=sys.stderr)
 raise SystemExit(1)
print("advisory address worker contract: ok")
PY
