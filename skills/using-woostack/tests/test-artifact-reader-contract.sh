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
  python3 - "$1" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
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

if failures:
    print("\n".join(failures))
    raise SystemExit(1)
print(f"discovered {len(discovered)} approved artifact surfaces; validated {len(read_only)} read-only readers")
PY
}

record_analysis() {
  local root="$1" label="$2" output
  if output="$(analyze_root "$root" 2>&1)"; then
    pass
  else
    fail "$label: $output"
  fi
}

expect_fixture_failure() {
  local root="$1" expected="$2" label="$3" output
  if output="$(analyze_root "$root" 2>&1)"; then
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
