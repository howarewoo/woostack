#!/usr/bin/env bash
# Structural contract: canonical fix/build records, safe init defaults, optional artifacts elsewhere.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"

python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
failures = []

def flat(path):
    return re.sub(r"\s+", " ", path.read_text(encoding="utf-8"))

def require(label, text, pattern, message):
    if not re.search(pattern, text, re.I):
        failures.append(f"{label}: {message}")

flag_paths = list((root / "skills").glob("*/SKILL.md")) + [
    root / "AGENTS.md",
    root / "README.md",
]
for path in flag_paths:
    if re.search(r"(?<![\w-])--linear(?![\w-])", path.read_text(encoding="utf-8")):
        failures.append(f"{path.relative_to(root)}: obsolete --linear init flag remains")

init = flat(root / "skills/woostack-init/SKILL.md")
for pattern, message in (
    (r"Every run attempts automatic Linear setup", "default init does not attempt Linear setup"),
    (r"Authenticated read access is sufficient", "read-only authenticated setup is not sufficient"),
    (r"never selects artifact mode", "init setup can appear to select unrelated artifact use"),
    (r"continue ordinary local initialization", "Linear setup can appear to block local init"),
):
    require("woostack-init", init, pattern, message)

contract = flat(root / "skills/woostack-init/references/artifact-backends.md")
for pattern, message in (
    (r"canonical product records for `woostack-build` and project-backed `woostack-fix`", "canonical fix/build role missing"),
    (r"Each independently shippable increment is one direct issue in that project", "direct build issue shape missing"),
    (r"Do not create a parent plan issue", "retired build wrapper is not forbidden"),
    (r"not source-control or delivery authority", "source-control authority boundary missing"),
    (r"Run-scoped gated draft manifest", "gated manifest authority missing"),
    (r"host OS temporary-directory facility.*0700.*0600", "restricted OS-temp manifest missing"),
    (r"atomically renames it over the manifest", "atomic manifest update missing"),
    (r"zero Linear or other provider reads and writes", "provider-free gated drafting missing"),
    (r"complete exact local content to be saved, not a summary or pointer-only presentation", "complete displayed content missing"),
    (r"approval must occur before any draft content is saved", "approval-before-save ordering missing"),
    (r"immediately re-read the exact Linear targets", "immediate pre-save drift read missing"),
    (r"only after that exact content read-back, record", "read-back-before-receipt ordering missing"),
    (r"stable local task key to the one native issue ID", "native identity mapping missing"),
    (r"prior stable-key mappings.*explicit proposed native-issue.*task-key mapping", "retained issue reconciliation missing"),
    (r"optimistic revision/content-identity precondition.*immediate fresh read", "mid-cycle drift protection missing"),
    (r"unreceipted approval is consumed and cannot be replayed", "unreceipted approval replay guard missing"),
    (r"different/restarted process.*requires a fresh complete Ask", "process-loss invalidation missing"),
    (r"Remove the manifest and its run-scoped temporary directory", "manifest cleanup missing"),
    (r"local draft.*never replaces.*last Linear-approved boundary", "local authority boundary missing"),
    (r"Standalone `woostack-plan`.*unchanged", "standalone Plan distinction missing"),
    (r"Execute-era safety reads are unchanged", "Execute read preservation missing"),
    (r"projectSpecApprovalRecord", "project-spec approval record missing"),
    (r"executionPlanApprovalRecord", "execution-plan approval record missing"),
    (r"project-specification change invalidates both.*issue or dependency change invalidates only", "approval invalidation rules missing"),
    (r"exact caller-supplied resource always takes precedence over creation", "exact-resource precedence safeguard missing"),
    (r"official Linear MCP", "official-MCP-only transport safeguard missing"),
    (r"provisional event.*never clears any gate", "provisional receipt non-authority missing"),
    (r"preallocated.*mutation identities", "stable operation identity safeguard missing"),
    (r"independently read back", "independent read-back safeguard missing"),
):
    require("artifact-backends.md", contract, pattern, message)

for obsolete in (
    r"gate 1 displays only the",
    r"gate 2 displays only the",
    r"Do not paste any project",
):
    if re.search(obsolete, contract, re.I):
        failures.append(f"artifact-backends.md: obsolete approval presentation remains: {obsolete}")

build = flat(root / "skills/woostack-build/SKILL.md")
for pattern, message in (
    (r"always resolves the exact supplied project or creates exactly one project", "build project admission missing"),
    (r"exactly two content approvals", "two-approval build contract missing"),
    (r"candidate strict sequential direct-issue chain", "direct increment shape missing"),
):
    require("woostack-build", build, pattern, message)

fix = flat(root / "skills/woostack-fix/SKILL.md")
for pattern, message in (
    (r"Before root-cause proof, Fix makes no provider call", "pre-proof provider boundary missing"),
    (r"omitted, Fix creates exactly one project after root-cause proof", "plain-input project creation missing"),
    (r"exactly the two shared project-backed approval receipts", "shared Fix approvals missing"),
):
    require("woostack-fix", fix, pattern, message)
if re.search(r"fixApprovalRecord|approve-to-execute|bind exactly one issue", fix, re.I):
    failures.append("woostack-fix: retired one-issue approval contract remains")

plan = flat(root / "skills/woostack-plan/SKILL.md")
require("woostack-plan", plan, r"`--project` is mandatory", "exact-project selection boundary missing")
require("woostack-plan", plan, r"exactly one direct project issue for each execution increment", "direct-issue persistence missing")
require(
    "woostack-plan",
    plan,
    r"verification command.*repository-local script or path.*already exist.*predecessor increment.*same increment.*create",
    "planned verification existence check missing",
)

change = flat(root / "skills/woostack-change/SKILL.md")
require("woostack-change", change, r"(never reads or writes Linear|makes no Linear call)", "change is not Linear-free")

if failures:
    print("Linear authority contract violations:", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    raise SystemExit(1)

print("Linear authority contract: ok")
PY
