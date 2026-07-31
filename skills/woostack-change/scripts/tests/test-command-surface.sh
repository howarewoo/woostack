#!/usr/bin/env bash
# Structural contract for bounded artifact-free changes.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path
root=Path(sys.argv[1])
text=re.sub(r"\s+"," ",(root/"skills/woostack-change/SKILL.md").read_text())
route=re.sub(r"\s+"," ",(root/"skills/using-woostack/SKILL.md").read_text())
checks={
 "command":r"/woostack-change <goal>.*--issue",
 "optional issue":r"Without it, make no Linear call and never create an issue implicitly",
 "no hard gate":r"workflow has no hard approval gate",
 "classification":r"bugs, regressions.*woostack-fix.*greenfield.*woostack-bootstrap.*multiple coherent PRs.*woostack-build",
 "bounded contract":r"observable goal and target.*acceptance criteria.*allowed paths.*verification",
 "collision preflight":r"inventory local/remote branches, worktrees, registry claims, Graphite ancestry",
 "isolated execution":r"Delegate the approved bounded task to.*woostack-execute",
 "independent review":r"No self-review or self-acceptance",
 "Graphite delivery":r"Use Graphite, submit/update exactly one PR",
 "artifact separation":r"Artifact failure is reported separately",
 "never merge":r"Never force-push or merge",
 "route":r"/woostack-change <goal>.*woostack-change",
}
failures=[]
for name,pat in checks.items():
 source=route if name=="route" else text
 if not re.search(pat,source,re.I|re.S): failures.append(name)
if re.search(r"must.*(?:Linear|issue).*(?:before edit|before branch)|Linear-Issue:",text,re.I|re.S):
 failures.append("mandatory issue prerequisite")
if failures:
 print("change contract violations:",file=sys.stderr)
 print("\n".join(f"- {f}" for f in failures),file=sys.stderr)
 raise SystemExit(1)
print("artifact-free change contract: ok")
PY
