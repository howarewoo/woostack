#!/usr/bin/env bash
# Structural contract for the isolated one-issue coding worker.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path
text = re.sub(r"\s+", " ", (Path(sys.argv[1]) / "skills/woostack-execute/references/subagent-driver.md").read_text())
checks = {
    "fast model": r"configured fast-model subagent",
    "one issue": r"exact project or issue identity and mode",
    "plain artifacts": r"project-spec\.md.*execution-plan\.md",
    "fresh isolation": r"fresh process/session",
    "one worktree": r"exactly one worktree and branch",
    "complete packet": r"stable run/issue identity.*allowed paths",
    "untrusted inputs": r"repository files.*untrusted data",
    "focused checks": r"focused verification and changed-path smoke",
    "no self acceptance": r"reviews,? accepts",
    "no commit": r"never commits, pushes, submits a PR",
    "unknown timeout": r"timeout or lost response is `UNKNOWN`",
    "no duplicate writer": r"Never share a worktree",
    "bounded validator": r"bounded spec-compliance validator",
}
failures = [name for name, pattern in checks.items() if not re.search(pattern, text, re.I | re.S)]
if failures:
    print("subagent driver contract violations:", file=sys.stderr)
    print("\n".join(f"- {failure}" for failure in failures), file=sys.stderr)
    raise SystemExit(1)
if "inline-driver.md" in text:
    raise SystemExit("removed inline driver is still referenced")
print("isolated fast-model issue contract: ok")
PY
