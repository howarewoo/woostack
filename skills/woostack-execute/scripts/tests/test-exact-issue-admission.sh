#!/usr/bin/env bash
# Structural contract: one exact resource, two matching approval records, sequential delivery.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
if [ -e "$ROOT/skills/woostack-execute/references/inline-driver.md" ]; then
    echo "removed inline driver still exists" >&2
    exit 1
fi
python3 - "$ROOT" <<'PY'
import re, sys
from pathlib import Path
root = Path(sys.argv[1])
skill = re.sub(r"\s+", " ", (root / "skills/woostack-execute/SKILL.md").read_text())
controller = re.sub(r"\s+", " ", (root / "skills/woostack-execute/references/controller.md").read_text())
artifact = re.sub(r"\s+", " ", (root / "skills/woostack-init/references/artifact-backends.md").read_text())
driver = re.sub(r"\s+", " ", (root / "skills/woostack-execute/references/subagent-driver.md").read_text())
checks = [
    (skill, r"Exactly one of `--project` or `--issue` is required", "exact resource admission missing"),
    (skill, r"projectSpecApprovalRecord.*executionPlanApprovalRecord", "matching approval records missing"),
    (skill, r"canonicalProjectSpecFingerprint.*increments.*dependencies", "shared approval record fields missing"),
    (skill, r"lowest-ordinal unfinished issue", "lowest unfinished ordinal selection missing"),
    (skill, r"stop marker", "stop-marker behavior missing"),
    (skill, r"issue mode.*never advances siblings", "issue mode may advance siblings"),
    (skill, r"configured fast-model subagent", "fast-model dispatch missing"),
    (skill, r"one focused verification.*one small bounded spec-compliance validator", "narrow verification boundary missing"),
    (skill, r"Backlog` or `Todo` → `In Progress` → `In Review`", "Linear lifecycle missing"),
    (skill, r"branch, commit, PR URL/head/base.*verification receipt", "successful delivery evidence missing"),
    (skill, r"woostack-commit.*exact selected issue.*`Resolves <issue identifier>`", "selected issue closing reference missing"),
    (skill, r"clean exact worktree", "clean-worktree gate missing"),
    (skill, r"never create a duplicate", "duplicate resume protection missing"),
    (controller, r"--project` xor `--issue", "controller exact resource admission missing"),
    (controller, r"canonicalProjectSpecFingerprint.*increments.*dependencies", "controller shared approval fields missing"),
    (controller, r"incomplete pagination.*blocks before", "controller evidence gate missing"),
    (controller, r"select lowest unfinished ordinal", "controller deterministic selection missing"),
    (controller, r"immediate predecessor's exact branch", "predecessor proof missing"),
    (controller, r"one worktree", "controller worktree ownership missing"),
    (controller, r"fast-model subagent", "controller fast dispatch missing"),
    (controller, r"bounded spec-compliance validator", "controller validator missing"),
    (controller, r"Backlog`/`Todo` → `In Progress` → `In Review", "controller lifecycle missing"),
    (controller, r"Successful submission requires branch, commit, PR", "controller PR gate missing"),
    (controller, r"woostack-commit.*exact selected issue", "controller does not pass the exact issue to commit"),
    (controller, r"exactly one closing reference for the selected issue", "controller closing-reference read-back missing"),
    (controller, r"fresh independent Linear, Git, Graphite, and GitHub evidence", "resume evidence missing"),
    (skill, r"\[Controller-owned screenshot evidence\]\(references/controller\.md#controller-owned-screenshot-evidence\)", "skill screenshot controller cross-link missing"),
    (controller, r"Immediately after successful focused UI validation and image inspection.*when validation produced screenshots and before commit.*exactly one final representative safe screenshot", "controller screenshot trigger/selection missing"),
    (controller, r"refuses any screenshot visibly containing secrets, credentials, or personal data.*warn.*continue repository delivery.*never claim it was posted", "controller sensitive-data refusal missing"),
    (controller, r"supported attachment flow.*exact admitted Linear issue.*post one inline comment that renders the image beneath a short scenario/state caption", "controller issue attachment/comment missing"),
    (controller, r"fresh independent comment/image read-back.*exact comment contains.*both caption and image", "controller caption/image read-back missing"),
    (controller, r"upload, comment, or read-back failure.*best-effort Linear evidence failure.*warn.*continue repository delivery.*never claim success", "controller best-effort continuation missing"),
    (controller, r"Controller-owned screenshot evidence", "controller screenshot ownership missing"),
    (controller, r"Never post a screenshot to a GitHub PR or external hosting", "controller GitHub/external screenshot prohibition missing"),
    (controller, r"non-authoritative.*mandatory Linear lifecycle.*Git/Graphite/GitHub evidence", "controller screenshot evidence authority boundary missing"),
    (skill, r"active Execute project-start synchronization", "execute project-status contract cross-link missing"),
    (skill, r"both `--project` and `--issue` modes", "both execute modes missing project-status gate"),
    (skill, r"`Backlog`/`Todo`.*`In Progress`.*project", "unstarted plus in-progress lifecycle outcome missing"),
    (skill, r"`Backlog`/`Todo`.*`In Review`.*project", "unstarted plus in-review lifecycle outcome missing"),
    (skill, r"exact started match is idempotent", "exact started no-op outcome missing"),
    (skill, r"all direct issues.*`Backlog`/`Todo`.*`In Progress` transition.*synchroniz", "all-unstarted transition/sync outcome missing"),
    (controller, r"Completed or canceled projects", "terminal project conflict outcome missing"),
    (controller, r"failed/unknown mutation or read-back", "failed or unknown project mutation outcome missing"),
    (artifact, r"complete, paginated direct-issue set", "artifact direct-issue pagination contract missing"),
    (artifact, r"exactly one native project status.*native category.*`started`", "native started status resolution missing"),
    (artifact, r"Immediately before a needed project mutation, re-read the exact project.*stable mutation identity", "project mutation pre-read/identity missing"),
    (artifact, r"exact existing started status.*idempotent no-op", "artifact idempotency contract missing"),
    (artifact, r"completed or canceled project.*terminal conflict.*blocks", "artifact terminal blocking contract missing"),
    (artifact, r"update only the project's native status field", "one-field project mutation contract missing"),
    (artifact, r"Independently read back the exact project.*stable mutation identity", "project mutation read-back missing"),
    (driver, r"configured fast-model subagent", "driver fast model missing"),
]
for text, pattern, message in checks:
    if not re.search(pattern, text, re.I | re.S):
        raise SystemExit(f"{message}: {pattern}")
if re.search(r"canonicalProjectFingerprint|directIssueSet|dependencyTupleSet|fixApprovalRecord", skill + controller, re.I):
    raise SystemExit("retired approval record fields remain")
if "inline-driver.md" in skill.lower() + controller.lower() + driver.lower():
    raise SystemExit("removed inline driver is still referenced")
print("sequential exact-resource execution admission: ok")
PY
