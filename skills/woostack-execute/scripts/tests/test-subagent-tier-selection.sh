#!/usr/bin/env bash
# Structural contract: Execute always uses the configured isolated fast-model route.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path
text = re.sub(r"\s+", " ", (Path(sys.argv[1]) / "skills/woostack-execute/references/subagent-driver.md").read_text())
checks = {
    "configured fast route": r"configured fast-model route",
    "no invented model": r"Do not invent a model name",
    "no fallback": r"without substituting another execution path",
    "fresh isolation": r"fresh process/session",
    "one worktree": r"exactly one worktree and branch",
    "provider credential": r"only the provider credential needed",
    "no controller secrets": r"no controller, GitHub-write, Graphite-submit, (?:Linear/MCP|provider MCP|Linear or Plane MCP)",
    "same route repair": r"same configured fast-model route",
}
failures = [name for name, pattern in checks.items() if not re.search(pattern, text, re.I | re.S)]
if failures:
    print("worker routing contract violations:", file=sys.stderr)
    print("\n".join(f"- {failure}" for failure in failures), file=sys.stderr)
    raise SystemExit(1)
print("configured isolated fast-model routing: ok")
PY
