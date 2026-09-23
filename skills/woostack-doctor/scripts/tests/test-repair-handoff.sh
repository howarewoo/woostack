#!/usr/bin/env bash
# Structural contract: tracked doctor repairs route through artifact-free Execute.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path
root=Path(sys.argv[1])
doctor=re.sub(r"\s+"," ",(root/"skills/woostack-doctor/SKILL.md").read_text())
execute=re.sub(r"\s+"," ",(root/"skills/woostack-execute/SKILL.md").read_text())
checks=[
 (doctor,r"routes approved tracked repairs through.*woostack-execute","tracked repair routing"),
 (doctor,r"before invoking any `--fix` path","pre-mutation routing"),
 (doctor,r"complete bounded task","bounded task contract"),
 (doctor,r"never hands tracked repairs directly to `woostack-commit`","commit boundary"),
 (doctor,r"filesystem-only.*orphan-worktree --fix","filesystem-only repair"),
 (doctor,r"Approved tracked repairs run through artifact-free `woostack-execute`","artifact-free repair"),
 (execute,r"no provider configuration or project membership is required","execute artifact default"),
]
failures=[msg for text,pat,msg in checks if not re.search(pat,text,re.I|re.S)]
if re.search(r"binds or creates.*issue|Linear is the only development authority",doctor,re.I|re.S):
 failures.append("doctor retains mandatory issue authority")
if failures:
 print("doctor repair contract violations:",file=sys.stderr)
 print("\n".join(f"- {f}" for f in failures),file=sys.stderr)
 raise SystemExit(1)
print("doctor artifact-free repair handoff: ok")
PY
