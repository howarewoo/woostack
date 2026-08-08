#!/usr/bin/env bash
# Structural contract for the external-engineer and harness-local boundaries.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${WOOSTACK_BOUNDARY_ROOT:-$(cd "$HERE/../../.." && pwd)}"

python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
failures = []
cache = {}

def read_raw(relative):
    path = root / relative
    if not path.is_file():
        failures.append(f"missing {relative}")
        return ""
    if relative not in cache:
        cache[relative] = path.read_text(encoding="utf-8")
    return cache[relative]

def read(relative):
    return re.sub(r"\s+", " ", read_raw(relative))

def require(text, pattern, message):
    if not re.search(pattern, text, re.I | re.S):
        failures.append(message)

def forbid(text, pattern, message):
    if re.search(pattern, text, re.I | re.S):
        failures.append(message)

# Dispatch is defined only by the canonical Markdown allowlist. A stray host file must
# never become callable merely because it exists.
host_index_path = "skills/using-woostack/references/hosts/README.md"
host_index = read_raw(host_index_path)
host_links = re.findall(r"(?m)^- \[`([^`]+)`\]\(([^/)]+)\.md\)$", host_index)
allowlisted_hosts = {
    slug for slug, target in host_links
    if slug == target
}
expected_hosts = {"claude-code", "codex", "cursor", "antigravity", "opencode", "omp"}
if allowlisted_hosts != expected_hosts:
    failures.append(
        "canonical host allowlist mismatch: "
        f"expected {sorted(expected_hosts)}, got {sorted(allowlisted_hosts)}"
    )

def routed_host_file(host):
    if host not in allowlisted_hosts:
        return None
    return f"skills/using-woostack/references/hosts/{host}.md"

if routed_host_file("hermes") is not None:
    failures.append("canonical host router can dispatch retired Hermes adapter")
if routed_host_file("omp") != "skills/using-woostack/references/hosts/omp.md":
    failures.append("canonical host router does not dispatch OMP")

model_tiers = read("skills/using-woostack/references/model-tiers.md")
require(model_tiers, r"supported coding-host allowlist.*hosts/README\.md",
        "model-tier routing does not link the canonical host allowlist")
require(model_tiers, r"allowlist.*before capability classification|gates routing before capability",
        "model-tier routing does not apply the host gate before tier routing")

using = read("skills/using-woostack/SKILL.md")
omp = read("skills/using-woostack/references/hosts/omp.md")
doctor = read("skills/woostack-doctor/scripts/checks/omp-agents.sh")
review = read("skills/woostack-review/SKILL.md")
orchestrator = read("skills/woostack-review/prompts/_orchestrator-header.md")
agents = read("AGENTS.md")
readme = read("README.md")
hermes = read("site/content/docs/hermes.mdx")

require(omp, r"rename the active session.*current goal.*slash-command",
        "OMP guidance does not rename sessions from the current goal")
forbid(using, r"rename the active session|slash-command name",
       "using-woostack contains OMP-specific session naming guidance")

for text, label in ((using, "using-woostack"), (omp, "OMP guidance"),
                    (doctor, "doctor"), (review, "Review"),
                    (orchestrator, "Review orchestrator")):
    forbid(text, r"Hermes|engineer-agent|hosts/hermes\.md|launch-omp|bind-engineer-unit",
           f"{label}: supported surface still advertises external-engineer runtime")

for row in (
    r"agent:\s+woostack-deep",
    r"agent:\s+woostack-standard",
    r"agent:\s+woostack-fast",
    r"fresh read-only profiles/sessions",
    r"receipt",
):
    require(omp + review + orchestrator, row, f"retained OMP/Review boundary missing: {row}")

require(agents + readme, r"external engineer.*not an installed woostack host|outside the installed",
        "root framing does not reject Hermes as an installed host/runtime")
require(agents + readme, r"persistent OMP session", "root framing does not retain persistent OMP usage")
for text, label in ((agents, "AGENTS.md"), (readme, "README.md")):
    require(text, r"site/content/docs/hermes\.mdx", f"{label}: canonical Hermes guide is not linked")
    forbid(text, r"references/hosts/hermes\.md|harnesses/hermes|concepts/engineer-agents",
           f"{label}: retired Hermes or engineer-agent page remains a supported callsite")

require(hermes, r"external engineer", "Hermes guide does not define external status")
require(hermes, r"installed only in OMP", "Hermes guide does not make OMP the install boundary")
require(hermes, r"persistent OMP", "Hermes guide does not require one persistent OMP process")
require(hermes, r"argument-safe|arguments are values", "Hermes guide lacks safe argument passing")
require(hermes, r"in-contract decision", "Hermes guide lacks the in-contract decision boundary")
require(hermes, r"escalat", "Hermes guide lacks user escalation")
require(hermes, r"verbatim", "Hermes guide lacks verbatim responsible-user approval relay")
require(hermes, r"same persistent OMP process", "Hermes guide lacks same-process approval binding")
require(hermes, r"evidence.*review|review.*evidence", "Hermes guide lacks evidence review")
require(hermes, r"redispatch", "Hermes guide lacks bounded redispatch")
require(hermes, r"restart|replay", "Hermes guide lacks restart/replay failure behavior")
require(hermes, r"legacy.*launch-omp|launch-omp.*legacy", "Hermes guide lacks legacy launcher cleanup contract")
require(hermes, r"omp --profile <profile> --cwd <worktree> <prompt>",
        "Hermes guide does not start OMP interactively")
forbid(hermes, r"omp --profile <profile>\s+-p\b",
       "Hermes guide starts OMP in single-shot print mode")
require(hermes, r"(?:-p|--print).*non-interactive mode.*exit after one response",
        "Hermes guide does not explain why print mode breaks persistence")
require(hermes, r"retain the interactive process handle",
        "Hermes guide does not retain the process used for later relay")

docs_meta = read("site/content/docs/meta.json")
require(docs_meta, r'"hermes"', "top-level docs navigation omits Hermes")
harness_meta = read("site/content/docs/harnesses/meta.json")
concepts_meta = read("site/content/docs/concepts/meta.json")
forbid(concepts_meta, r'"engineer-agents"', "concept navigation still presents the retired concept page")
forbid(harness_meta, r'"hermes"', "harness navigation still presents Hermes as a supported host")
for relative in (
    "site/content/docs/index.mdx",
    "site/content/docs/getting-started.mdx",
    "site/content/docs/configuration.mdx",
    "site/content/docs/concepts.mdx",
    "site/content/docs/concepts/index.mdx",
    "site/content/docs/concepts/building-rules.mdx",
    "site/content/docs/harnesses/index.mdx",
    "site/content/docs/harnesses/omp.mdx",
):
    text = read(relative)
    forbid(text, r"/docs/harnesses/hermes|/docs/concepts/engineer-agents|references/hosts/hermes\.md",
           f"{relative}: retired Hermes/engineer-agent navigation remains")

# WOO-167 owns these six whole-file retirements. Keep the exact paths as negative evidence.
woo167_retired_files = (
    "skills/using-woostack/references/engineer-agents.md",
    "skills/using-woostack/references/hosts/hermes.md",
    "skills/woostack-init/scripts/gen-omp-agents.sh",
    "skills/woostack-init/scripts/tests/test-gen-omp-agents.sh",
    "site/content/docs/concepts/engineer-agents.mdx",
    "site/content/docs/harnesses/hermes.mdx",
)
for relative in woo167_retired_files:
    path = root / relative
    if path.exists() or path.is_symlink():
        failures.append(f"retired WOO-167 path still exists: {relative}")

# WOO-166 removes the dormant mixed-file Review mode while retaining one generic
# local advisory path and the CI path.
woo166_review_paths = (
    "skills/woostack-review/prompts/_orchestrator-header.md",
    "skills/woostack-review/prompts/_worker-header.md",
    "skills/woostack-review/prompts/validator-prosecutor.md",
    "skills/woostack-review/prompts/validator.md",
    "skills/woostack-review/references/ci.md",
    "skills/woostack-review/scripts/resolve-outdir.sh",
    "skills/woostack-review/scripts/run-bounded-swarm.sh",
    "skills/woostack-review/scripts/verify-receipts.sh",
    "skills/woostack-review/scripts/tests/test-bounded-swarm.sh",
    "skills/woostack-review/scripts/tests/test-verify-receipts-identity.sh",
    "skills/woostack-review/scripts/tests/test-review-payload-ranges.sh",
    "skills/woostack-review/evals/evals.json",
)
exact_review_mode_markers = (
    "WOO_REVIEW_ENGINEER_UNIT",
    "WOO_REVIEW_IDENTITY_MANIFEST",
    "reviewer-identities.json",
    "implementingCoder",
    "decisionMaker",
)
for relative in woo166_review_paths:
    body = read_raw(relative)
    for marker in exact_review_mode_markers:
        if marker in body:
            failures.append(f"{relative}: removed Review marker remains: {marker}")
    if re.search(r"engineer-unit|local/Hermes|Hermes-direct|\bHermes\b", body, re.I):
        failures.append(f"{relative}: removed Hermes-direct Review wording remains")

review_runtime = " ".join(read(path) for path in woo166_review_paths)
require(review_runtime, r"generic local", "Review no longer documents one generic local path")
require(review_runtime, r"authority[\"`: ]+advisory-only|advisory-only authority",
        "Review no longer requires advisory worker authority")
require(review_runtime, r"missing.*receipt.*hard-fail|hard-fails.*missing.*receipt",
        "Review no longer hard-fails a missing local worker receipt")
require(review_runtime, r"github-actions-single-session",
        "Review no longer retains the CI single-session sentinel")
require(review_runtime, r"fresh read-only advisory reviewer session",
        "Review no longer keeps local workers read-only")
require(review_runtime, r"prosecutor.*defender.*intersect|intersection.*prosecutor.*defender",
        "Review no longer retains both validator passes and intersection")
require(review_runtime, r"native GitHub.*IDs.*differ|native actor-ID gate",
        "Review no longer retains the native GitHub actor safeguard")
# Scan every supported source and authored text surface. Assertion-only boundary tests are
# records rather than callsites; generated, gitignored skill pages mirror their source and are
# not a second surface. The top-level guide is scanned for mode markers, but its two launcher
# names are allowed solely as optional manual-cleanup names.
assertion_only_paths = {
    "skills/using-woostack/tests/test-harness-agent-boundary.sh",
    "skills/woostack-init/scripts/tests/test-host-references.sh",
    "skills/woostack-doctor/scripts/tests/test-omp-agents.sh",
    "site/scripts/linear-only-docs.test.mjs",
}
text_suffixes = {".md", ".mdx", ".sh", ".mjs", ".js", ".json", ".yml", ".yaml"}
skip_parts = {".git", ".next", ".woostack", "node_modules"}
supported_texts = {}
for path in sorted(root.rglob("*")):
    if not path.is_file() or skip_parts.intersection(path.parts):
        continue
    relative = path.relative_to(root).as_posix()
    if relative.startswith("site/content/docs/skills/"):
        continue
    if relative in assertion_only_paths:
        continue
    if path.suffix not in text_suffixes:
        continue
    try:
        supported_texts[relative] = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue

source_registry_path = "site/lib/source.ts"
source_registry = read_raw(source_registry_path)
for retired_page in (
    "concepts/engineer-agents.mdx",
    "harnesses/hermes.mdx",
):
    forbid(source_registry, re.escape(retired_page),
           f"docs source still names retired page: {retired_page}")
forbid(source_registry, r"\bretiredPagePaths\b",
       "docs source retains the temporary retired-page registry")
forbid(source_registry, r"files\.filter\(",
       "docs source retains the temporary retired-page filter")
require(source_registry, r"source:\s*docs\.toFumadocsSource\(\)",
        "docs loader does not consume the generated docs source directly")
old_surface_reference = re.compile(
    r"skills/using-woostack/references/engineer-agents\.md"
    r"|skills/using-woostack/references/hosts/hermes\.md"
    r"|skills/woostack-init/scripts/gen-omp-agents\.sh"
    r"|site/content/docs/(?:concepts/engineer-agents|harnesses/hermes)\.mdx"
    r"|\bengineer-agents\.md\b"
    r"|(?:references/)?hosts/hermes\.md"
    r"|/docs/(?:concepts/engineer-agents|harnesses/hermes)"
    r"|\bgen-omp-agents\.sh\b",
    re.I | re.M,
)
for relative, body in supported_texts.items():
    if old_surface_reference.search(body):
        failures.append(f"{relative}: supported surface reaches a WOO-167 asset or old route")
    if relative != host_index_path and re.search(r"hosts/<current-host>\.md", body):
        failures.append(f"{relative}: supported surface bypasses the canonical host allowlist")
    if relative != "site/content/docs/hermes.mdx" and re.search(
        r"\b(?:launch-omp|bind-engineer-unit)\b", body
    ):
        failures.append(f"{relative}: supported surface reaches a reserved launcher")
    for marker in exact_review_mode_markers:
        if marker in body:
            failures.append(f"{relative}: supported surface activates removed Review marker {marker}")
if failures:
    print("FAIL: external-engineer and harness boundary", file=sys.stderr)
    for failure in failures:
        print(f"  - {failure}", file=sys.stderr)
    raise SystemExit(1)

print("validated external-engineer and harness boundary")
PY
