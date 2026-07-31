#!/usr/bin/env bash
# Structural contract for repository-first commit delivery and optional attribution.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path
root=Path(sys.argv[1])
skill=(root/"skills/woostack-commit/SKILL.md").read_text()
refs={name:(root/"skills/woostack-commit/references"/name).read_text() for name in ("graphite.md","pr-body.md","linear-attribution.md")}
text=re.sub(r"\s+"," ",skill)
corpus=re.sub(r"\s+"," ",skill+"\n"+"\n".join(refs.values()))
checks={
 "artifact-free command":r"/woostack-commit \[<message>\]",
 "optional issue flag":r"--issue <exact Linear issue URL[|]UUID>",
 "no issue prerequisite":r"Linear is optional: no issue, project",
 "bounded input":r"approved bounded task contract.*direct repository evidence",
 "no inferred scope":r"Do not reconstruct scope from a branch name, commit message, PR, artifact, or prior session",
 "inspect":r"### 1\. Inspect repository state",
 "verify":r"### 2\. Verify before staging",
 "stage narrow":r"### 3\. Stage only task-relevant changes",
 "Graphite commit":r"### 4\. Create or update the Graphite commit",
 "Graphite submit":r"### 5\. Submit with Graphite",
 "PR body":r"### 6\. Update PR title and body",
 "optional sync":r"### 7\. Synchronize an optional artifact",
 "stale verification":r"If source changed after verification, return to the calling workflow",
 "explicit staging":r"Stage explicit paths or hunks.*whole bounded task and nothing else",
 "no force push":r"Do not force-push",
 "PR readback":r"independently read the canonical GitHub PR",
 "body fields":r"## Goal.*## Summary.*## Test plan.*### Automated.*### Manual",
 "artifact narrow":r"Never change assignment, ownership, lifecycle, acceptance, scope, or project membership",
 "unknown outcome":r"Never replay a commit, submit, PR update, or artifact write",
}
failures=[name for name,pat in checks.items() if not re.search(pat,text,re.I|re.S)]
for name in refs:
 if f"references/{name}" not in skill: failures.append(f"missing dispatch {name}")
reference_checks={
 "Graphite authority":r"Linear is not required.*never selects the branch, worktree, parent, commit, PR, or submission authority",
 "artifact-free PR":r"Artifact-free PRs have no Linear trailer requirement",
 "ordinary link":r"one ordinary canonical link",
 "body preservation":r"Preserve repository-required templates.*human-authored context",
 "body validation":r"Before the edit verify the canonical repository.*current head branch/SHA.*After editing, independently read title, full body",
 "artifact readback":r"independently read the mutation back",
}
for name,pat in reference_checks.items():
 if not re.search(pat,corpus,re.I|re.S): failures.append(name)
if failures:
 print("commit package contract violations:",file=sys.stderr)
 print("\n".join(f"- {f}" for f in failures),file=sys.stderr)
 raise SystemExit(1)
print("repository-first commit package: ok")
PY
