#!/usr/bin/env bash
# Structural contract: canonical fix/build records, safe init defaults, optional artifacts elsewhere.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"

python3 - "$ROOT" <<'PY'
import json
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
    (r"canonical persistent store for `woostack-build` and project-backed `woostack-fix` is `\.woostack/tmp/runs/<run-id>/`", "canonical fix/build local authority missing"),
    (r"Do not create (?:synthetic )?parent plan resource", "retired build wrapper is not forbidden"),
    (r"artifacts\.provider.*gates every provider call", "artifacts.provider gating missing"),
    (r"zero provider reads or writes", "zero provider reads or writes when gating disabled missing"),
    (r"Merge authority remains human-only and outside every woostack workflow", "merge authority boundary missing"),
    (r"prefer provider-native operation identities|stable mutation identities", "stable mutation identities missing"),
    (r"stable external-mutation identity", "external mutation identity missing"),
    (r"separate canonical caller-facing, readable, native, and external identities", "provider identity boundary missing"),
    (r"stableTaskMappings.*maps each stable task key to.*one canonical (?:direct|increment)-resource reference", "stable task mapping definition missing"),
    (r"parentId.*Normalize an explicitly returned null parent to `null`|parent state is unknown and blocks", "nullable-parent validation missing"),
    (r"no-follow semantics", "no-follow semantics missing"),
    (r"directory mode is exactly `0700`", "directory 0700 mode missing"),
    (r"owner-only `0600`", "regular file 0600 mode missing"),
    (r"Write `project-spec\.md` exactly once", "plain project spec single write missing"),
    (r"Write `execution-plan\.md` exactly once", "plain execution plan single write missing"),
    (r"Never patch, replace, regenerate, or rewrite either final artifact", "immutable artifact write invariant missing"),
    (r"atomically rename it to the final path", "atomic rename update missing"),
    (r"compare-and-swap", "compare-and-swap update missing"),
    (r"taskExecutions\[stableTaskKey\]", "task executions checkpoints missing"),
    (r"Planning base and Execute choice", "planning base and Execute choice missing"),
    (r"If the current tip equals the planning tip, continue without a question", "matching planning tip rule missing"),
    (r"If the same branch has a different tip, make zero mutations", "different base tip mutation rule missing"),
    (r"`Continue`.*`Revise spec/plan`.*`Stop`", "Execute base choice options missing"),
    (r"independently read back", "independent read-back missing"),
    (r"full project fields.*complete membership set.*complete dependency graph", "mirror sync read-back fields missing"),
    (r"existing-description mutation invariant", "existing-description mutation invariant missing"),
    (r"Never replace an existing full description", "existing description replacement prohibition missing"),
    (r"Retain `manifest\.json`, `project-spec\.md`, `execution-plan\.md`, and `\.lock`", "retained run artifacts missing"),
):
    require("artifact-backends.md", contract, pattern, message)

linear_profile = flat(root / "skills/woostack-init/references/artifact-providers/linear.md")
for pattern, message in (
    (r"Woostack project mutation ID: <UUID>", "project mutation identity fallback marker missing"),
    (r"\[woostack-mutation:<UUID>\]", "issue mutation identity fallback suffix missing"),
    (r"stable human-facing identifier.*canonical issue reference", "canonical issue-reference definition missing"),
    (r"direct current issue must have null parent|parentless direct issue|parent = null|no parent plan issue", "Linear parentless direct issue contract missing"),
):
    require("linear.md", linear_profile, pattern, message)
for obsolete in (
    r"gate 1 displays only the",
    r"gate 2 displays only the",
    r"Do not paste any project",
    r"projectSpecApprovalRecord",
    r"executionPlanApprovalRecord",
    r"canonicalProjectSpecFingerprint",
    r"canonicalIncrementFingerprint",
    r"providerPresentationCanonicalization",
    r"\bstream(?:ed|ing)?.*(?:full|complete).*(?:bytes|content)",
):
    if re.search(obsolete, contract, re.I):
        failures.append(f"artifact-backends.md: obsolete term remains: {obsolete}")

build = flat(root / "skills/woostack-build/SKILL.md")
for pattern, message in (
    (r"resolves the exact.*supplied.*project or creates exactly one.*project|\[Build\] ", "build project admission missing"),
    (r"writes plain Markdown `project-spec\.md` and `execution-plan\.md`", "plain spec and plan build contract missing"),
    (r"candidate strict sequential direct-issue chain", "direct increment shape missing"),
):
    require("woostack-build", build, pattern, message)

fix = flat(root / "skills/woostack-fix/SKILL.md")
for pattern, message in (
    (r"Before root-cause proof, Fix makes no provider call", "pre-proof provider boundary missing"),
    (r"omitted, Fix creates exactly one project after root-cause proof", "plain-input project creation missing"),
    (r"writes plain Markdown `project-spec\.md` and `execution-plan\.md`", "shared Fix plain artifacts missing"),
):
    require("woostack-fix", fix, pattern, message)
if re.search(r"fixApprovalRecord|approve-to-execute|bind exactly one issue|projectSpecApprovalRecord|executionPlanApprovalRecord", fix, re.I):
    failures.append("woostack-fix: retired approval contract remains")

plan = flat(root / "skills/woostack-plan/SKILL.md")
require("woostack-plan", plan, r"Linear.*`--project` is mandatory|`--project` is mandatory", "exact-project selection boundary missing")
require("woostack-plan", plan, r"exactly one direct project issue (?:(?:\(for Linear\)|\bfor Linear\b) )?or child increment work item.*for each execution increment|exactly one direct project issue.*for each execution increment", "direct-issue persistence missing")
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
