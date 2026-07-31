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
cleanup() { rm -rf -- "$TMP_ROOT"; }
trap cleanup EXIT
trap 'trap - EXIT; cleanup; exit 130' HUP INT TERM

analyze_root() {
  python3 - "$1" "${2:-repository}" <<'PY'
import hashlib
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
    "woostack-init",
    "woostack-status",
    "woostack-doctor",
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

# Init and doctor may inspect legacy local artifact directories only to classify migration
# blockers. They are not normalized feature consumers and may not adopt or mutate those records.
compatibility_readers = {
    "woostack-init",
    "woostack-doctor",
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
compatibility_action = re.compile(
    r"\b(?:use|uses|used|using|adopt|adopts|adopted|adopting|process|processes|processed|processing|"
    r"treat|treats|treated|treating|consume|consumes|consumed|consuming|open|opens|opened|opening|"
    r"read|reads|reading|load|loads|loaded|loading|scan|scans|scanned|scanning|inspect|inspects|"
    r"inspected|inspecting|parse|parses|parsed|parsing|walk|walks|walked|walking|traverse|"
    r"traverses|traversed|traversing|list|lists|listed|listing|find|finds|found|finding|grep|"
    r"greps|grepped|grepping|glob|globs|globbed|globbing)\b",
    re.I,
)
local_artifact = re.compile(r"\.woostack/(?:specs|plans)(?:/|\b)", re.I)
legacy_local_artifact = re.compile(r"\.woostack/(?:specs|plans|fixes|overnight)(?:/|\b)", re.I)
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


def directly_negated(text: str, start: int) -> bool:
    prefix = text[max(0, start - 160):start]
    return bool(re.search(
        r"\b(?:never|must\s+not|may\s+not|do\s+not|does\s+not|cannot|can't|no)\b"
        r"(?:\s+[\w`][\w`'-]*){0,12}\s*$",
        prefix,
        re.I,
    ))


def compatibility_pure_prohibition(paragraph: str) -> bool:
    starters = r"(?:No|Never|Neither|Cannot|Can't|Must not|May not|Do not|Does not)"
    if not re.match(rf"^{starters}\b", paragraph, re.I):
        return False
    if re.search(r"\bdo not (?:hesitate|fail|forget)\b", paragraph, re.I):
        return False
    if ";" in paragraph or re.search(
        r"\b(?:but|however|yet|then|instead|although)\b", paragraph, re.I
    ):
        return False
    clauses = [part.strip() for part in re.split(r"[.!?]+\s*", paragraph) if part.strip()]
    negative_clause = re.compile(
        rf"^(?:{starters}\b|.{{1,100}}\b(?:never|cannot|can't|must not|may not|do not|does not)\b)",
        re.I,
    )
    return bool(clauses) and all(negative_clause.match(clause) for clause in clauses)


def compatibility_declaration(name: str, text: str):
    marker = "woostack-legacy-compatibility"
    open_markers = list(re.finditer(rf"<!--\s*{marker}\b.*?-->", text, re.I | re.S))
    close_markers = list(re.finditer(rf"<!--\s*/{marker}\s*-->", text, re.I))
    if len(open_markers) != 1 or len(close_markers) != 1:
        failure(name, "requires exactly one balanced legacy compatibility declaration")
        return None
    opening, closing = open_markers[0], close_markers[0]
    if opening.end() >= closing.start():
        failure(name, "legacy compatibility declaration is unbalanced or nested")
        return None
    if re.search(rf"<!--\s*/?{marker}\b", text[opening.end():closing.start()], re.I):
        failure(name, "legacy compatibility declaration is nested")
        return None
    expected = (
        f'<!-- {marker} reader="{name}" operation="inspect" '
        'paths=".woostack/specs/|.woostack/plans/|.woostack/fixes/|.woostack/overnight/" '
        'purpose="migration-classification-only" lifecycle-use="prohibited" -->'
    )
    if opening.group() != expected:
        failure(name, "legacy compatibility declaration has malformed or unknown attributes")
        return None
    body = text[opening.end():closing.start()]
    expected_paths = {".woostack/specs/", ".woostack/plans/", ".woostack/fixes/", ".woostack/overnight/"}
    if set(re.findall(r"\.woostack/(?:specs|plans|fixes|overnight)/", body, re.I)) != expected_paths:
        failure(name, "legacy compatibility declaration body must target the exact four paths")
        return None
    positive_inspects = [
        match for match in re.finditer(r"\binspect(?:s|ed|ing)?\b", body, re.I)
        if not directly_negated(body, match.start())
    ]
    if len(positive_inspects) != 1 or not re.search(
        r"\b(?:only|solely|exclusively)\b.{0,80}\bmigration\s+classification\b|"
        r"\bmigration\s+classification\b.{0,80}\b(?:only|solely|exclusively)\b",
        body,
        re.I | re.S,
    ):
        failure(name, "legacy compatibility declaration lacks its concrete migration-only inspect")
        return None
    if not re.search(r"\b(?:never|must\s+not|may\s+not|do\s+not|cannot|can't)\b.{0,120}\b(?:use|lifecycle)\b", body, re.I | re.S):
        failure(name, "legacy compatibility declaration lacks lifecycle-use prohibition")
        return None
    return opening.start(), closing.end()


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
for name in compatibility_readers:
    text = texts.get(name, "")
    if not text:
        failure(name, "required compatibility reader is missing")
        continue
    declaration_span = compatibility_declaration(name, text)
    for line, paragraph in paragraphs(text):
        in_declaration = (
            "<!-- woostack-legacy-compatibility " in paragraph
            and "<!-- /woostack-legacy-compatibility -->" in paragraph
        )
        if in_declaration or not legacy_local_artifact.search(paragraph):
            continue
        operations = [
            operation for operation in compatibility_action.finditer(paragraph)
            if operation.group().lower() not in {"finding", "findings"}
        ]
        positive = [
            operation for operation in operations
            if not directly_negated(paragraph, operation.start())
        ]
        if positive:
            failure(name, f"undeclared positive legacy operation near line {line}")
        elif not compatibility_pure_prohibition(paragraph):
            failure(name, f"legacy path outside declaration is not a pure prohibition near line {line}")


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
dream_folded = re.sub(r"\s+", " ", dream)
if re.search(r"resolve-backend\.sh[^.]{0,120}exactly\s+once", dream_folded, re.I):
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
    "woostack-eval",
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
    failure("skill-surface", f"expected 26 fixed SKILL.md locations, found {len(texts)}")

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
    "woostack-eval",
    "woostack-address-comments",
    "woostack-status",
    "woostack-visualize",
    "woostack-debug",
    "woostack-tdd",
    "woostack-dream",
    "woostack-doctor",
]
if routes != expected_routes:
    failure("skill-surface", "public command routing rows must remain exactly the ordered 23-command surface")

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

    for name in ("AGENTS.md", "README.md", "CONTRIBUTING.md", "using-woostack"):
        require_doc(name, r"development\.md#artifact-backend", "does not link the artifact-backend adoption authority")
    # development.md owns the Linear-only adoption overview. Related authorities link to it
    # rather than defining a backend selector or another development-record model.
    for name in ("init", "status-conventions"):
        require_doc(name, r"development\.md#linear-development-authority", "does not link the Linear-only adoption authority")
    require_doc("development", r"\.\./\.\./woostack-build/SKILL\.md", "does not link the build lifecycle authority")
    require_doc("development", r"\.\./\.\./woostack-init/references/worktrees\.md", "does not link the worktree authority")
    require_doc("development", r"\.\./\.\./woostack-status/references/conventions\.md", "does not link the status authority")
    require_doc("worktrees", r"woostack-build/references/linear-procedure\.md", "does not link the Linear build authority")

    require_doc("init", r"host-exposed MCP.*OAuth/MCP secret\s+store", "does not require host-exposed official MCP/OAuth authentication")
    require_doc("development", r"host's official Linear MCP/OAuth connection", "does not make host-owned official MCP/OAuth authoritative")
    require_doc("development", r"no development record, transport configuration, or\s+provider credential", "does not exclude repository transport and credentials")
    require_doc("development", r"does not issue custom Linear GraphQL requests", "does not exclude custom Linear transport")
    require_doc("development", r"repository-owned project.{0,160}typed project updates.{0,160}dependency-aware issue", "does not state the canonical feature record")
    require_doc("development", r"projectStatuses.{0,160}issueStates", "does not preserve configured native lifecycle mappings")
    require_doc("development", r"planning creates and\s+reconciles issues and native relations", "does not preserve native dependency relations")
    require_doc("status-conventions", r"Native project status remains coarse", "does not preserve native project lifecycle state")
    require_doc("status-conventions", r"Managed `increment` and `work-item` issues use the semantic path configured by\s+`linear\.issueStates`", "does not preserve native issue lifecycle state")
    require_doc("development", r"exactly\s+three\s+hard\s+gates", "does not preserve exactly three workflow gates")
    require_doc("development", r"no docs-only base PR", "does not prohibit a docs-only base PR")
    require_doc("development", r"Legacy local development records are migration input only.{0,200}never adopted as a fallback", "does not constrain legacy local records to migration")
    require_doc("status-conventions", r"Every `/woostack-status` run.{0,240}terminal\s+reconciliation", "does not require terminal reconciliation on every status run")
    require_doc("AGENTS.md", r"twenty-three\s+public.{0,160}twenty-six\s+fixed\s+`SKILL\.md`", "does not preserve the 23-public/26-fixed skill surface")

    # Preserve the authored public-site contract until its owning documentation increment changes it.
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
    require_doc("site-build-loop", r"woostack-build/references/linear-procedure\.md", "does not link the Linear lifecycle authority")
    require_doc("site-status", r"Status authenticates before reading Linear.{0,120}narrow terminal reconciliation", "does not preserve authenticated terminal reconciliation")
    require_doc("site-status", r"managed project.{0,120}spec document.{0,120}ordered increment issues", "does not preserve the canonical Linear model")
    require_doc("site-status", r"native project.{0,120}team issue states", "does not preserve native lifecycle state")
    require_doc("site-status", r"Backend selection is a clean boundary, not synchronization or fallback.{0,400}inactive", "does not preserve the status migration boundary")
    require_doc("site-status", r"woostack-status/references/conventions\.md", "does not link the status authority")

    joined_docs = "\n".join(doc_texts.values())
    if re.search(r"twenty-two\s+(?:public|skills)|twenty-five\s+(?:fixed|`SKILL\.md`)|22\s+public|25\s+fixed|twenty-one\s+public|twenty-four\s+fixed|21\s+public|24\s+fixed|twenty\s+public|twenty-two\s+fixed|20\s+public|22\s+fixed", joined_docs, re.I):
        failure("skill-surface", "stale pre-23-public/pre-26-fixed count remains in adoption docs")
    for forbidden in (
        r"api\.linear\.app/graphql",
        r"\b(?:query|mutation)\s*\{",
        r"\b(?:project|document|issue)(?:Create|Update)\b",
    ):
        if re.search(forbidden, joined_docs):
            failure("adoption-docs", f"duplicates adapter query detail: {forbidden}")

    # Regenerate rows deterministically with Python 3: split each LF-normalized file on blank
    # lines, collapse all whitespace in each non-empty paragraph to one space, then SHA-256 its
    # UTF-8 bytes. Print (label, 1-based index, hex digest) in document order.
    canonical_paragraph_manifest = [
        ("development", 1, "0bed3d79b41a0afa2537848b9931d875973f4c0326a94913a0a9b8ebf876f7c4"),
        ("development", 2, "445606e6bfbcec5941e3491d37c3b0d4ba28bb82cb288f2ba4c76baf96abcace"),
        ("development", 3, "bd86079d4f62c94f3d8c9662101d48e7c0483185da111f35fde0dbf689f74168"),
        ("development", 4, "68b9df3d91aaf8154a104e5e9c5cff3ed4d7346e77e3428e8ee4ff5d83513237"),
        ("development", 5, "dcd796146af8771076f8363d18d284c54f533c5532a024fd5f3b45abedc9a427"),
        ("development", 6, "740cc5025e2de5336af44e16b8790cc66ef4b01fb053a96de8cf6965408ae27a"),
        ("development", 7, "2ca6b78ef8b7c01501c0db7add03fef84000bb896c64b1016eb6b5711b3d62c7"),
        ("development", 8, "e9f9345ba8cc54aac7578f53181a57744f696368bc2429d3437e3f274f6db7a9"),
        ("development", 9, "d73a88c5a1d367c8d6f5d778731052a59afd040f5f39254c69c44e08722324f8"),
        ("development", 10, "337b67f5e2301ca5cd9e7b0f9c1b0c5fd4837be34b82df863f13454f8dee162a"),
        ("development", 11, "e4f5e2003360114f1f39bfc3ca43dfd09f454180c0a064d9c2ce90e34e675c0a"),
        ("development", 12, "8cc3b131f95c592cc6e467745492667173457724fa738bb8576d75d13496b095"),
        ("development", 13, "8ab2e7f810d412c70e95d03c80ce8923526d7c6dd6e98df0c4e26e8f32e8d4b0"),
        ("development", 14, "a676c68778769bb22ebffd1bc81954fbdf2fb0e51ce1ed340611e36ea28ca6e8"),
        ("development", 15, "1ba7028af38d1c0685873ef69039c2f4c2f09ecb33e8af71ae31b34f471719a7"),
        ("development", 16, "b42c4d30d77a77827e43c7743e1fa15b133c772e0bd2f384a80771afe4c6ccaa"),
        ("development", 17, "e9edce7f874b25c0b19a01c2ac56e09534b218115dd983ab058ccec854897dc6"),
        ("development", 18, "a968a929a4da11bfe5ffe45989e5b2702caacbe0ad37e1faa5ab724c27416347"),
        ("development", 19, "de225ecf6be8f1372c8c110c6983d0c770c7ade0ae1f223c8788d935adba2ac6"),
        ("development", 20, "362a4cd26c9a121b473df50e73202e006f78a7eca3e1b6e9dcae7610b91ae502"),
        ("development", 21, "f5ec6854bbe421fbd1bd4b6a7397c40978e1f48fcecdfee9fc772d1f4889989e"),
        ("development", 22, "a5b27b65fc3eecf794e492ad71922d3c77f1864f38cd97eeac8b92ed7fee9501"),
        ("init", 1, "8e10072f76545e6ca7fea1d0426dd7dcbaae31023614afc04f4800595bdc79c9"),
        ("init", 2, "2e442cc04485de2683b5dd5f07a13041d65360c9cad946bfd3b3e3af66d2b6bb"),
        ("init", 3, "7337f3d0aa29e9a82b8f1650b743a98eef90794631fa763a319686e69c546821"),
        ("init", 4, "40936e9d20df3a3f0001db7e552e0ca9aeccdc6d1dd547ac186fd7b0fe0ee93a"),
        ("init", 5, "b3324aeb9c0e095347d5ba30d0669351c8410600b982ef97e25532dcb945cfef"),
        ("init", 6, "49fd8adc17a8f25857474576000dcd5e067a7542381afef145b6e822f564c6af"),
        ("init", 7, "5da93bd3e25731d2786cd3c17c54b84047ba82401bc69b04138a3a1a9b0c0402"),
        ("init", 8, "34109299a6b51b34f45967a2603b6ddc8b2d44db1ed9c93232004cc771b0169d"),
        ("init", 9, "b97c526a729c9de7c53e8eaf6cabb6a3e463951e3e16b18825ea199cbee73dab"),
        ("init", 10, "2b70ef76c7d0d6b18549dd3c62fdd0bbdc7bab1fd2f0b1b20c6b9ac4eb04ad1a"),
        ("init", 11, "47c5d85e44547a2a8e39527fc1bfed6625b131b73468027ac1c4f3e773f07666"),
        ("init", 12, "de149207b12ea17a40b2c7c10df76948bebae90a7ebc47a719e5a0b4ce613c84"),
        ("init", 13, "516acc29d415185c062683988f48825e50d1dffd08516a3760b13b751a40088d"),
        ("init", 14, "e7b8b863e9ae9538dd70af072e20f4e7e76af16de9f1943dca22a6ed8bff738b"),
        ("init", 15, "7bd84e1d5c474e76a0e4012d1c5d4a225b5c129ef2a8f2ea2561ae141b147bf3"),
        ("init", 16, "9fef030f690c8664436e588ad7795b0a68fb485bbb958f8158449eca643a5b7e"),
        ("init", 17, "4f872cde712469f3435f1abba6d016d296b1ef7ecc0a0328847ec02ad183857e"),
        ("init", 18, "50c496e7fa0b456662cc7d625f6ccc165d5cb17ffc1956406a14ba5726b39ead"),
        ("init", 19, "efbc86cb22ab52b96a650d86ab4888829a6fe51f351c57f8001364f3dc89c376"),
        ("init", 20, "ca14b10819774d1642bdcec03a9b9aedbfa0b4868fa0a7fd470c949e06a4af11"),
        ("init", 21, "d75918828735437cb2a2055525ea0f4b5ccf38eb210210d5e729a7c55c5f1e75"),
        ("init", 22, "bf16ab4f77bb0b81404e9640f25bc23d91a2efa1f95fa2e26f96282866d74b53"),
        ("init", 23, "7f395ec6b8bf7c0a0820d9d86278fef002e11cc005bbb98f2802baa36cd41bfd"),
        ("init", 24, "568f108bdd343beb0b617dd13c19566d70f96b8e3a3c7f95a9c9502131d22201"),
        ("init", 25, "001d68f3950ea7a7a0ee4806c7175d584def691c1ff73cecfd05af28e693924c"),
        ("init", 26, "bdcaf86c805adf7499e4bd9ca3fc7f285ff9d7316c26c592c98a4fb3153eec32"),
        ("init", 27, "a1add74c9b339881bc7f2ddcfb2d00f63eca023912aa157884d6b53cc90bddbf"),
        ("init", 28, "642ccf3cbeb899a826e48071e1c2bb1409d14e44d326342c495e072759a07efb"),
        ("init", 29, "2d33e3e2182938fc05711a5147c6c880e21e4f3fba551e8a94f03516cf5f9435"),
        ("init", 30, "30da970d6ad0f7292be3167b9c1e517b32c0622b475272915b21559c45e2e4ed"),
        ("init", 31, "189ad87c4ca9ea5d8544ec33b9288744bd443fca1c1cb93b2d82fe8b77501ff2"),
        ("init", 32, "e8d198429c35fa10848e6eff2154cffc0c0098d506eb05e48898060f04f546b1"),
        ("init", 33, "08729004f3a8add5438ba31895ab6c90e4450665db2bc30f6c35e23f6e0728b5"),
        ("init", 34, "5290e3a506a292dbd1e7b63e2f91be3859a8768b19770851604c4312e61fb285"),
        ("worktrees", 1, "e62f3a41fdb122863003100fe52e74c78eaca5c60f3f29ff40da387bd608370b"),
        ("worktrees", 2, "91bfd4fa5d382c5c24bb42f0b161aa80f22570cfbeaf7d849bc35548750a3ba9"),
        ("worktrees", 3, "9b2d8189bed1ba37428388f161b6680ca82c6e6ed3b89dfe8b53170f3f6a8078"),
        ("worktrees", 4, "9a63779fa16ce523882004b1f1c04535e78be0d337a69507fb0372860d86d3ba"),
        ("worktrees", 5, "b698ac5eac3cb0c059c556c055742d93f414b276b3fcc7d668465d6d83e00039"),
        ("worktrees", 6, "124d9ce873d6c6a1b6d2de25f1851d5177498cadb6f10254a5b9dd5bed77e3c7"),
        ("worktrees", 7, "c1fb293580e2c8aa9f0b64ce619d15ac187bd3672298d3e140670f82f67b55b9"),
        ("worktrees", 8, "fecd094f011716765c32552c66012f2c0ce36a13fcf0f2f647624cfe15c3bfc7"),
        ("worktrees", 9, "b0e81abd43490640bf7302a7ec375bea37e80871c87b4b38a12d84de00ed438a"),
        ("worktrees", 10, "5b38d638de71b646ac870568b0c28eed5a6291f715113a4d740096ab638262ae"),
        ("worktrees", 11, "eddeb3ac0d7f7115c11785030c93200c9e3d172e4ab3817ec176c194b4754f60"),
        ("worktrees", 12, "a8943773d90f3e63506088509653f71cebcbeb5ba689ffd6b2922c9516ad05db"),
        ("worktrees", 13, "baad34fa2808f4a0051d5bbe8a3bdee7bc6f1527928c71c4190ad5a187604ee6"),
        ("worktrees", 14, "d1cee620774e242266bdf62105d1cda147664c9a6dc3a5ba3306002362672f69"),
        ("worktrees", 15, "19ca7a925ce5afb35d3e2680a39503a01ebe98db44609941a07e61392e149b45"),
        ("worktrees", 16, "cbaa863a018700730e9e4ec812e54cf17544495173a4bd33fdc268cfcc370b60"),
        ("worktrees", 17, "69b36c3f383fd6e49aae4e4651fbefe2a44a699e786a4d59be0240ea81887133"),
        ("worktrees", 18, "cc78492cb05500b91ae05f5b4c29946884508321b6b23e05ff6cc56526426845"),
        ("worktrees", 19, "834812c6efb853c2da901080d4e510996039fbee2e7114fd840faede911ea1e5"),
        ("worktrees", 20, "5ac9df96eae3fdd419704909566e42413a026584717a4c37b878b3c51be69a29"),
        ("worktrees", 21, "80f68659dc9a55e0b32ba37522b0e321015d55a712f362e4ce433b7098147439"),
        ("worktrees", 22, "35bef93b21e7e3bf6810744d669425dc2c0acf42f805f9c3d32189c134483179"),
        ("worktrees", 23, "c6474727cc5ea14a40dfdd7d6c38e492580a43a8172c7cf5228041f5a447b8df"),
        ("worktrees", 24, "c8260852ad3b43927cb53b43ed311dbda0827c3fc8b4cf1265ad5f8877be1915"),
        ("worktrees", 25, "44e4b151a67a69e5beb8df85aa2f71a57c5ae13c18e9c94a198a46ee73c2c9a2"),
        ("worktrees", 26, "66530c58f123761e088c4fdc013b73069bbcb688bd05bddd42b580f9e10d058d"),
        ("worktrees", 27, "07a56716c2abe56ecf04b5ad8b6d8e367772660d31291fbdedbfa6dbfadb7267"),
        ("worktrees", 28, "fd43d4c70480fbdbfe4eb032eeea96cb6091bab1a4f10136ccbc94fffe773c07"),
        ("worktrees", 29, "82d10da32978f170d2423379133c53b57a0e58fc94576af98f637e311e10b604"),
        ("worktrees", 30, "0b951da6a958e3558750b18975b93f85752e6f21356b3315d737517558b3807d"),
        ("worktrees", 31, "31901d6bf5bce05e6286eb48f628ef02151e419b9c38aaaa6ae5ec77ecd644a6"),
        ("worktrees", 32, "d1d72afe2553fcfbe9f2ed0fc7b403f9fa736a519268c9663a71ccf65ab23f0b"),
        ("worktrees", 33, "57e627144efa2f6b1d0a97b13b672081f99f44849e334504a030a0d53798b9c4"),
        ("worktrees", 34, "854d705a3e664d861feba993eef2c66122d0cf67cf43ee924a15ad210a123e85"),
        ("worktrees", 35, "12a9c761c09fb6629fa9abc15d872e8ceba36eb5caf2a9a152612c27b6111412"),
        ("worktrees", 36, "db678e360ebc9c1d0e70fc011130af245954b6fabc6f7feb45386d9725a3bdf8"),
        ("worktrees", 37, "299abec1b7c24af46fdcc81756a4fd929cec5bfbfce095ecaa9d395548c0a1e8"),
        ("worktrees", 38, "51026104a2444dc27c3c566226b7c2035e5fbdd6a8b2d41df16489ec8aa52432"),
        ("worktrees", 39, "c60a775db2a344a32a8f43008fa076e851101b3969586914b5a1856caea4e0a1"),
        ("worktrees", 40, "e3a7291a899cd8d23be23b55eae6b315d8698ee9bf0a567c3e12d49403f0d891"),
        ("worktrees", 41, "804909e149df1d64be32ccbb16d392ec6cfa3652136847405727b1730e32770a"),
        ("worktrees", 42, "ffc71f76072a5b3e1fae7e64dd2f9e9a7299c6b1c8ef19ab8b491da8b5f59564"),
        ("worktrees", 43, "c8684c710b37d8385c583da4f38d32f903dcf0d2a1b0bea50703eba406bd9618"),
        ("worktrees", 44, "683f1757572a22eddc8bb062e331d481cfe6b1a90728d858e964b0e449db8a6f"),
        ("worktrees", 45, "ea7093fe17d93f96a421eaa5b8275b124bd4a49c54d0eb083a083c80f4912112"),
        ("status-conventions", 1, "c01b904336956e541929ad5b46703e79feabb51223dc4dc1c0f8dfcd0bd8227b"),
        ("status-conventions", 2, "85e1244db9a632ba9957e7effc4025f9706f4073b03c2a591ae3bcad295c6d66"),
        ("status-conventions", 3, "aeb9dbbee2431705401f7b3e7a5ff1f79b2833f33f5daa7cd7ae34bb7b934e99"),
        ("status-conventions", 4, "0b89aa22ac30a99cc2d1c64b24210f6fd567dbe1ce1b70a4911461ef136a16bd"),
        ("status-conventions", 5, "79bb1abb5cf667fb86eda2993029d1194a90e0519458d26c3a43c3bdc0155a7b"),
        ("status-conventions", 6, "a6003fa11c4d13e0b41a8ae3ca5c6c2f3b58abb0f8b6e4f704bb4ce9d41b07d5"),
        ("status-conventions", 7, "8108b429cee3461ed119a08e045792cf385eeb4948c7e8228a39d4857aeccf68"),
        ("status-conventions", 8, "5e50470cb7263a79fa156eaab20ad9236b290b89de85096739bc4d28df5db5e3"),
        ("status-conventions", 9, "3f944b46935ddbab9d635e75d2eee75be8c27b0cb82fe575f9b64cb7c852210a"),
        ("status-conventions", 10, "623fcde3b51827ef0f8d9c6955c82116671620978a43ec41fb629f37ff688b69"),
        ("status-conventions", 11, "9af2431dfda3dbdf1d6fffb665d71165d04b01490bf13486a8a7999ba22d514f"),
        ("status-conventions", 12, "eb863fa19a92ae97c39f1365cd2867332e2c3a094ab58d63e4879d9ead6b0cdb"),
        ("status-conventions", 13, "87733f73bc6817b048dff492774232f2ff5dd1daaa0a41ef0c257afd8b0d632a"),
        ("status-conventions", 14, "4fcb6e0ed94fa666189bfc736e33e2b1ca3fa0392e211093e07ac04043c3fc6b"),
        ("status-conventions", 15, "8b7124f609434ce4dd65df762dc3fa2a61f99011d5286d5fab47c4b57a8b1239"),
        ("status-conventions", 16, "86e8226df46288b1852794d3669e948633ec93695140eddce2e6e6107a3f0087"),
        ("status-conventions", 17, "60518f176fcd64d03e75828c2767c09ef2629be5853fb1463ad9ab7e4c525866"),
        ("status-conventions", 18, "03b0b9988a78f9194fc555cee6390d76d825521bc3fc6aa8f68b76d0ec9a327a"),
        ("status-conventions", 19, "ca12a8bd7dab472a0a40329f3a3dbd5d37ec1337eba2c8023398fd8562e405cf"),
        ("status-conventions", 20, "0e27e6f0120ff4546492c803bd8a661822c3f12a651be87de8a12249aec42d13"),
        ("status-conventions", 21, "a6b3c99b64fa83d03ac8d07827471f49ccfaed8345de663594eddeaa0bf4ad6b"),
        ("status-conventions", 22, "635230a83d610eaffb7d31150a939c430d315e03ba290c2f7d23e2408b5ad801"),
        ("status-conventions", 23, "562578486dda4bb745e52f1785aeedc92cb2207bb2890ef472fc73fc0b391960"),
        ("status-conventions", 24, "52c912780687cb0a2a42921481ba42a06e44efd2c80379c988877b1c153c66c2"),
        ("status-conventions", 25, "f8d5138184eb3b94583ffd7784ced31e5be3f779504fa9a5ccd8688dbbc32500"),
        ("status-conventions", 26, "98173b8d6741e5e61f07390e2dce2759cda0f5ef9c4e227f5e76a1a404d7864d"),
        ("status-conventions", 27, "d3e5c80a0ddb5637a5de9a7c3aae4740db008d631dd2a2caaa0358f61507ec69"),
        ("status-conventions", 28, "6ff620395de581c348f89c34318d63cc6f71703db74f091b5883c8084bddb5b5"),
        ("status-conventions", 29, "c6816b6629fb833191b67c6beca1232ae12d8b429212cbd34685cef51e1e79aa"),
        ("status-conventions", 30, "e9c6698ed84ee32128eeb1f9271d10fcbf1ef3e3e73ce78ca4d041c0861bbe8f"),
        ("status-conventions", 31, "d9faf91f7b24829f90fe59c960575ada1a27251580e4f2188b38a2f7a76280b6"),
        ("status-conventions", 32, "b4c659bc014b968557846e3a02ed1e44a0591ce18977d0cc4a0fb5a7dae1c082"),
        ("status-conventions", 33, "4897cfd5832765e8ab0197b326d7f9e52d2c8184ca2d1e49e63b55ffec001ebc"),
        ("status-conventions", 34, "1313521535573b8ca6c88ba98f93c093839f2976a04d106b11a1a843c190c7ab"),
    ]
    manifests = {}
    for label, index, digest in canonical_paragraph_manifest:
        manifests.setdefault(label, []).append((index, digest))

    def normalized_paragraphs(text: str):
        text = text.replace("\r\n", "\n").replace("\r", "\n")
        return [
            re.sub(r"\s+", " ", raw).strip()
            for raw in re.split(r"\n\s*\n", text)
            if raw.strip()
        ]

    def pure_prohibition(paragraph: str) -> bool:
        text = re.sub(r"\s+", " ", paragraph).strip()
        if not text.endswith(".") or re.search(r"[.!?;:]", text[:-1]):
            return False

        # Extra prose is allowed only when the leading negative directly governs a
        # retired authority or transport. Do not search the whole paragraph for a
        # target: an adjunct such as "official MCP via a local bridge" reverses the
        # policy even though it happens to mention a retired transport.
        authority_root = (
            r"(?:(?:managed|checked-in|version-controlled)\s+)*"
            r"(?:repository-backed|repository-local|repo-local|repository|repo|Markdown|filesystem)"
        )
        authority_noun = (
            r"(?:notes?|records?|state|artifacts?|specifications?|plans?|documents?|files?|"
            r"authority|ledger|backend)"
        )
        authority_phrase = (
            rf"{authority_root}(?:\s+(?:development|work)){{0,2}}(?:\s+{authority_noun})?"
        )
        transport_phrase = (
            r"(?:(?:local|custom|unofficial|internal|direct)\s+)+"
            r"(?:(?:HTTP|GraphQL|Linear)\s+)?(?:backend|transport|bridge|requester|adapter|API)"
        )
        target_phrase = rf"(?:(?:a|an|the)\s+)?(?:{authority_phrase}|{transport_phrase})"
        target_object = re.compile(
            rf"^(?:"
            rf"{target_phrase}(?:\s+or\s+{target_phrase})*"
            rf"(?:\s+as\s+(?:(?:a|an|the)\s+)?(?:authoritative(?:\s+(?:development|work))?\s+"
            rf"(?:state|authority|ledger|source of truth)|development authority|source of truth))?"
            rf"(?:\s+for\s+Linear(?:\s+changes?)?)?"
            rf"|Linear(?:\s+changes?)?\s+(?:through|via)\s+{target_phrase}"
            rf")$",
            re.I,
        )

        def approved_object(value: str) -> bool:
            return bool(target_object.fullmatch(value.strip()))

        verbs = r"(?:create|write|use|select|call|invoke|read|store|persist|choose|open|route|treat|adopt|keep|regard)"
        status = r"(?:allowed|authoritative|created|used|selected|stored|persisted|invoked|called|opened|read|written|routed|treated)"
        status_list = rf"{status}(?:\s*,\s*{status})*(?:\s*,?\s*(?:and|or)\s+{status})?"
        no_form = re.compile(
            rf"^No\s+(?P<subject>[\w`'-]+(?:\s+[\w`'-]+){{0,24}})\s+"
            rf"(?:is|are|may be|can be|will be|shall be)\s+{status_list}\.$",
            re.I,
        )
        approved_no_subject = re.compile(rf"^{target_phrase}$", re.I)
        if re.match(r"^No\b", text, re.I):
            matched = no_form.match(text)
            if not matched:
                return False
            subject = matched.group("subject")
            return bool(approved_no_subject.fullmatch(subject))

        if re.match(r"^Neither\b", text, re.I):
            neither = re.match(
                rf"^Neither\s+{verbs}\b(?P<before_nor>(?:(?!\bnor\b)[^.])*)"
                rf"\bnor\s+{verbs}\b(?P<tail>[^.]*)\.$",
                text,
                re.I,
            )
            return bool(
                neither
                and (
                    not neither.group("before_nor").strip()
                    or approved_object(neither.group("before_nor"))
                )
                and approved_object(neither.group("tail"))
            )

        leading = re.match(
            r"^(?:Never|Cannot|Can't|Must not|May not|Do not|Does not)\b(?P<body>[^.]*)\.$",
            text,
            re.I,
        )
        if not leading:
            return False
        body = leading.group("body").lstrip()
        if body.startswith(","):
            modifier = re.match(
                r"^,\s*(?:even\s+)?(?:under|at|during|before|after)\s+"
                r"(?P<modifier>[^,]{1,120}),\s*(?P<rest>.*)$",
                body,
                re.I,
            )
            if not modifier or re.search(
                rf"\b(?:{verbs}|exists?|may|can|will|shall|must|should|is|are|does|do|has|have)\b",
                modifier.group("modifier"),
                re.I,
            ):
                return False
            body = modifier.group("rest").lstrip()
        governed = re.match(rf"{verbs}\b", body, re.I)
        if not governed:
            return False
        tail = body[governed.end():]
        coordinated = re.compile(
            rf"^(?:\s*,\s*(?:(?:and|or)\s+)?{verbs}\b|\s+(?:and|or)\s+{verbs}\b)*",
            re.I,
        )
        tail = tail[coordinated.match(tail).end():]
        return approved_object(tail)

    for label in ("development", "init", "worktrees", "status-conventions"):
        expected = manifests[label]
        if [index for index, _ in expected] != list(range(1, len(expected) + 1)):
            failure("paragraph-manifest", f"non-contiguous canonical indices for {label}")
            continue
        next_expected = 0
        for paragraph in normalized_paragraphs(doc_texts[label]):
            digest = hashlib.sha256(paragraph.encode("utf-8")).hexdigest()
            if next_expected < len(expected) and digest == expected[next_expected][1]:
                next_expected += 1
            elif not pure_prohibition(paragraph):
                failure("adoption-docs", f"non-canonical internal authority paragraph in {label}")
        if next_expected != len(expected):
            failure("adoption-docs", f"canonical internal authority paragraphs missing or reordered in {label}")

    internal_docs = "\n".join(
        doc_texts[name] for name in ("development", "init", "worktrees", "status-conventions")
    )
    for forbidden in (
        r"artifacts\.specPlan",
        r"LINEAR_API_KEY",
        r"Markdown\s+(?:is|as)\s+the\s+(?:compatible\s+)?default",
    ):
        if re.search(forbidden, internal_docs, re.I):
            failure("adoption-docs", f"restores removed dual-backend authority: {forbidden}")

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

expect_fixture_success() {
  local root="$1" label="$2" mode="${3:-fixture}" output
  if output="$(analyze_root "$root" "$mode" 2>&1)"; then
    pass
  else
    fail "$label: $output"
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

make_repository_fixture() {
  local destination="$1" relative
  make_fixture "$destination"
  while IFS= read -r relative; do
    mkdir -p "$destination/$(dirname "$relative")"
    cp "$ROOT/$relative" "$destination/$relative"
  done <<'EOF'
AGENTS.md
README.md
CONTRIBUTING.md
skills/woostack-bootstrap/references/development.md
skills/woostack-init/references/worktrees.md
skills/woostack-status/references/conventions.md
site/content/docs/index.mdx
site/content/docs/getting-started.mdx
site/content/docs/concepts.mdx
site/content/docs/configuration.mdx
site/content/docs/concepts/building-rules.mdx
site/content/docs/concepts/status-tracking.mdx
EOF
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
# expected tokens into today's six files.
fixture="$TMP_ROOT/duplicate-route"
make_fixture "$fixture"
printf '\n| `/woostack-init`, duplicate route | `woostack-init` |\n' \
  >> "$fixture/skills/using-woostack/SKILL.md"
expect_fixture_failure "$fixture" "ordered 23-command surface" "duplicate routing-row rejection"

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
expect_fixture_failure "$fixture" "ordered 23-command surface" "routing-row order rejection"

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
for reader in woostack-init woostack-doctor; do
  for family in specs plans fixes overnight; do
    for style in positive-use adjacent-list routine-open day-read; do
      fixture="$TMP_ROOT/compatibility-${reader}-${family}-${style}-bypass"
      make_fixture "$fixture"
      case "$style" in
        positive-use)
          printf '\nLegacy migration records must never be deleted before receipts. Use `.woostack/%s/` as ongoing workflow data.\n' "$family" \
            >> "$fixture/skills/$reader/SKILL.md"
          ;;
        adjacent-list)
          printf '\n- Legacy migration records are migration-only and must never be deleted\n- Adopt `.woostack/%s/` as production lifecycle state\n' "$family" \
            >> "$fixture/skills/$reader/SKILL.md"
          ;;
        routine-open)
          printf '\nLegacy material may only be migrated and must never be deleted during normal development. Open `.woostack/%s/` for routine use.\n' "$family" \
            >> "$fixture/skills/$reader/SKILL.md"
          ;;
        day-read)
          printf '\nLegacy records must never be deleted before receipts. Read `.woostack/%s/` as day-to-day workflow data.\n' "$family" \
            >> "$fixture/skills/$reader/SKILL.md"
          ;;
      esac
      expect_fixture_failure "$fixture" "undeclared positive legacy operation" \
        "$reader $family $style compatibility-scope rejection"
    done
  done

  for limiter in only solely exclusively; do
    fixture="$TMP_ROOT/compatibility-${reader}-${limiter}-control"
    make_fixture "$fixture"
    python3 - "$fixture/skills/$reader/SKILL.md" "$limiter" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace("for migration classification only.", f"{sys.argv[2]} for migration classification.")
path.write_text(text, encoding="utf-8")
PY
    expect_fixture_success "$fixture" "$reader $limiter migration declaration control"
  done
done

declaration_mutations=(duplicate missing-close nested wrong-reader wrong-operation missing-path extra-path scope-transfer)
for reader in woostack-init woostack-doctor; do
  for mutation in "${declaration_mutations[@]}"; do
    fixture="$TMP_ROOT/declaration-${reader}-${mutation}"
    make_fixture "$fixture"
    python3 - "$fixture/skills/$reader/SKILL.md" "$mutation" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
kind = sys.argv[2]
text = path.read_text(encoding="utf-8")
opening = text.index("<!-- woostack-legacy-compatibility ")
closing = text.index("<!-- /woostack-legacy-compatibility -->", opening)
end = closing + len("<!-- /woostack-legacy-compatibility -->")
declaration = text[opening:end]
if kind == "duplicate":
    text += "\n" + declaration + "\n"
elif kind == "missing-close":
    text = text[:closing] + text[end:]
elif kind == "nested":
    text = text[:closing] + declaration + "\n" + text[closing:]
elif kind == "wrong-reader":
    text = text[:opening] + declaration.replace(f'reader="{path.parent.name}"', 'reader="other"') + text[end:]
elif kind == "wrong-operation":
    text = text[:opening] + declaration.replace('operation="inspect"', 'operation="read"') + text[end:]
elif kind == "missing-path":
    text = text[:opening] + declaration.replace(".woostack/fixes/|", "") + text[end:]
elif kind == "extra-path":
    text = text[:opening] + declaration.replace('.woostack/overnight/"', '.woostack/overnight/|.woostack/extra/"') + text[end:]
elif kind == "scope-transfer":
    text += "\nRead `.woostack/specs/` exclusively for migration classification.\n"
path.write_text(text, encoding="utf-8")
PY
    expected="legacy compatibility declaration"
    [[ "$mutation" == scope-transfer ]] && expected="undeclared positive legacy operation"
    expect_fixture_failure "$fixture" "$expected" "$reader $mutation declaration rejection"
  done
done

internal_authority_mutations=(
  'Markdown remains the authoritative work ledger.'
  'Store feature state in version-controlled notes.'
  'Commit the specification and plan to the repo as the source of truth.'
  'Repository notes must never be deleted; they remain the authoritative work ledger.'
  'Our GraphQL requester handles Linear changes.'
  'Linear changes flow through a local HTTP bridge.'
  'Ignore the official host MCP and route Linear updates through our GraphQL requester.'
  'Linear uses our internal GraphQL requester, not the official host MCP.'
  'Do not hesitate to route Linear updates through our GraphQL requester.'
  'No repository notes are deleted, but Markdown remains authoritative.'
  'No objection exists and repository notes remain the authoritative work ledger.'
  'No matter what, repository notes remain the authoritative work ledger.'
  'Do not create repository state and our requester handles Linear.'
  'Do not create repository state while we use our requester for Linear.'
  'Do not create repository state plus use our requester for Linear.'
  'Do not create repository state thereby making Markdown authoritative.'
  'No objection exists and repository notes are authoritative.'
  'Never create repository state and Linear routes changes through our requester.'
  'Never create repository state and repository notes remain authoritative.'
  'Never create repository state, Linear routes changes through our requester.'
  'Never create repository state — Linear routes changes through our requester.'
  'Never create repository state with our requester handling Linear changes.'
  'Must not prevent use of our requester for Linear.'
  'Must not discourage use of our requester for Linear.'
  'Cannot block use of our requester for Linear.'
  'Does not rule out use of our requester for Linear.'
  'Never use official Linear MCP.'
  'Do not invoke the host official Linear MCP.'
  'Must not route Linear through official host MCP.'
  'Do not read executionApproved back.'
  'No objection to using a local HTTP bridge is allowed.'
  'No barrier to using repository notes as the authoritative ledger is allowed.'
  'No objection to Atlas using a local bridge is allowed.'
  'No objection to local transport is allowed.'
  "No objection to Linear's internal requester is allowed."
  'Must not disallow use of a local HTTP bridge.'
  'Must not ban use of repository notes as development authority.'
  'Must not hinder use of a local transport.'
  'Must not impede use of a local transport.'
  'Must not deter use of a local transport.'
  'Must not inhibit use of a local transport.'
  'Must not stop use of a local transport.'
  'Must not preclude use of a local transport.'
  'No advocacy for local transport is allowed.'
  'Never use official Linear MCP via a local bridge.'
  'Never call official Linear MCP through a local transport.'
  'Neither use official Linear MCP nor call it through a local bridge.'
  'Never create a ban on local transport.'
  'Never create restrictions on a local transport.'
  'Do not write a policy requiring repository notes as authority.'
  'Never create a Linear project record.'
  'Never use Linear project state.'
  'No Linear project record is created.'
)
for index in "${!internal_authority_mutations[@]}"; do
  fixture="$TMP_ROOT/internal-authority-bypass-$index"
  make_repository_fixture "$fixture"
  printf '\n%s\n' "${internal_authority_mutations[$index]}" \
    >> "$fixture/skills/woostack-init/references/worktrees.md"
  expect_fixture_failure "$fixture" "non-canonical internal authority paragraph" \
    "internal paragraph-manifest mutation rejection $index" repository
done

fixture="$TMP_ROOT/internal-authority-negative-controls"
make_repository_fixture "$fixture"
printf '\nNo repository notes are authoritative.\n\nDo not route Linear changes through a local HTTP bridge.\n\nNever, even under unusually prolonged operational pressure, treat checked-in Markdown or repository notes as authoritative development state.\n\nNever create, read, or write repository-local state.\n\nNo managed repository record is created, used, or opened.\n\nNeither create nor open a repository-local development artifact.\n\nNo local transport is allowed.\n\nNo custom Linear requester is used.\n\nNo checked-in Markdown plan is authoritative.\n\nNo repository-backed artifact is created.\n' \
  >> "$fixture/skills/woostack-init/references/worktrees.md"
expect_fixture_success "$fixture" "pure-prohibition alternate-authority controls" repository

fixture="$TMP_ROOT/manifest normalization with spaces"
make_repository_fixture "$fixture"
python3 - "$fixture/skills/woostack-init/references/worktrees.md" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
text = text.replace("single source of truth", "single   source\n    of truth", 1)
path.write_bytes(text.replace("\n", "\r\n").encode("utf-8"))
PY
expect_fixture_success "$fixture" "CRLF wrapping indentation and spaced-path normalization" repository

for mutation in delete reorder duplicate punctuation; do
  fixture="$TMP_ROOT/manifest-structure-$mutation"
  make_repository_fixture "$fixture"
  python3 - "$fixture/skills/woostack-init/references/worktrees.md" "$mutation" <<'PY'
import re
import sys
from pathlib import Path
path = Path(sys.argv[1])
kind = sys.argv[2]
text = path.read_text(encoding="utf-8")
paragraphs = re.split(r"(\n\s*\n)", text)
content = [index for index in range(0, len(paragraphs), 2) if paragraphs[index].strip()]
first, second = content[1], content[2]
if kind == "delete":
    paragraphs[first] = ""
elif kind == "reorder":
    paragraphs[first], paragraphs[second] = paragraphs[second], paragraphs[first]
elif kind == "duplicate":
    paragraphs.insert(second, paragraphs[first] + "\n\n")
elif kind == "punctuation":
    paragraphs[first] = paragraphs[first].replace(".", "!", 1)
path.write_text("".join(paragraphs), encoding="utf-8")
PY
  expect_fixture_failure "$fixture" "adoption-docs:" \
    "canonical paragraph $mutation rejection" repository
done


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
