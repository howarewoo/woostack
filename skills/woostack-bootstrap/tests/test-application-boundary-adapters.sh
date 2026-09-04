#!/usr/bin/env bash
# Structural and behavioral contract: application-boundary adapter rules and scenario matrix.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
fold = lambda text: re.sub(r"\s+", " ", text)
failures = []

def require(text, pattern, message):
    if not re.search(pattern, fold(text), re.I | re.S):
        failures.append(message)

# ==============================================================================
# 1. Canonical Pattern in skills/woostack-bootstrap/references/patterns.md
# ==============================================================================
patterns_path = root / "skills/woostack-bootstrap/references/patterns.md"
if not patterns_path.exists():
    failures.append(f"missing patterns.md at {patterns_path}")
    patterns_text = ""
else:
    patterns_text = patterns_path.read_text(encoding="utf-8")

# Exactly one canonical section heading in patterns.md
canonical_headings = re.findall(r"^##\s*3\.\s*Application-boundary adapters\s*$", patterns_text, re.M)
if len(canonical_headings) != 1:
    failures.append(f"patterns.md must have exactly 1 canonical '## 3. Application-boundary adapters' heading, found {len(canonical_headings)}")

# Numbered headings sequence in patterns.md
require(patterns_text, r"## 3\. Application-boundary adapters", "patterns.md missing ## 3. Application-boundary adapters")
require(patterns_text, r"## 4\. Test-Driven Development", "patterns.md missing renumbered ## 4. Test-Driven Development")
require(patterns_text, r"## 5\. API stability", "patterns.md missing renumbered ## 5. API stability")
require(patterns_text, r"## 6\. Type safety", "patterns.md missing renumbered ## 6. Type safety")
require(patterns_text, r"## 7\. Least code & comments", "patterns.md missing renumbered ## 7. Least code & comments")
require(patterns_text, r"## 8\. Dependency ownership", "patterns.md missing renumbered ## 8. Dependency ownership")

# Canonical clauses in patterns.md
require(patterns_text, r"HTTP/RPC server-client.*service-service.*webhooks.*queues/events.*third-party APIs", "patterns.md missing all named boundaries")
require(patterns_text, r"in both directions|receiving and sending boundaries", "patterns.md missing both directions scope")
require(patterns_text, r"Excludes database persistence mapping and ordinary in-process module calls", "patterns.md missing DB/in-process exclusions")
require(patterns_text, r"validate or narrow untrusted wire input", "patterns.md missing validation responsibility")
require(patterns_text, r"map wire or vendor representations to application/domain models and map domain models back to wire shapes", "patterns.md missing bidirectional wire/domain mapping")
require(patterns_text, r"translate transport-specific errors", "patterns.md missing transport error translation responsibility")
require(patterns_text, r"so transport, client, and vendor formats never leak into application or domain logic", "patterns.md missing domain isolation from transport/client/vendor types")
require(patterns_text, r"so business logic remains independent of transport, client, and vendor details", "patterns.md missing business logic transport independence")
require(patterns_text, r"Keep adapters in the application that owns the boundary, optionally in an application-local adapter location", "patterns.md missing application-local adapter placement")
require(patterns_text, r"Extract to the repository's shared-code location only when multiple applications consume the exact same contract", "patterns.md missing repository-native shared extraction rule")
require(patterns_text, r"Preserve existing wire and API contracts", "patterns.md missing wire/API compatibility requirement")
require(patterns_text, r"Preserve input validation, error handling, security, accessibility, and data-loss protections", "patterns.md missing named safety protections preservation")
require(patterns_text, r"Apply to new boundary flows and existing flows materially changed by a task", "patterns.md missing new/materially touched flow scope")
require(patterns_text, r"Do not migrate untouched legacy boundary flows", "patterns.md missing untouched legacy exclusion")
require(patterns_text, r"Functions or modules satisfy the pattern; classes are not required", "patterns.md missing functions/modules/no-class guidance")
require(patterns_text, r"Architecture review blocks concrete changed-code transport/client/vendor leaks or missing required boundary validation and error translation", "patterns.md missing review blocking criteria")
require(patterns_text, r"Review does not block folder/file naming, class-vs-function style, or the omission of identity/no-op wrappers", "patterns.md missing review style/naming/no-op non-blocking skip")

# ==============================================================================
# 2. Downstream Surfaces Link Resolution & Anti-Competition Checks
# ==============================================================================
CANONICAL_ANCHOR = "#3-application-boundary-adapters"
CANONICAL_SITE_URL = "https://github.com/howarewoo/woostack/blob/main/skills/woostack-bootstrap/references/patterns.md#3-application-boundary-adapters"

downstream_files = {
    "arch": root / "skills/woostack-bootstrap/references/architecture.md",
    "plan": root / "skills/woostack-plan/SKILL.md",
    "execute": root / "skills/woostack-execute/references/subagent-driver.md",
    "change": root / "skills/woostack-change/SKILL.md",
    "review": root / "skills/woostack-review/prompts/angles/architecture.md",
    "site": root / "site/content/docs/concepts/repository-rules.mdx",
}

surface_texts = {}
for name, path in downstream_files.items():
    if not path.exists():
        failures.append(f"missing downstream file {name} at {path}")
        surface_texts[name] = ""
    else:
        surface_texts[name] = path.read_text(encoding="utf-8")

# Verify downstream files do not define a competing canonical section heading
for name, text in surface_texts.items():
    if name == "site":
        if re.search(r"^##\s*3\.\s*Application-boundary adapters", text, re.M):
            failures.append(f"site page {downstream_files[name]} must not define a competing '## 3.' canonical heading")
    else:
        if re.search(r"^##\s*(?:3\.\s*)?Application-boundary adapters", text, re.M):
            failures.append(f"downstream file {downstream_files[name]} must not define a competing canonical adapter heading")

# Validate relative Markdown links resolve to patterns.md and anchor #3-application-boundary-adapters
for name in ("arch", "plan", "execute", "change", "review"):
    src_path = downstream_files[name]
    text = surface_texts[name]
    links = re.findall(r"\[([^\]]+)\]\(([^)]*patterns\.md[^)]*)\)", text)
    if not links:
        failures.append(f"{name} ({src_path}) missing link to patterns.md")
        continue
    has_canonical_anchor = False
    for label, target in links:
        if "#" in target:
            target_file_rel, anchor = target.split("#", 1)
            if anchor == "3-application-boundary-adapters":
                has_canonical_anchor = True
            resolved = (src_path.parent / target_file_rel).resolve()
            if resolved != patterns_path.resolve():
                failures.append(f"{name}: link target {target_file_rel} does not resolve to patterns.md (resolved: {resolved})")
    if not has_canonical_anchor:
        failures.append(f"{name} ({src_path}) missing link to exact canonical anchor {CANONICAL_ANCHOR}")

# Validate authored site canonical URL
if CANONICAL_SITE_URL not in surface_texts["site"]:
    failures.append(f"site page missing exact canonical URL: {CANONICAL_SITE_URL}")

# ==============================================================================
# 3. Structural Placement & Authored Site Reference Checks
# ==============================================================================
require(surface_texts["arch"], r"Boundary adapters map wire or vendor data.*patterns\.md#3-application-boundary-adapters", "architecture.md missing boundary adapter placement with canonical link")
require(surface_texts["site"], r"Boundary adapters map wire or vendor representations.*patterns\.md#3-application-boundary-adapters", "repository-rules.mdx missing boundary adapter placement with canonical link")
require(surface_texts["site"], r"### Application-boundary adapters", "repository-rules.mdx missing ### Application-boundary adapters section")
require(surface_texts["site"], r"Keep transport, client, and vendor formats out of domain and business logic through boundary adapters", "repository-rules.mdx missing domain isolation obligation")
require(surface_texts["site"], r"Adapters own input validation/narrowing, wire/domain bidirectional mapping, and transport error translation", "repository-rules.mdx missing adapter responsibilities")

# ==============================================================================
# 4. Source-Grounded Scenario Checks
# ==============================================================================

# Scenario 1: Positive Case — New Server-Client Differing Wire/Domain Shape Flow
# Asserts the complete Plan -> Execute/Change -> Review enforcement chain with focused tests and review carve-outs.
scenario_1_assertions = [
    (surface_texts["plan"],
     r"inter-application boundary.*specify adapter mapping.*boundary validation/narrowing.*transport error translation.*app-local placement.*wire/API compatibility.*focused boundary test obligations",
     "Scenario 1 (Plan): missing inter-app boundary mapping, validation, error translation, placement, compatibility, or test obligations"),
    (surface_texts["execute"],
     r"applicable inter-application boundary requirements.*mapping, validation, error translation, app-local placement, compatibility, and focused boundary tests.*patterns\.md#3-application-boundary-adapters",
     "Scenario 1 (Execute packet): missing boundary adapter packet requirements and canonical link"),
    (surface_texts["execute"],
     r"enforcing the canonical \[application-boundary adapters rule\].*when new or materially changed inter-application boundaries are touched",
     "Scenario 1 (Execute loop): missing worker loop boundary adapter enforcement"),
    (surface_texts["change"],
     r"touching new or materially changed inter-application boundaries.*route wire/vendor data through app-local adapters.*isolate transport errors.*validate/narrow untrusted inputs.*preserve wire/API compatibility.*focused mapping or round-trip tests plus affected boundary error-path coverage",
     "Scenario 1 (Change): missing boundary adapter implementation, validation, transport isolation, or test obligations"),
    (surface_texts["review"],
     r"Scope\..*structural-quality regressions.*and.*application-boundary leaks",
     "Scenario 1 (Review scope): missing application-boundary leaks as explicit review responsibility"),
    (surface_texts["review"],
     r"not a correctness reviewer.*except for enforcing application-boundary integrity.*input validation/narrowing, wire/domain bidirectional mapping, and transport error translation",
     "Scenario 1 (Review role): missing boundary integrity carve-out in reviewer role"),
    (surface_texts["review"],
     r"Application-boundary leak.*New or materially touched code crossing inter-application boundaries.*leaks wire, transport, client, or vendor representations.*or omits required boundary validation or transport error translation",
     "Scenario 1 (Review find): missing Application-boundary leak find item"),
    (surface_texts["review"],
     r"other angles own those \(except application-boundary validation, wire/domain mapping, and transport error translation, which are owned here\)",
     "Scenario 1 (Review skip carve-out): missing boundary exception in correctness/security skip"),
    (surface_texts["review"],
     r"Application-boundary findings:.*name \(a\) the concrete changed boundary, \(b\) the exact leaked transport, client, or vendor representation or missing required validation/error translation, and \(c\) the concrete adapter, validation, or error-translation repair",
     "Scenario 1 (Review grounding): missing boundary-specific grounding standard and repair requirement"),
    (surface_texts["review"],
     r"HIGH.*blocking: true.*concrete changed-code application-boundary leak",
     "Scenario 1 (Review severity): missing HIGH/blocking rubric for boundary leaks"),
]

for text, pattern, message in scenario_1_assertions:
    require(text, pattern, message)

# Scenario 2: Negative Case — Deliberately Shared Identity-Shape Flow
# Asserts consistent no-op wrapper omission across all surfaces while preserving validation and transport handling.
scenario_2_assertions = [
    (patterns_text,
     r"deliberately shared contract is already the application/domain shape, do not add an identity-only or no-op wrapper.*Boundary validation and transport/error handling still apply",
     "Scenario 2 (Patterns): canonical pattern missing no-op wrapper exclusion or validation/transport preservation"),
    (surface_texts["plan"],
     r"Do not demand identity-only or no-op wrappers when a deliberately shared contract is already the application/domain shape",
     "Scenario 2 (Plan): missing no-op wrapper exclusion for shared domain shapes"),
    (surface_texts["execute"],
     r"without introducing identity-only wrappers",
     "Scenario 2 (Execute): missing identity-only wrapper exclusion in worker loop"),
    (surface_texts["change"],
     r"do not migrate untouched legacy boundaries or introduce no-op wrappers for shared identity contracts",
     "Scenario 2 (Change): missing no-op wrapper exclusion for shared contracts"),
    (surface_texts["review"],
     r"Adapter folder naming.*class-versus-function.*justified omission of identity-only wrappers.*Untouched legacy boundary flows are also skipped",
     "Scenario 2 (Review): missing non-blocking skips for naming, class-vs-function style, no-op wrappers, and legacy"),
    (surface_texts["site"],
     r"Do not add identity-only or no-op wrappers when a deliberately shared contract is already the domain model shape",
     "Scenario 2 (Site): missing no-op wrapper exclusion for shared domain shapes"),
]

for text, pattern, message in scenario_2_assertions:
    require(text, pattern, message)

# ==============================================================================
# 5. Final Verdict
# ==============================================================================
if failures:
    print("Application-boundary adapter contract failures:", file=sys.stderr)
    for f in failures:
        print(f"  - {f}", file=sys.stderr)
    sys.exit(1)

print("test-application-boundary-adapters: ok")
PY
