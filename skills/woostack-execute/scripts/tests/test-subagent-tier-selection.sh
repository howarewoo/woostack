#!/usr/bin/env bash
# Structural contract: worker routing is host-owned and never weakens isolation.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path
root=Path(sys.argv[1])
text=re.sub(r"\s+"," ",(root/"skills/woostack-execute/references/subagent-driver.md").read_text())
checks={
 "host routing": r"host's actual configured worker/profile routing",
 "no invented model": r"Do not invent model names",
 "fallback explicit": r"only an explicitly permitted fallback",
 "same coder": r"same coding profile handles implementation and any follow-up fixes",
 "separate review": r"Review uses a distinct decision-maker or explicitly configured independent reviewer",
 "profile credential": r"only the provider credential needed for its configured coding model",
 "no controller secrets": r"no controller, GitHub-write, Graphite-submit, Linear/MCP, browser, SSH",
}
failures=[name for name,pat in checks.items() if not re.search(pat,text,re.I|re.S)]
if failures:
 print("worker routing contract violations:",file=sys.stderr)
 print("\n".join(f"- {f}" for f in failures),file=sys.stderr)
 raise SystemExit(1)
print("host-owned worker routing contract: ok")
PY
