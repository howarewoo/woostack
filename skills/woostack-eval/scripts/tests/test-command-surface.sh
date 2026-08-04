#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

surfaces=(
  AGENTS.md
  README.md
  CONTRIBUTING.md
  skills/using-woostack/SKILL.md
  skills/woostack-bootstrap/references/development.md
  skills/using-woostack/references/hosts/omp.md
  skills/using-woostack/references/hosts/opencode.md
  skills/using-woostack/references/hosts/claude-code.md
  skills/using-woostack/references/hosts/codex.md
  skills/using-woostack/references/hosts/cursor.md
  skills/using-woostack/references/hosts/antigravity.md
  site/content/docs/concepts/index.mdx
  site/content/docs/concepts/utilities.mdx
  site/scripts/gen-skills.mjs
  site/scripts/gen-skills.test.mjs
  skills/using-woostack/tests/test-artifact-reader-contract.sh
  skills/woostack-change/scripts/tests/test-command-surface.sh
  skills/woostack-eval/scripts/tests/test-command-surface.sh
)

for surface in "${surfaces[@]}"; do
  [ -r "$ROOT/$surface" ] || {
    printf 'missing or unreadable command surface: %s\n' "$surface" >&2
    exit 1
  }
  cat "$ROOT/$surface" >/dev/null
done

python3 - "$ROOT" <<'PY'
import re
import subprocess
import sys
from pathlib import Path

root = Path(sys.argv[1])

def read(path: str) -> str:
    return (root / path).read_text(encoding="utf-8")

def require(condition: bool, message: str) -> None:
    if not condition:
        raise SystemExit(message)

public = [
    "using-woostack",
    "woostack-init",
    "woostack-bootstrap",
    "woostack-build",
    "woostack-fix",
    "woostack-change",
    "woostack-plan",
    "woostack-execute",
    "woostack-execute-overnight",
    "woostack-commit",
    "woostack-review",
    "woostack-address-comments",
    "woostack-status",
    "woostack-visualize",
    "woostack-debug",
    "woostack-tdd",
    "woostack-doctor",
    "woostack-sweep",
    "woostack-qa",
    "woostack-audit",
    "woostack-eval",
    "woostack-reflect",
]
internal = ["woostack-harden", "woostack-ideate"]
fixed = public + internal
require(len(public) == 22 and len(fixed) == 24 and len(set(fixed)) == 24, "invalid expected command counts")

agents = read("AGENTS.md")
agent_section = re.search(
    r"The public command/adoption surface has twenty-two skills:\s*(.*?)\nThe collection also installs",
    agents,
    re.S,
)
require(agent_section is not None, "AGENTS.md does not declare the 22-skill public surface")
agent_public = re.findall(r"^- \[`([^`]+)`\]\(skills/[^)]+/SKILL\.md\)$", agent_section.group(1), re.M)
require(agent_public == public, f"AGENTS.md public order mismatch: {agent_public!r}")
require("This collection still has twenty-two public command/adoption skills at twenty-four fixed" in agents, "AGENTS.md missing 22-public/24-fixed invariant")
require("twenty-four `SKILL.md` files (the twenty-two public command/adoption" in agents, "AGENTS.md fixed-path constraint is stale")
require(agents.count("[`woostack-eval`](skills/woostack-eval/SKILL.md)") == 1, "AGENTS.md public list must register woostack-eval once")
require(agents.count("[`woostack-reflect`](skills/woostack-reflect/SKILL.md)") == 1, "AGENTS.md public list must register woostack-reflect once")
require("[`skills/woostack-eval/SKILL.md`](skills/woostack-eval/SKILL.md)" in agents, "AGENTS.md quick map must register woostack-eval once")
require("[`skills/woostack-reflect/SKILL.md`](skills/woostack-reflect/SKILL.md)" in agents, "AGENTS.md quick map must register woostack-reflect once")
require(agents.count("`/woostack-eval`") == 1, "AGENTS.md must route Mode B to woostack-eval exactly once")
require(agents.count("`/woostack-reflect`") == 1, "AGENTS.md must route Mode B to woostack-reflect exactly once")

actual_fixed = sorted(path.parent.name for path in (root / "skills").glob("*/SKILL.md"))
require(actual_fixed == sorted(fixed), f"fixed SKILL.md surface mismatch: {actual_fixed!r}")

routing = read("skills/using-woostack/SKILL.md")
routes = re.findall(r"^\| `/([^`\s]+)", routing, re.M)
expected_routes = [
    "woostack-init",
    "woostack-bootstrap",
    "woostack-build",
    "woostack-fix",
    "woostack-change",
    "woostack-plan",
    "woostack-execute",
    "woostack-execute-overnight",
    "woostack-sweep",
    "woostack-commit",
    "woostack-review",
    "woostack-audit",
    "woostack-qa",
    "woostack-eval",
    "woostack-reflect",
    "woostack-address-comments",
    "woostack-status",
    "woostack-visualize",
    "woostack-debug",
    "woostack-tdd",
    "woostack-doctor",
]
require(routes == expected_routes, f"routing order mismatch: {routes!r}")
require(len(re.findall(r"^\| `/woostack-eval\s", routing, re.M)) == 1, "woostack-eval must have exactly one routing row")
require(len(re.findall(r"^\| `/woostack-reflect(?:\s|`)", routing, re.M)) == 1, "woostack-reflect must have exactly one routing row")
require(not set(internal) & set(routes), "internal sub-skills must remain unregistered")

generator = read("site/scripts/gen-skills.mjs")
def array(name: str) -> list[str]:
    match = re.search(rf"export const {name} = \[(.*?)\];", generator, re.S)
    require(match is not None, f"missing {name}")
    return re.findall(r"'([^']+)'", match.group(1))
require(array("PUBLIC_ORDER") == public, "PUBLIC_ORDER is not the exact 22-command order")
require(array("INTERNAL_ORDER") == internal, "internal skill order changed")
tracked_eval_page = subprocess.run(
    ["git", "-C", str(root), "ls-files", "--error-unmatch", "--", "site/content/docs/skills/woostack-eval.mdx"],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    check=False,
).returncode == 0
require(not tracked_eval_page, "generated woostack-eval page must not be committed")
tracked_reflect_page = subprocess.run(
    ["git", "-C", str(root), "ls-files", "--error-unmatch", "--", "site/content/docs/skills/woostack-reflect.mdx"],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    check=False,
).returncode == 0
require(not tracked_reflect_page, "generated woostack-reflect page must not be committed")

readme = read("README.md")
folded_readme = re.sub(r"\s+", " ", readme)
contributing = read("CONTRIBUTING.md")
development = read("skills/woostack-bootstrap/references/development.md")
concepts = read("site/content/docs/concepts/index.mdx")
utilities = read("site/content/docs/concepts/utilities.mdx")
require("twenty-two public command/adoption skills and two bundled internal skills at twenty-four fixed" in folded_readme, "README count is stale")
require("[/woostack-eval](skills/woostack-eval/SKILL.md)" in readme, "README catalog omits woostack-eval")
require("[/woostack-reflect](skills/woostack-reflect/SKILL.md)" in readme, "README catalog omits woostack-reflect")
require("| Change skill evaluation (`/woostack-eval`) |" in contributing, "CONTRIBUTING map omits woostack-eval")
require("| Change session reflection (`/woostack-reflect`) |" in contributing, "CONTRIBUTING map omits woostack-reflect")
require("twenty-two public command/adoption skills and all twenty-four fixed" in contributing, "CONTRIBUTING count is stale")
require("| Evaluate approved behavior and trigger corpora for a skill without editing it | `woostack-eval` |" in development, "bootstrap adoption map omits woostack-eval")
require("| Reflect on the fixed active-conversation snapshot for concrete durable instruction suggestions | `woostack-reflect` |" in development, "bootstrap adoption map omits woostack-reflect")
require('href="/docs/concepts/utilities"' in concepts, "authored concept overview omits the utilities surface")
require("[woostack-eval](/docs/skills/woostack-eval)" in utilities, "utilities page omits woostack-eval")
require("[woostack-reflect](/docs/skills/woostack-reflect)" in utilities, "utilities page omits woostack-reflect")

folded_utilities = re.sub(r"\s+", " ", utilities)
require(re.search(r"tracked corpus files only after explicit approval", folded_utilities, re.I) is not None, "utilities page must gate tracked corpus writes on approval")
require(re.search(r"evidence and reports are transient", folded_utilities, re.I) is not None, "utilities page must call eval reports transient")
require(re.search(r"never edits the target skill", folded_utilities, re.I) is not None, "utilities page must forbid target skill edits")

adoption = "\n".join((agents, readme, contributing, routing, development, concepts, utilities))
stale = re.compile(
    r"twenty-one\s+(?:public(?:\s+command/adoption)?\s+skills|fixed\s+`SKILL\.md`)|"
    r"twenty-one\s+public|21\s+public|"
    r"twenty-three\s+(?:public(?:\s+command/adoption)?\s+skills|fixed\s+`SKILL\.md`)|"
    r"twenty-three\s+public|23\s+public|"
    r"twenty-six\s+(?:fixed\s+)?`SKILL\.md`|26\s+fixed",
)
require(stale.search(adoption) is None, "stale public/fixed adoption count remains")

host_requirements = {
    "omp": (
        r"candidate and baseline's common effective tier",
        r"same managed worker",
        r"same `tasks\[\]` call",
        r"role pin, not proof of a concrete model",
        r"completion identity",
        r"identical model and effort",
        r"host fallback divergence, or model/effort divergence fails the mechanics proof",
        r"unable to start both siblings.*fails comparative preflight",
    ),
    "opencode": (
        r"isolated `@subagent` workers in the same parallel dispatch",
        r"pin the same concrete model on both calls",
        r"`session-default`.*same session model",
        r"true parallel subagents support comparative concurrency",
        r"`n=1` or queue-only build cannot",
    ),
    "claude-code": (
        r"isolated `general-purpose` workers.*same `task` dispatch turn",
        r"same concrete `model`.*exposed effort.*both calls",
        r"`session-default`.*both calls omit `model`.*same session identity",
        r"one-turn sibling `task` dispatch supports comparative concurrency",
        r"task mode that serializes the pair cannot",
    ),
    "codex": (
        r"local codex.*two isolated workers",
        r"same concrete `model` plus `reasoning_effort` on both calls",
        r"`session-default`.*both calls omit overrides.*same session identity",
        r"local concurrent dispatch can satisfy comparative mode",
        r"single-session codex action cannot",
    ),
    "cursor": (
        r"composer's parallel-subagent primitive",
        r"no concrete per-call model pin",
        r"`session-default`.*same session model identity",
        r"composer parallel subagents support comparative concurrency",
        r"queue-only runtime cannot",
    ),
    "antigravity": (
        r"isolated-context workers.*same dynamic orchestration turn",
        r"no concrete per-call model pin",
        r"`session-default`.*same identified session model",
        r"parallel dynamic subagents can satisfy comparative concurrency",
        r"host mode that serializes the pair cannot",
    ),
}
for host, requirements in host_requirements.items():
    text = read(f"skills/using-woostack/references/hosts/{host}.md")
    matches = re.findall(r"^- \*\*woostack-eval.*?(?=\n- \*\*|\n## |\Z)", text, re.M | re.S)
    require(len(matches) == 1, f"{host}: expected one woostack-eval mechanics note")
    note = re.sub(r"\s+", " ", matches[0]).lower()
    for pattern in requirements:
        require(re.search(pattern, note) is not None, f"{host}: eval mechanics mismatch: {pattern}")
    require(not re.search(r"\b(?:corpus approval|aggregate|render-report|receipt schema|target hash)\b", note), f"{host}: evaluator law leaked into mechanics note")

print("woostack-eval command surface: PASS")
PY
