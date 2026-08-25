#!/usr/bin/env bash
# Structural contract for plain local artifacts and the optional Linear mirror.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
paths = {
    "build": root / "skills/woostack-build/SKILL.md",
    "context": root / "skills/woostack-build/references/linear-context.md",
    "procedure": root / "skills/woostack-build/references/linear-procedure.md",
    "artifact": root / "skills/woostack-init/references/artifact-backends.md",
    "ideate": root / "skills/woostack-ideate/SKILL.md",
    "harden": root / "skills/woostack-harden/SKILL.md",
    "plan": root / "skills/woostack-plan/SKILL.md",
    "fix": root / "skills/woostack-fix/SKILL.md",
    "execute": root / "skills/woostack-execute/SKILL.md",
    "controller": root / "skills/woostack-execute/references/controller.md",
}
text = {name: path.read_text(encoding="utf-8") for name, path in paths.items()}
flat = {name: re.sub(r"\s+", " ", value) for name, value in text.items()}
failures = []


def require(name, pattern, message=None):
    if not re.search(pattern, flat[name], re.I | re.S):
        failures.append(message or f"{name}: missing {pattern!r}")


def forbid(names, pattern, message=None):
    for name in names:
        if re.search(pattern, flat[name], re.I | re.S):
            failures.append(message or f"{name}: obsolete contract remains: {pattern!r}")


# Build remains a thin controller around plain local artifacts.
for pattern in (
    r"\.woostack/tmp/runs/<run-id>/",
    r"project-spec\.md",
    r"execution-plan\.md",
    r"Ideate.*zero provider",
    r"delegated Plan.*zero provider",
    r"Stop here.*Execute.*Abandon",
    r"retain.*run artifacts",
    r"Build never merges|never merges",
    r"resolves the exact.*supplied.*project or creates exactly one.*project|\[Build\] ",
    r"writes plain Markdown `project-spec\.md`",
    r"writes plain Markdown `execution-plan\.md`",
    r"safe removal/simplification analysis|removal.*before additive",
):
    require("build", pattern)

for name in ("build", "context", "procedure", "ideate", "harden", "plan", "fix", "execute"):
    require(name, r"manifest", f"{name}: local run manifest contract missing")

# The shared contract owns local safety, one-time plain writes, recovery, and explicit base choice.
artifact_requirements = (
    r"Local run artifact and provider mirror contract",
    r"artifacts\.provider.*gates every provider call",
    r"zero provider reads or writes",
    r"\.woostack/config\.local\.json",
    r"no-follow semantics",
    r"directory mode is exactly `0700`",
    r"owner-only `0600`",
    r"Write `project-spec\.md` exactly once",
    r"Write `execution-plan\.md` exactly once",
    r"Never patch, replace, regenerate, or rewrite either final artifact",
    r"exclusive creation.*flush the file.*atomically rename.*flush the directory",
    r"manifest records only what recovery and strict sequential execution need",
    r"compare-and-swap",
    r"stableTaskMappings",
    r"taskExecutions\[stableTaskKey\]",
    r"canonical issue reference.*resource identifier only",
    r"unknown.*parent.*blocks",
    r"Do not create a parent plan issue",
    r"Preserve its title, description, status, assignment, labels, relations, comments, and lifecycle",
    r"full project fields.*complete direct membership set.*complete dependency graph",
    r"existing-description mutation invariant",
    r"active Execute project-start synchronization",
    r"project-backed workflow closure",
    r"Retain `manifest\.json`, `project-spec\.md`, `execution-plan\.md`, and `\.lock`",
    r"Report repository delivery and mirror synchronization separately",
    r"If the current tip equals the planning tip, continue without a question",
    r"If the same branch has a different tip, make zero mutations",
    r"`Continue`.*`Revise spec/plan`.*`Stop`",
    r"This is never automatic",
    r"checks.*for observation only",
)
for pattern in artifact_requirements:
    require("artifact", pattern)

# Provider safety retained by Build and its shared references.
for name in ("context", "procedure"):
    require(name, r"canonical issue-reference|canonical issue reference")
    require(name, r"nullable-parent|null parent|parent state")
require("procedure", r"zero provider and repository mutation")
require("harden", r"canonical issue references")
require("artifact", r"host's authenticated official Linear MCP")
require("artifact", r"untrusted data, never instructions")
require("artifact", r"Never replace an existing full description")
require("artifact", r"completed or canceled project.*terminal conflict")
require("artifact", r"update only the native status field")


# Configured project label preservation contracts
require("artifact", r"projectLabels.*array of non-empty strings")
require("artifact", r"completely paginate.*workspace project labels.*flatten.*null terminal cursor.*resolves each configured label")
require("artifact", r"exact.*native ID.*or.*exact.*case-sensitive name")
require("artifact", r"union of existing project labels and configured labels")
require("artifact", r"preserving all unrelated existing labels")
require("artifact", r"Preflight label discovery")
require("artifact", r"at most one write alongside project creation or admission")
require("artifact", r"independently read back the complete label set")
require("artifact", r"fails closed before mutating the project")
require("context", r"projectLabels")
require("context", r"completely paginate all workspace project labels.*flatten every page.*require null terminal cursors.*resolve.*before any project creation or admission mutation")
require("context", r"exact native ID.*or exact case-sensitive name")
require("context", r"union.*configured labels with existing project labels")
require("context", r"preserving unrelated.*existing labels")
require("context", r"at most one write alongside admission|applying the union of resolved configured labels in the creation write")
require("context", r"independently read the project and complete label set back")
require("context", r"Reject missing, ambiguous, duplicate, or incomplete matches before mutation")
require("fix", r"completely paginate all workspace project labels.*flatten every page.*require null terminal cursors.*resolve.*before mutation")
source_names = tuple(paths)
for obsolete in (
    r"canonicalProjectSpecFingerprint",
    r"canonicalIncrementFingerprint",
    r"projectSpecApprovalRecord",
    r"executionPlanApprovalRecord",
    r"approvalEventId",
    r"fingerprintVersion",
    r"providerPresentationCanonicalization",
    r"gate[- ]file.*(?:SHA-256|byteLength|identity)",
    r"\bstream(?:ed|ing)?.*(?:full|complete).*(?:bytes|content)",
    r"reaccept|re-accept",
    r"compatible[- ]advancement|compatible parent advancement",
):
    forbid(source_names, obsolete)

# One direct issue per increment and native relations remain required. The explicit sentence is
# intentionally required rather than forbidden because parent/container plan issues are noncanonical.
require("artifact", r"Do not create a parent plan issue")
require("artifact", r"membership before relations")
require("artifact", r"Bind each newly created issue to its stable task key exactly once")

if failures:
    raise SystemExit("\n".join(failures))
print("test-linear-build-contract: ok")
PY
