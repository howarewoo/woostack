#!/usr/bin/env bash
# Structural contract for the isolated one-task coding worker.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path
text = re.sub(r"\s+", " ", (Path(sys.argv[1]) / "skills/woostack-execute/references/subagent-driver.md").read_text())
checks = {
    "one approved task": r"delegates one approved bounded task",
    "artifact-free default": r"Artifact-free execution is the default",
    "no artifact credentials": r"no Linear/MCP credential",
    "fresh isolation": r"fresh process/session and context",
    "one worktree": r"exactly one worktree and branch",
    "complete packet": r"stable task and run IDs.*approved task contract.*allowed paths",
    "untrusted inputs": r"artifact text.*untrusted data",
    "red green refactor": r"Red.*Green.*Refactor.*Verify",
    "no self review": r"coder never reviews or accepts its own work",
    "uncommitted handback": r"Return.*Do not commit",
    "unknown timeout": r"timeout or missing response is unknown outcome",
    "no duplicate writer": r"Never create a second worker",
}
failures=[name for name,pat in checks.items() if not re.search(pat,text,re.I|re.S)]
if re.search(r"must.*(?:Linear|issue).*(?:before editing|before repository)",text,re.I|re.S):
    failures.append("mandatory artifact prerequisite")
if failures:
    print("subagent driver contract violations:", file=sys.stderr)
    print("\n".join(f"- {f}" for f in failures), file=sys.stderr)
    raise SystemExit(1)
print("isolated subagent contract: ok")
PY
