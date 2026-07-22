#!/usr/bin/env bash
# Closed, behavior-tested structural contract for read-only artifact consumers.
# Adapter I/O is exercised by woostack-init's artifact tests; this suite owns reader
# discovery, backend/read ordering, compatibility-scan boundaries, and mutation safety.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../woostack-init/scripts/tests/assert.sh"
set +e

ROOT="${WOOSTACK_READER_ROOT:-$(cd "$HERE/../../.." && pwd)}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/woostack-reader-contract.XXXXXX")" || exit 1
trap 'rm -rf -- "$TMP_ROOT"' EXIT HUP INT TERM

analyze_root() {
  python3 - "$1" "${2:-repository}" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
validation_mode = sys.argv[2]
skills_root = root / "skills"

# Every artifact-reading SKILL discovered below must be classified here. This is wider than
# Increment 9's read-only set because existing lifecycle writers and controllers also read.
approved_artifact_skills = {
    "woostack-address-comments",
    "woostack-ask",
    "woostack-audit",
    "woostack-fix",
    "woostack-build",
    "woostack-commit",
    "woostack-debug",
    "woostack-dream",
    "woostack-execute",
    "woostack-harden",
    "woostack-plan",
    "woostack-review",
    "woostack-status",
    "woostack-tdd",
    "woostack-visualize",
}

# Increment 9 readers are query-only. Values are the normalized Linear operations each
# consumer is allowed to invoke; adapter semantics stay in test-artifact-backends.sh.
read_only = {
    "woostack-review": {"feature-read"},
    "woostack-address-comments": {"feature-read"},
    "woostack-ask": {"identity-resolve"},
    "woostack-visualize": {"identity-resolve"},
    "woostack-debug": {"identity-resolve"},
    "woostack-audit": {"identity-resolve"},
    "woostack-dream": {"doctor-read", "identity-resolve"},
}

mutation_operations = {
    "feature-create",
    "feature-transition",
    "spec-write",
    "plan-reconcile",
    "issue-transition",
    "status-reconcile",
    "projectCreate",
    "projectUpdate",
    "documentCreate",
    "documentUpdate",
    "issueCreate",
    "issueUpdate",
}
read_operations = {
    "feature-read",
    "feature-resolve",
    "doctor-read",
    "identity-resolve",
    "spec-read",
    "plan-read",
}
negative = re.compile(
    r"\b(?:never|must\s+not|may\s+not|do\s+not|does\s+not|cannot|can't|prohibit(?:ed|s)?|"
    r"forbid(?:den|s)?|ban(?:ned|s)?|no\s+(?:linear\s+)?mutation)\b",
    re.I,
)
readish = re.compile(r"\b(?:read|scan|grep|glob|find|enumerat|load|fetch|corpus)\w*\b", re.I)
local_artifact = re.compile(r"\.woostack/(?:specs|plans)(?:/|\b)", re.I)
adapter_signal = re.compile(
    r"resolve-backend\.sh|markdown\.sh\s+feature|linear\.sh\s+(?:"
    + "|".join(re.escape(op) for op in sorted(read_operations | mutation_operations))
    + r")",
    re.I,
)
broad_scan = re.compile(
    r"git\s+ls-files\s+[`'\"]?\*\.md|"
    r"find\s+(?:\.|\.woostack)\b[^\n]{0,160}(?:\.md|markdown)|"
    r"(?:rg|grep)\s+[^\n]{0,160}\.woostack|"
    r"\.woostack/(?:\*\*/\*|\*\*/\*\.md)|"
    r"(?:whole|entire)\s+(?:repository|repo|\.woostack)[^\n]{0,100}(?:scan|glob|read|enumerat)",
    re.I,
)

def paragraphs(text: str):
    offset = 0
    for raw in re.split(r"\n\s*\n", text):
        if not raw:
            offset += 1
            continue
        start = text.find(raw, offset)
        offset = start + len(raw)
        yield text.count("\n", 0, start) + 1, re.sub(r"\s+", " ", raw).strip()

def sentences(paragraph: str):
    return [part.strip() for part in re.split(r"(?:[.!?;]|\n)\s+", paragraph) if part.strip()]


def is_candidate(text: str) -> bool:
    if adapter_signal.search(text) or broad_scan.search(text):
        return True
    return any(local_artifact.search(p) and readish.search(p) for _, p in paragraphs(text))


def failure(name: str, message: str):
    failures.append(f"{name}: {message}")

skill_files = sorted(skills_root.glob("*/SKILL.md"))
texts = {path.parent.name: path.read_text(encoding="utf-8") for path in skill_files}
discovered = {name for name, text in texts.items() if is_candidate(text)}
failures = []

for name in sorted(discovered - approved_artifact_skills):
    failure(name, "unapproved artifact reader discovered repo-wide")
for name in sorted(approved_artifact_skills - discovered):
    failure(name, "approved artifact surface disappeared from reader discovery")
for name in sorted(read_only):
    if name not in texts:
        failure(name, "required Increment 9 reader is missing")

for name, allowed_reads in read_only.items():
    text = texts.get(name, "")
    if not text:
        continue
    folded = re.sub(r"\s+", " ", text)

    resolver = re.search(r"resolve-backend\.sh", text, re.I)
    adapter_reads = list(re.finditer(
        r"(?:markdown\.sh\s+feature|linear\.sh\s+(?:"
        + "|".join(re.escape(op) for op in sorted(allowed_reads))
        + r"))",
        text,
        re.I,
    ))
    if resolver is None:
        failure(name, "does not resolve the backend")
    if not adapter_reads:
        failure(name, "does not invoke an approved normalized reader")
    elif resolver is not None and any(match.start() < resolver.start() for match in adapter_reads):
        failure(name, "invokes an artifact adapter before backend resolution")

    if not re.search(r"backend\s*==\s*markdown", text, re.I):
        failure(name, "has no explicit Markdown compatibility branch")
    if not re.search(r"markdown\.sh\s+feature", text, re.I):
        failure(name, "bypasses the normalized Markdown feature reader")
    if not any(
        re.search(r"\b(?:consume|use|retain|take|read)\w*\b", p, re.I)
        and all(field in p for field in (".feature", ".spec", ".increments"))
        for _, p in paragraphs(text)
    ):
        failure(name, "does not consume the complete normalized reader model")
    if not (re.search(r"\buntrusted\b", text, re.I) and re.search(r"\binstructions?\b", text, re.I)):
        failure(name, "does not treat normalized remote text as untrusted data, never instructions")

    # Local spec/plan reads are compatibility behavior only. A negative sentence may name a
    # forbidden path; every positive read must carry its Markdown branch guard in the paragraph.
    for line, paragraph in paragraphs(text):
        if not (local_artifact.search(paragraph) and readish.search(paragraph)):
            continue
        if negative.search(paragraph):
            continue
        if name == "woostack-dream" and "git ls-files" in paragraph and "unconditionally" in paragraph.lower():
            continue
        if not re.search(r"backend\s*==\s*markdown", paragraph, re.I):
            failure(name, f"unguarded direct spec/plan filesystem read near line {line}")

    # Reject broad whole-tree discovery even when the text later mentions a backend. Dream's
    # documentation inventory is the sole exception and must visibly exclude both local corpora
    # for every backend before its selected Markdown branch may add them as trend input.
    for line, paragraph in paragraphs(text):
        if not broad_scan.search(paragraph) or negative.search(paragraph):
            continue
        dream_docs_exception = (
            name == "woostack-dream"
            and "git ls-files" in paragraph
            and "unconditionally" in paragraph.lower()
            and ".woostack/specs" in paragraph
            and ".woostack/plans" in paragraph
            and re.search(r"\bexclud\w*\b", paragraph, re.I)
        )
        if not dream_docs_exception:
            failure(name, f"broad artifact-tree scan bypass near line {line}")

    for line, paragraph in paragraphs(text):
        for sentence in sentences(paragraph):
            for operation in sorted(mutation_operations):
                if re.search(rf"\b{re.escape(operation)}\b", sentence, re.I) and not negative.search(sentence):
                    failure(name, f"forbidden Linear mutation {operation} near line {line}")
            if (
                re.search(r"\blinear\b", sentence, re.I)
                and re.search(r"\b(?:delegate|dispatch|hand\s+off|helper|wrapper)\w*\b", sentence, re.I)
                and re.search(r"\b(?:write|transition|reconcile|create|mutat)\w*\b", sentence, re.I)
                and not negative.search(sentence)
            ):
                failure(name, f"indirect Linear mutation path near line {line}")

# Consumer-specific semantic regressions that mere adapter-token checks cannot catch.
audit = texts.get("woostack-audit", "")
if re.search(r"single\s+unambiguous\s+managed\s+(?:feature|project)\s+when\s+no\s+explicit", audit, re.I):
    failure("woostack-audit", "ordinary code target auto-resolves an unrelated singleton Linear project")
for required in (
    r"explicit\s+artifact\s+identity",
    r"deterministic\s+attribution",
    r"zero\s+or\s+multiple",
    r"artifact\s+context\s+(?:stays|remains|is)\s+empty",
):
    if not re.search(required, audit, re.I):
        failure("woostack-audit", f"missing ordinary-target isolation contract: {required}")
if not (re.search(r"spec-only", audit, re.I) and re.search(r"(?:absent|missing|without|no)\s+(?:joined\s+)?plan", audit, re.I)):
    failure("woostack-audit", "does not preserve normalized Markdown spec-only audits")

dream = texts.get("woostack-dream", "")
docs_paragraphs = [p for _, p in paragraphs(dream) if re.search(r"git\s+ls-files\s+[`'\"]?\*\.md", p, re.I)]
if len(docs_paragraphs) != 1:
    failure("woostack-dream", "must define exactly one tracked-Markdown documentation inventory")
elif not all(token in docs_paragraphs[0] for token in (".woostack/specs", ".woostack/plans")) or not re.search(
    r"unconditionally\s+exclud", docs_paragraphs[0], re.I
):
    failure("woostack-dream", "documentation inventory does not unconditionally exclude local specs/plans")
if not (re.search(r"spec-only", dream, re.I) and re.search(r"(?:absent|missing|without|no)\s+(?:joined\s+)?plan", dream, re.I)):
    failure("woostack-dream", "Markdown branch omits normalized spec-only artifacts")
if re.search(r"resolve-backend\.sh[^.]{0,120}exactly\s+once", folded, re.I):
    failure("woostack-dream", "claims a false process-wide resolver call count despite doctor runtime isolation")


# Adoption documentation mirrors workflow contracts without becoming a second implementation
# manual. Keep this set closed: adding a SKILL.md or routing row is a deliberate public-surface
# change, not a side effect of documenting an artifact backend.
fixed_skills = {
    "using-woostack",
    "woostack-address-comments",
    "woostack-ask",
    "woostack-audit",
    "woostack-bootstrap",
    "woostack-build",
    "woostack-commit",
    "woostack-debug",
    "woostack-doctor",
    "woostack-dream",
    "woostack-execute",
    "woostack-execute-overnight",
    "woostack-fix",
    "woostack-change",
    "woostack-harden",
    "woostack-ideate",
    "woostack-init",
    "woostack-plan",
    "woostack-qa",
    "woostack-respond",
    "woostack-review",
    "woostack-status",
    "woostack-sweep",
    "woostack-tdd",
    "woostack-visualize",
}
public_skills = fixed_skills - {"woostack-ask", "woostack-harden", "woostack-ideate"}
if set(texts) != fixed_skills:
    failure("skill-surface", f"expected 25 fixed SKILL.md locations, found {len(texts)}")

using = texts.get("using-woostack", "")
routes = re.findall(r"^\| `/([^`\s]+)", using, re.M)
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
    "woostack-respond",
    "woostack-address-comments",
    "woostack-status",
    "woostack-visualize",
    "woostack-debug",
    "woostack-tdd",
    "woostack-dream",
    "woostack-doctor",
]
if routes != expected_routes:
    failure("skill-surface", "public command routing rows must remain exactly the ordered 22-command surface")

if validation_mode == "repository":
    doc_paths = {
        "AGENTS.md": root / "AGENTS.md",
        "README.md": root / "README.md",
        "CONTRIBUTING.md": root / "CONTRIBUTING.md",
        "using-woostack": skills_root / "using-woostack" / "SKILL.md",
        "development": skills_root / "woostack-bootstrap" / "references" / "development.md",
        "init": skills_root / "woostack-init" / "SKILL.md",
        "worktrees": skills_root / "woostack-init" / "references" / "worktrees.md",
        "status-conventions": skills_root / "woostack-status" / "references" / "conventions.md",
        "site-index": root / "site" / "content" / "docs" / "index.mdx",
        "site-getting-started": root / "site" / "content" / "docs" / "getting-started.mdx",
        "site-concepts": root / "site" / "content" / "docs" / "concepts.mdx",
        "site-configuration": root / "site" / "content" / "docs" / "configuration.mdx",
        "site-build-loop": root / "site" / "content" / "docs" / "concepts" / "building-rules.mdx",
        "site-status": root / "site" / "content" / "docs" / "concepts" / "status-tracking.mdx",
    }
    doc_texts = {}
    for name, path in doc_paths.items():
        if not path.is_file():
            failure(name, "required adoption document is missing")
            doc_texts[name] = ""
        else:
            doc_texts[name] = path.read_text(encoding="utf-8")

    def require_doc(name: str, pattern: str, message: str):
        if not re.search(pattern, doc_texts.get(name, ""), re.I | re.S):
            failure(name, message)

    # development.md owns the adoption overview; related docs link to it and to the existing
    # build/worktree/status authorities rather than restating adapter commands or GraphQL.
    for name in ("AGENTS.md", "README.md", "CONTRIBUTING.md", "using-woostack", "init"):
        require_doc(name, r"development\.md#artifact-backend", "does not link the artifact-backend adoption authority")
    require_doc("development", r"\.\./\.\./woostack-build/SKILL\.md", "does not link the build lifecycle authority")
    require_doc("development", r"\.\./\.\./woostack-init/references/worktrees\.md", "does not link the worktree authority")
    require_doc("development", r"\.\./\.\./woostack-status/references/conventions\.md", "does not link the status authority")
    require_doc("worktrees", r"woostack-build/SKILL\.md#linear-backend-procedure", "does not link the Linear build authority")
    require_doc("status-conventions", r"woostack-bootstrap/references/development\.md#artifact-backend", "does not link the adoption authority")

    require_doc("development", r"Markdown.{0,100}\bdefault\b", "does not describe Markdown as the default backend")
    require_doc("development", r"(?:LINEAR_API_KEY.{0,160}\benvironment\b|\benvironment\b.{0,160}LINEAR_API_KEY)", "does not make Linear authentication environment-only")
    require_doc("development", r"\bproject\b.{0,160}\bspec document\b.{0,160}\bincrement issues\b", "does not state the canonical Linear artifact model")
    require_doc("development", r"native project statuses.{0,160}team issue states", "does not preserve native Linear lifecycle state")
    require_doc("development", r"exactly\s+three\s+hard\s+gates", "does not preserve exactly three workflow gates")
    require_doc("development", r"Linear.{0,200}no docs-only base PR", "does not exclude the Markdown docs-only base PR from Linear mode")
    require_doc("status-conventions", r"Every `/woostack-status` run.{0,240}terminal\s+reconciliation", "does not require terminal reconciliation on every status run")
    require_doc("AGENTS.md", r"twenty-two\s+public.{0,160}twenty-five\s+fixed\s+`SKILL\.md`", "does not preserve the 22-public/25-fixed skill surface")

    # The authored site has six framing-page equivalents. Generated per-skill pages remain out of
    # scope, but each authored page must preserve the backend fact it presents to consumers.
    require_doc("site-index", r"Markdown\s+is\s+the\s+default.{0,160}Linear.{0,160}(?:projects|project).{0,100}(?:documents|document).{0,100}(?:issues|issue).{0,80}canonical", "does not frame the default and canonical Linear model")
    require_doc("site-index", r"/docs/configuration#artifact-backend", "does not link the site backend authority")

    require_doc("site-getting-started", r"artifacts\.specPlan.{0,80}linear", "does not explain Linear selection")
    require_doc("site-getting-started", r"LINEAR_API_KEY.{0,160}(?:process environment|secret manager)", "does not make Linear authentication environment-only")
    require_doc("site-getting-started", r"native projects.{0,120}documents.{0,120}issues.{0,120}canonical", "does not identify native Linear artifacts as canonical")
    require_doc("site-getting-started", r"clean boundary.{0,240}(?:inactive|Migrate deliberately)", "does not explain the migration boundary")
    require_doc("site-getting-started", r"development\.md#artifact-backend", "does not link the repository adoption authority")

    require_doc("site-concepts", r"Three hard gates", "does not preserve the three-gate overview")
    require_doc("site-concepts", r"Markdown.{0,120}default.{0,240}Linear.{0,200}project.{0,120}spec document.{0,120}(?:increment issues|ordered issue)", "does not compare canonical backend models")
    require_doc("site-concepts", r"Linear.{0,240}no docs-only base PR", "does not preserve the Linear handoff difference")
    require_doc("site-concepts", r"/docs/configuration#artifact-backend", "does not link the site backend authority")

    require_doc("site-configuration", r"artifacts\.specPlan.{0,160}default is `markdown`", "does not document the default selector")
    require_doc("site-configuration", r"Projects\s+are\s+the\s+feature.{0,160}document\s+is\s+the\s+spec.{0,160}issues\s+are\s+the\s+plan\s+increments", "does not document the canonical Linear resource model")
    require_doc("site-configuration", r"native states.{0,120}(?:relations|canonical)", "does not preserve native Linear lifecycle state")
    require_doc("site-configuration", r"LINEAR_API_KEY.{0,120}(?:environment-only|shell or secret manager)", "does not make Linear authentication environment-only")
    require_doc("site-configuration", r"Changing the selector does not migrate data.{0,320}inactive legacy artifacts", "does not document the migration boundary")
    require_doc("site-configuration", r"development\.md#artifact-backend", "does not link the repository adoption authority")

    require_doc("site-build-loop", r"Exactly three hard gates", "does not preserve exactly three gates")
    for gate in ("Design approval", "Written-spec approval", "Execution handoff"):
        require_doc("site-build-loop", re.escape(gate), f"does not preserve the {gate} gate")
    require_doc("site-build-loop", r"Markdown \(default\).{0,300}Linear", "does not compare backend handoffs")
    require_doc("site-build-loop", r"Linear has no docs-only base PR", "does not exclude a Linear docs-only base PR")
    require_doc("site-build-loop", r"woostack-build/SKILL\.md#linear-backend-procedure", "does not link the Linear lifecycle authority")
    require_doc("site-status", r"Status authenticates before reading Linear.{0,120}narrow terminal reconciliation", "does not preserve authenticated terminal reconciliation")
    require_doc("site-status", r"managed project.{0,120}spec document.{0,120}ordered increment issues", "does not preserve the canonical Linear model")
    require_doc("site-status", r"native project.{0,120}team issue states", "does not preserve native lifecycle state")
    require_doc("site-status", r"Backend selection is a clean boundary, not synchronization or fallback.{0,400}inactive", "does not preserve the status migration boundary")
    require_doc("site-status", r"woostack-status/references/conventions\.md", "does not link the status authority")

    joined_docs = "\n".join(doc_texts.values())
    if re.search(r"twenty-three\s+(?:public|skills)|twenty-six\s+(?:fixed|`SKILL\.md`)|23\s+public|26\s+fixed|twenty-one\s+public|twenty-four\s+fixed|21\s+public|24\s+fixed|twenty\s+public|twenty-two\s+fixed|20\s+public|22\s+fixed", joined_docs, re.I):
        failure("skill-surface", "stale non-22-public/non-25-fixed count remains in adoption docs")
    for forbidden in (
        r"api\.linear\.app/graphql",
        r"\b(?:query|mutation)\s*\{",
        r"\b(?:project|document|issue)(?:Create|Update)\b",
    ):
        if re.search(forbidden, joined_docs):
            failure("adoption-docs", f"duplicates adapter query detail: {forbidden}")
if failures:
    print("\n".join(failures))
    raise SystemExit(1)
print(f"discovered {len(discovered)} approved artifact surfaces; validated {len(read_only)} read-only readers")
PY
}

record_analysis() {
  local root="$1" label="$2" output
  if output="$(analyze_root "$root" repository 2>&1)"; then
    pass
  else
    fail "$label: $output"
  fi
}

expect_fixture_failure() {
  local root="$1" expected="$2" label="$3" mode="${4:-fixture}" output
  if output="$(analyze_root "$root" "$mode" 2>&1)"; then
    fail "$label: injected violation unexpectedly passed"
  elif [[ "$output" == *"$expected"* ]]; then
    pass
  else
    fail "$label: wrong failure: $output"
  fi
}

make_fixture() {
  local destination="$1" skill
  mkdir -p "$destination/skills"
  for skill in "$ROOT"/skills/*/SKILL.md; do
    mkdir -p "$destination/skills/$(basename "$(dirname "$skill")")"
    cp "$skill" "$destination/skills/$(basename "$(dirname "$skill")")/SKILL.md"
  done
}

# First validate the real repository. The adapter suite owns Markdown spec-only parsing and
# Linear query behavior; the review runtime suite owns executable trailer/context extraction.
record_analysis "$ROOT" "repository reader contract"
if [[ -f "$ROOT/skills/woostack-init/scripts/tests/test-artifact-backends.sh" &&
      -f "$ROOT/skills/woostack-init/scripts/tests/test-linear-resources.sh" ]]; then
  pass
else
  fail "shared Markdown/Linear adapter behavior suites are missing"
fi
if [[ -f "$ROOT/skills/woostack-review/scripts/tests/test-resolve-artifact-context.sh" ]]; then
  pass
else
  fail "shared review artifact-context behavior suite is missing"
fi

# Behavioral fixtures prove discovery and semantic checks cannot be satisfied by sprinkling
# expected tokens into today's seven files.
fixture="$TMP_ROOT/duplicate-route"
make_fixture "$fixture"
printf '\n| `/woostack-init`, duplicate route | `woostack-init` |\n' \
  >> "$fixture/skills/using-woostack/SKILL.md"
expect_fixture_failure "$fixture" "ordered 22-command surface" "duplicate routing-row rejection"

fixture="$TMP_ROOT/reordered-routes"
make_fixture "$fixture"
python3 - "$fixture/skills/using-woostack/SKILL.md" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
lines = path.read_text().splitlines()
routes = [index for index, line in enumerate(lines) if line.startswith("| `/")]
lines[routes[0]], lines[routes[1]] = lines[routes[1]], lines[routes[0]]
path.write_text("\n".join(lines) + "\n")
PY
expect_fixture_failure "$fixture" "ordered 22-command surface" "routing-row order rejection"

fixture="$TMP_ROOT/missing-adoption-contract"
make_fixture "$fixture"
expect_fixture_failure "$fixture" "required adoption document is missing" \
  "missing repository adoption contract" repository

fixture="$TMP_ROOT/new-reader"
make_fixture "$fixture"
mkdir -p "$fixture/skills/woostack-injected-reader"
cat > "$fixture/skills/woostack-injected-reader/SKILL.md" <<'EOF'
# Injected reader
Run resolve-backend.sh, then read .woostack/specs/*.md with markdown.sh feature.
For Linear, call linear.sh feature-read.
EOF
expect_fixture_failure "$fixture" "unapproved artifact reader" "repo-wide new-reader discovery"

fixture="$TMP_ROOT/broad-scan"
make_fixture "$fixture"
printf '\nScan the entire repository with `find .woostack -name "*.md"` before choosing context.\n' \
  >> "$fixture/skills/woostack-ask/SKILL.md"
expect_fixture_failure "$fixture" "broad artifact-tree scan bypass" "whole-tree bypass rejection"

fixture="$TMP_ROOT/indirect-mutation"
make_fixture "$fixture"
printf '\nFor Linear, never call feature-create directly; delegate spec-write through a helper.\n' \
  >> "$fixture/skills/woostack-audit/SKILL.md"
expect_fixture_failure "$fixture" "forbidden Linear mutation spec-write" \
  "mixed-negative indirect mutation rejection"

fixture="$TMP_ROOT/read-order"
make_fixture "$fixture"
python3 - "$fixture/skills/woostack-audit/SKILL.md" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
path.write_text("Call linear.sh identity-resolve before selecting a backend.\n\n" + path.read_text())
PY
expect_fixture_failure "$fixture" "before backend resolution" "backend-first order rejection"

fixture="$TMP_ROOT/audit-singleton"
make_fixture "$fixture"
printf '\nResolve the single unambiguous managed project when no explicit reference was supplied.\n' \
  >> "$fixture/skills/woostack-audit/SKILL.md"
expect_fixture_failure "$fixture" "ordinary code target auto-resolves" \
  "ordinary code target isolation"

fixture="$TMP_ROOT/dream-doc-inventory"
make_fixture "$fixture"
python3 - "$fixture/skills/woostack-dream/SKILL.md" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text()
path.write_text(text.replace(
    "Unconditionally exclude",
    "When `backend == markdown`, exclude",
    1,
))
PY
expect_fixture_failure "$fixture" "documentation inventory does not unconditionally exclude" \
  "inactive local corpus exclusion"

finish
