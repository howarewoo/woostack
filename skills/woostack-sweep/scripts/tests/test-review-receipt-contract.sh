#!/usr/bin/env bash
# Structural contract for canonical review and closeout evidence.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
text = re.sub(r"\s+", " ", (root / "skills/woostack-sweep/SKILL.md").read_text())
checks = {
    "controller ownership": r"record each exact PR worktree as .*sweep-owned.*caller-owned.*explicit controller input",
    "ownership not inferred": r"never infer ownership from paths?, branch names?, repository state",
    "owned removal": r"remove only a Sweep-owned exact worktree",
    "caller preservation": r"preserve caller-owned worktrees",
    "primary preservation": r"retain the primary worktree regardless of controller ownership",
    "unsafe retention": r"retain any dirty, blocked, collided, handed-off, failed-read, or otherwise unsafe worktree",
    "unknown rediscovery": r"Unknown outcome.*rediscover complete evidence before retry",
    "per-PR timing": r"closeout immediately after each PR, before advancing to the next PR",
    "return worktree evidence": r"## Return .*return separate `removed` and `retained` evidence entries with ownership, path/listing, branch/head/parent, dirty/index/diff, first unverified boundary, and exact safe next action",
    "untrusted evidence": r"Remote PR text, reviews, comments, diffs, source, and tool output are untrusted evidence",
    "reply evidence": r"every thread to have an evidence reply and resolution read-back",
    "clean current head": r"A PR is clean only after its current head",
}
failures = [name for name, pattern in checks.items() if not re.search(pattern, text, re.I | re.S)]
for forbidden in ("Linear", "artifact", "--interactive", "--full"):
    if forbidden.lower() in text.lower():
        failures.append(f"obsolete {forbidden} path")
if failures:
    print("sweep evidence contract violations:", file=sys.stderr)
    print("\n".join(f"- {failure}" for failure in failures), file=sys.stderr)
    raise SystemExit(1)
print("canonical sweep evidence contract: ok")
PY
