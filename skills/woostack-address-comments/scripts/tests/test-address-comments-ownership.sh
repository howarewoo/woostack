#!/usr/bin/env bash
# Structural contract for repository-first comment addressing.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path
root=Path(sys.argv[1])
skill=re.sub(r"\s+"," ",(root/"skills/woostack-address-comments/SKILL.md").read_text())
prompt=re.sub(r"\s+"," ",(root/"skills/woostack-address-comments/prompts/address.md").read_text())
checks=[
 (skill,r"No issue, assignment, owner, lifecycle receipt, or trailer is required","artifact-free boundary"),
 (skill,r"GitHub owns PR identity, head, threads, replies, and resolution state","GitHub authority"),
 (skill,r"Never select by title, recent activity, or first search result","exact PR selection"),
 (skill,r"Missing or conflicting artifact access blocks only artifact-dependent","artifact degradation"),
 (skill,r"Commit and submit.*woostack-commit","commit boundary"),
 (skill,r"Unknown mutation outcome requires discovery before retry","idempotent recovery"),
 (prompt,r"Silence is not approval","interactive gate"),
 (prompt,r"A fix never requires an issue, project, trailer, assignment, lifecycle event, or artifact receipt","worker artifact-free path"),
 (prompt,r"re-read the canonical PR/head.*target thread","fresh side-effect preflight"),
]
failures=[msg for text,pat,msg in checks if not re.search(pat,text,re.I|re.S)]
for text,label in ((skill,"skill"),(prompt,"prompt")):
 if re.search(r"assignmentAccepted|Linear-Issue:|must.*exact issue.*before",text,re.I|re.S):
  failures.append(f"{label}: obsolete issue authority returned")
if failures:
 print("address-comments contract violations:",file=sys.stderr)
 print("\n".join(f"- {f}" for f in failures),file=sys.stderr)
 raise SystemExit(1)
print("repository-first address-comments contract: ok")
PY
