#!/usr/bin/env bash
# Structural contract for explicit, read-only Linear context consumers.
# Provider behavior belongs to the host's official Linear MCP. This suite proves that
# utility skill packages cannot regain local development authority or adapter paths.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../woostack-init/scripts/tests/assert.sh"
set +e

ROOT="${WOOSTACK_READER_ROOT:-$(cd "$HERE/../../.." && pwd)}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/woostack-reader-contract.XXXXXX")" || exit 1
trap 'rm -rf -- "$TMP_ROOT"' EXIT HUP INT TERM

UTILITY_SKILLS=(
  woostack-ask
  woostack-debug
  woostack-tdd
  woostack-visualize
  woostack-dream
)

analyze_root() {
  python3 - "$1" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
skills_root = root / "skills"
utility_names = (
    "woostack-ask",
    "woostack-debug",
    "woostack-tdd",
    "woostack-visualize",
    "woostack-dream",
)
failures = []
texts = {}


def failure(name: str, message: str):
    failures.append(f"{name}: {message}")


def require(name: str, pattern: str, message: str, text=None):
    subject = re.sub(r"\s+", " ", texts.get(name, "") if text is None else text).strip()
    if not re.search(pattern, subject, re.I | re.S):
        failure(name, message)


def paragraphs(text: str):
    for raw in re.split(r"\n\s*\n", text):
        folded = re.sub(r"\s+", " ", raw).strip()
        if folded:
            yield folded


def policy_clauses(text: str):
    for paragraph in paragraphs(text):
        for clause in re.split(r"(?<=[.!?;])\s+", paragraph):
            clause = clause.strip()
            if clause:
                yield clause


def load_json(relative: str, label: str):
    path = root / relative
    if not path.is_file():
        failure(label, f"missing {relative}")
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        failure(label, f"invalid JSON in {relative}: {exc}")
        return None


def case_by_id(corpus, case_id: str, label: str):
    if not isinstance(corpus, dict) or not isinstance(corpus.get("cases"), list):
        failure(label, "corpus has no cases array")
        return None
    matches = [case for case in corpus["cases"] if isinstance(case, dict) and case.get("id") == case_id]
    if len(matches) != 1:
        failure(label, f"expected exactly one {case_id} case")
        return None
    return matches[0]


def assertion_map(case):
    if not isinstance(case, dict) or not isinstance(case.get("assertions"), list):
        return {}
    return {
        item.get("id"): item
        for item in case["assertions"]
        if isinstance(item, dict) and isinstance(item.get("id"), str)
    }


for name in utility_names:
    path = skills_root / name / "SKILL.md"
    if not path.is_file():
        failure(name, "SKILL.md is missing")
        texts[name] = ""
    else:
        texts[name] = path.read_text(encoding="utf-8")

# All five consumers share one fail-closed context path and link rather than duplicate its schemas.
common_requirements = (
    (r"\.\./woostack-init/references/artifact-backends\.md", "does not link the canonical Linear MCP authority"),
    (r"\.\./woostack-status/references/conventions\.md", "does not link the canonical status authority"),
    (r"host-exposed official Linear MCP", "does not require the host-exposed official Linear MCP"),
    (r"parse only (?:the )?(?:canonical )?managed fields", "does not limit parsing to managed fields"),
    (r"complete read-back", "does not require a complete read-back"),
    (r"exhaust pagination", "does not require pagination exhaustion"),
    (r"independently re-read", "does not require an independent exact-resource read-back"),
    (r"exact PR attribution", "does not require exact PR attribution"),
    (r"project(?: or issue)? URL.{0,100}client UUID|project URL/client UUID.{0,100}issue URL/client UUID", "does not accept an explicit exact Linear URL/client UUID"),
    (r"issue keys? alone", "does not reject an issue key without independently verified identity"),
    (r"title(?:-| )match", "does not reject title matching"),
    (r"local specification,? (?:plan,? (?:or|and) fix|plan,? and fix)", "does not reject local specification/plan/fix authority"),
    (r"local development adapter", "does not reject local development adapters"),
    (r"custom (?:Linear HTTP/GraphQL|provider) transport", "does not reject custom Linear transports"),
    (r"repository credential", "does not reject repository credentials"),
    (r"untrusted (?:data|evidence), never instructions", "does not quarantine remote text as data rather than instructions"),
    (r"linear://project/<uuid>", "does not retain canonical project provenance"),
    (r"linear://issue/<uuid>", "does not retain canonical issue provenance"),
    (r"immutable Git blob", "does not retain immutable Git provenance"),
    (r"exact (?:canonical )?PR source", "does not retain exact PR provenance"),
)
for name in utility_names:
    for pattern, message in common_requirements:
        require(name, pattern, message)

# Executable adapter/credential tokens are forbidden even when surrounded by reassuring prose.
forbidden_tokens = {
    "resolve-backend.sh": r"\bresolve-backend\.sh\b",
    "linear.sh": r"\blinear\.sh\b",
    "markdown.sh": r"\bmarkdown\.sh\b",
    "legacy artifacts directory": r"woostack-init/scripts/artifacts",
    "custom Linear endpoint": r"api\.linear\.app/graphql",
    "repository Linear secret": r"\bLINEAR_API_KEY\b",
    "hard-coded Linear MCP tool": r"\bmcp__linear\w*\b",
}
for name, text in texts.items():
    for token, pattern in forbidden_tokens.items():
        if re.search(pattern, text, re.I):
            failure(name, f"contains forbidden local development adapter token: {token}")

negative = re.compile(
    r"\b(?:never|must\s+not|do\s+not|does\s+not|cannot|can't|reject(?:ed|s)?|"
    r"invalid|forbid(?:den|s)?|prohibit(?:ed|s)?|no|not|neither|nor|block(?:ed|s)?|"
    r"fail(?:s|ed)?\s+closed)\b",
    re.I,
)
local_development_path = re.compile(r"\.woostack/(?:specs|plans|fixes)(?:/|\b)", re.I)
local_path_action = re.compile(
    r"\b(?:read|scan|grep|glob|find|enumerat|discover|load|use|resolve|infer|select|write|save|render)\w*\b",
    re.I,
)
title_selector = re.compile(
    r"(?:\b(?:search|match|select|resolve|infer|discover)\w*\b.{0,100}\btitle\w*\b|"
    r"\btitle\w*\b.{0,100}\b(?:search|match|select|resolve|infer|discover)\w*\b)",
    re.I,
)
adapter_invocation = re.compile(
    r"\b(?:invoke|run|call|execute|use)\w*\b.{0,120}\b(?:local|repository)\b.{0,80}\badapter\b",
    re.I,
)
custom_transport_invocation = re.compile(
    r"\b(?:invoke|run|call|execute|use)\w*\b.{0,120}\bcustom\b.{0,80}\b(?:GraphQL|transport)\b",
    re.I,
)
linear_mutation = re.compile(
    r"\b(?:create|edit|update|comment|assign|delegate|transition|relate|delete|mutat)\w*\b",
    re.I,
)
for name, text in texts.items():
    for clause in policy_clauses(text):
        if negative.search(clause):
            continue
        if local_development_path.search(clause) and local_path_action.search(clause):
            failure(name, "positively reads or writes a local development artifact")
        if title_selector.search(clause):
            failure(name, "positively selects managed context by title")
        if adapter_invocation.search(clause):
            failure(name, "positively invokes a local development adapter")
        if custom_transport_invocation.search(clause):
            failure(name, "positively invokes a custom Linear transport")
        if re.search(r"\b(?:Linear (?:resource|issue|project|comment)|provider)\b", clause, re.I) and linear_mutation.search(clause):
            failure(name, "contains an unguarded Linear/provider mutation path")

# Consumer-specific boundaries.
ask = texts.get("woostack-ask", "")
for pattern, message in (
    (r"<WRITE-BLOCK>", "is missing its repository/provider write block"),
    (r"code-only question stays code-only", "does not isolate code-only questions from development discovery"),
    (r"Ask never creates, edits, comments on, assigns, delegates, transitions, or\s+relates a Linear resource", "does not enumerate its read-only Linear boundary"),
    (r"terminal.{0,80}chain(?:s|ing)? nothing|chains nothing", "does not remain a terminal read-only handback"),
):
    require("woostack-ask", pattern, message, ask)


debug = texts.get("woostack-debug", "")
for pattern, message in (
    (r"<IRON-LAW>", "is missing the no-fix-without-root-cause law"),
    (r"this skill never\s+applies the fix", "does not prohibit applying a diagnostic fix"),
    (r"code/runtime target may be investigated without development context", "does not preserve code-only diagnosis"),
    (r"fix must independently re-verify", "does not make remediation re-verify the exact issue"),
    (r"Debug never creates, edits,\s*comments on, assigns, delegates, transitions, or relates a Linear resource", "does not enumerate its read-only Linear boundary"),
):
    require("woostack-debug", pattern, message, debug)


tdd = texts.get("woostack-tdd", "")
for pattern, message in (
    (r"role-`feature` project.{0,180}role-`increment` issue", "does not require the exact feature-project/increment-issue pair"),
    (r"project URL/client UUID plus exact issue URL/client\s+UUID", "does not require both explicit project and issue identities"),
    (r"test-only.{0,120}contract", "does not limit the handoff to an issue-owned test-only contract"),
    (r"woostack-execute", "does not route repository mutation through the canonical issue executor"),
    (r"isolated worktree", "does not require the issue executor to own the worktree"),
    (r"assignmentAccepted", "does not require the issue executor to verify assignment acceptance"),
    (r"verification.{0,120}precommitReview", "does not require current verification and precommit review receipts"),
    (r"no direct repository mutation", "does not prohibit direct TDD repository mutation"),
    (r"standalone (?:work-item|issue).{0,120}(?:not accepted|unsupported|blocks)", "does not reject standalone issue authority"),
    (r"no\s+Linear create, update, comment, assignment/delegation, transition, relation", "does not prohibit every Linear mutation class"),
):
    require("woostack-tdd", pattern, message, tdd)
for clause in policy_clauses(tdd):
    if negative.search(clause):
        continue
    if re.search(r"\bapp engineer\b.{0,120}\b(?:use|compare|match|equal)\w*\b.{0,80}\bassignee\b", clause, re.I):
        failure("woostack-tdd", "maps an app engineer to assignee instead of delegate")
    if re.search(r"\bhuman engineer\b.{0,120}\b(?:use|compare|match|equal)\w*\b.{0,80}\bdelegate\b", clause, re.I):
        failure("woostack-tdd", "maps a human engineer to delegate instead of assignee")
    if re.search(r"\b(?:issue-only|standalone issue)\b.{0,120}\b(?:sufficient|accepted|authoriz)\w*\b", clause, re.I):
        failure("woostack-tdd", "accepts issue-only authority without an exact feature project")


visualize = texts.get("woostack-visualize", "")
for pattern, message in (
    (r"\.woostack/visuals/YYYY-MM-DD-<slug>-<audience>\.html", "does not keep generated output in the disposable visuals surface"),
    (r"HTML is disposable", "does not classify generated HTML as disposable"),
    (r"never (?:authoritative|a specification, plan, fix, acceptance)", "allows generated HTML to become development authority"),
    (r"self-contained.{0,80}offline|offline.{0,80}self-contained", "does not require a self-contained offline render"),
    (r"Safely encode all remote text", "does not encode untrusted remote text before HTML insertion"),
    (r"No browser without consent", "does not require consent before opening a browser"),
    (r"Visualization never creates, edits, comments on, assigns, delegates,\s*transitions, or relates a Linear resource", "does not enumerate its read-only Linear boundary"),
):
    require("woostack-visualize", pattern, message, visualize)


dream = texts.get("woostack-dream", "")
for pattern, message in (
    (r"memory and wisdom remain local curation targets", "does not keep memory/wisdom as the local curation targets"),
    (r"context is read-only corroboration for local curation", "does not limit managed context to corroboration"),
    (r"never a curation target", "does not prohibit remote development content as a curation target"),
    (r"Sanitized `.woostack/respond/\*\.md` reports.{0,180}non-authoritative evidence", "does not classify sanitized diagnostic reports as local non-authoritative evidence"),
    (r"Never enumerate, read, join, or infer development context from `.woostack/specs/`,\s*`.woostack/plans/`, or `.woostack/fixes/`", "does not reject every local development corpus"),
    (r"Require explicit, unambiguous approval", "does not gate local writes on explicit approval"),
    (r"Do not touch local specifications, plans, fixes, remote resources", "does not constrain the approved apply phase"),
    (r"Dream never creates, edits,\s*comments on, assigns, delegates, transitions, relates, or deletes a Linear resource", "does not enumerate its read-only Linear boundary"),
):
    require("woostack-dream", pattern, message, dream)
for paragraph in paragraphs(dream):
    if negative.search(paragraph):
        continue
    if re.search(r"\b(?:Linear|remote)\b", paragraph, re.I) and re.search(
        r"\b(?:copy|convert|turn|promote|write)\w*\b.{0,100}\b(?:memory|wisdom)\b", paragraph, re.I
    ):
        failure("woostack-dream", "turns remote development text into local memory/wisdom")

# Behavior corpora cover one valid exact source and one rejected discovery/mutation request.
behavior_specs = {
    "woostack-ask": (
        "skills/woostack-ask/evals/evals.json",
        "valid-explicit-managed-context-is-read-only",
        "rejects-local-discovery-title-matching-and-adapters",
    ),
    "woostack-debug": (
        "skills/woostack-debug/evals/evals.json",
        "valid-exact-pr-context-traces-root-cause-read-only",
        "rejects-local-fix-title-match-adapter-and-mutation",
    ),
    "woostack-visualize": (
        "skills/woostack-visualize/evals/evals.json",
        "valid-explicit-project-renders-disposable-output",
        "rejects-local-plan-title-adapter-and-remote-mutation",
    ),
}
for name, (relative, valid_id, rejected_id) in behavior_specs.items():
    corpus = load_json(relative, name)
    if corpus is None:
        continue
    if corpus.get("schemaVersion") != 1 or corpus.get("skill") != name:
        failure(name, "behavior corpus identity/schema is invalid")
    valid = case_by_id(corpus, valid_id, name)
    rejected = case_by_id(corpus, rejected_id, name)
    if valid is not None:
        prompt = valid.get("prompt", "")
        for pattern, message in (
            (r"official-MCP", "valid case does not use official MCP facts"),
            (r"exhausted pagination", "valid case does not prove complete pagination"),
            (r"(?:direct|independent).{0,60}read-back", "valid case does not prove independent read-back"),
            (r"managed role-", "valid case does not identify a managed resource role"),
            (r"(?:remote|issue|readable).{0,120}(?:body|field).{0,300}(?:ignore|untrusted|treat)", "valid case does not exercise hostile remote text"),
            (r"localAdapterCalls", "valid case does not report adapter calls"),
            (r"linearMutationCount", "valid case does not report Linear mutations"),
        ):
            if not re.search(pattern, prompt, re.I | re.S):
                failure(name, message)
        assertions = assertion_map(valid)
        if not assertions or any(item.get("critical") is not True for item in assertions.values()):
            failure(name, "valid case assertions must all be critical")
    if rejected is not None:
        prompt = rejected.get("prompt", "")
        for pattern, message in (
            (r"\.woostack/(?:specs|plans|fixes)/", "rejected case does not exercise a local development path"),
            (r"title", "rejected case does not exercise title matching"),
            (r"adapter", "rejected case does not exercise an adapter request"),
            (r"(?:credential|token)", "rejected case does not exercise repository credentials"),
            (r"fallbackAllowed", "rejected case does not report fallback rejection"),
            (r"linearMutationCount", "rejected case does not report mutation rejection"),
        ):
            if not re.search(pattern, prompt, re.I):
                failure(name, message)
        assertions = assertion_map(rejected)
        if not assertions or any(item.get("critical") is not True for item in assertions.values()):
            failure(name, "rejected case assertions must all be critical")

ask_corpus = load_json("skills/woostack-ask/evals/evals.json", "woostack-ask")
ask_valid = case_by_id(ask_corpus, "valid-explicit-managed-context-is-read-only", "woostack-ask") if ask_corpus else None
if ask_valid:
    prompt = ask_valid.get("prompt", "")
    for token in (
        "11111111-1111-4111-8111-111111111111",
        "22222222-2222-4222-8222-222222222222",
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    ):
        if token not in prompt:
            failure("woostack-ask", f"valid case is missing exact source identity {token}")
    assertions = assertion_map(ask_valid)
    for assertion_id in (
        "valid-project-provenance",
        "valid-issue-provenance",
        "valid-code-provenance",
        "valid-complete-readback",
        "valid-remote-text-quarantined",
        "valid-zero-side-effects",
    ):
        if assertion_id not in assertions:
            failure("woostack-ask", f"valid case is missing {assertion_id}")


debug_corpus = load_json("skills/woostack-debug/evals/evals.json", "woostack-debug")
debug_valid = case_by_id(debug_corpus, "valid-exact-pr-context-traces-root-cause-read-only", "woostack-debug") if debug_corpus else None
if debug_valid:
    prompt = debug_valid.get("prompt", "")
    for pattern, message in (
        (r"Exact canonical PR https://github\.com/acme/widgets/pull/42", "valid PR case lacks an exact canonical PR"),
        (r"raw adjacent trailer pair.{0,160}Linear-Project:.{0,100}Linear-Issue:", "valid PR case lacks exact raw attribution trailers"),
        (r"11111111-1111-4111-8111-111111111111", "valid PR case lacks the exact project UUID"),
        (r"22222222-2222-4222-8222-222222222222", "valid PR case lacks the resolved issue UUID"),
    ):
        if not re.search(pattern, prompt, re.I | re.S):
            failure("woostack-debug", message)
    assertions = assertion_map(debug_valid)
    for assertion_id in (
        "valid-root-cause",
        "valid-project-provenance",
        "valid-issue-provenance",
        "valid-pr-source",
        "valid-readback",
        "valid-untrusted-text-ignored",
        "valid-debug-no-writes",
        "valid-debug-source-unchanged",
    ):
        if assertion_id not in assertions:
            failure("woostack-debug", f"valid case is missing {assertion_id}")


visualize_corpus = load_json("skills/woostack-visualize/evals/evals.json", "woostack-visualize")
visualize_valid = case_by_id(visualize_corpus, "valid-explicit-project-renders-disposable-output", "woostack-visualize") if visualize_corpus else None
if visualize_valid:
    prompt = visualize_valid.get("prompt", "")
    for pattern, message in (
        (r"exact project URL https://linear\.app/", "valid render case lacks an exact project URL"),
        (r"<script>.*fetch", "valid render case does not exercise hostile markup encoding"),
        (r"\.woostack/visuals/2026-07-27-cache-refresh-engineer\.html", "valid render case lacks a disposable output path"),
    ):
        if not re.search(pattern, prompt, re.I | re.S):
            failure("woostack-visualize", message)
    assertions = assertion_map(visualize_valid)
    for assertion_id in (
        "valid-visualize-provenance",
        "valid-visualize-readback",
        "valid-visualize-encoding",
        "valid-visualize-disposable",
        "valid-visualize-not-authority",
        "valid-visualize-no-side-effects",
    ):
        if assertion_id not in assertions:
            failure("woostack-visualize", f"valid case is missing {assertion_id}")

# Dream has a trigger corpus rather than a behavior corpus: it must select local curation, accept
# explicit read-only corroboration, and defer code questions/status/repairs to their owners.
dream_triggers = load_json("skills/woostack-dream/evals/trigger-evals.json", "woostack-dream")
if dream_triggers is not None:
    if dream_triggers.get("schemaVersion") != 1 or dream_triggers.get("skill") != "woostack-dream":
        failure("woostack-dream", "trigger corpus identity/schema is invalid")
    required_trigger_cases = {
        "local-memory-wisdom-curation": (True, "woostack-dream"),
        "verified-linear-context-corroborates-local-curation": (True, "woostack-dream"),
        "exact-linear-question-without-curation": (False, "woostack-ask"),
        "auth-migration-feature-board": (False, "woostack-status"),
        "workspace-structure-convention-repair": (False, "woostack-doctor"),
    }
    for case_id, (should_trigger, expected_skill) in required_trigger_cases.items():
        case = case_by_id(dream_triggers, case_id, "woostack-dream")
        if case is None:
            continue
        if case.get("shouldTrigger") is not should_trigger or case.get("expectedSkill") != expected_skill:
            failure("woostack-dream", f"trigger routing drift for {case_id}")
    corroboration = case_by_id(
        dream_triggers,
        "verified-linear-context-corroborates-local-curation",
        "woostack-dream",
    )
    if corroboration:
        query = corroboration.get("query", "")
        for pattern, message in (
            (r"exact Linear project UUID [0-9a-f-]{36}", "corroboration trigger lacks an exact project UUID"),
            (r"exact issue URL https://linear\.app/", "corroboration trigger lacks an exact issue URL"),
            (r"read-only corroboration", "corroboration trigger does not keep managed context read-only"),
            (r"keep the knowledge local", "corroboration trigger does not keep memory/wisdom local"),
            (r"without updating Linear or GitHub", "corroboration trigger does not reject remote mutation"),
        ):
            if not re.search(pattern, query, re.I):
                failure("woostack-dream", message)
    for case in dream_triggers.get("cases", []):
        if not isinstance(case, dict):
            continue
        if case.get("shouldTrigger") is True and re.search(r"\.woostack/(?:specs|plans|fixes)(?:/|\b)", case.get("query", ""), re.I):
            failure("woostack-dream", "positive trigger treats a local development artifact as curation input")

if failures:
    print("\n".join(failures))
    raise SystemExit(1)
print("validated 5 explicit Linear context consumers and their valid/rejected corpora")
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
  for skill in "${UTILITY_SKILLS[@]}"; do
    mkdir -p "$destination/skills/$skill"
    cp "$ROOT/skills/$skill/SKILL.md" "$destination/skills/$skill/SKILL.md"
  done
  for skill in woostack-ask woostack-debug woostack-visualize; do
    mkdir -p "$destination/skills/$skill/evals"
    cp "$ROOT/skills/$skill/evals/evals.json" "$destination/skills/$skill/evals/evals.json"
  done
  mkdir -p "$destination/skills/woostack-dream/evals"
  cp "$ROOT/skills/woostack-dream/evals/trigger-evals.json" \
    "$destination/skills/woostack-dream/evals/trigger-evals.json"
}

record_analysis "$ROOT" "repository utility reader contract"

fixture="$TMP_ROOT/local-adapter"
make_fixture "$fixture"
printf '\nInvoke `skills/woostack-init/scripts/artifacts/linear.sh identity-resolve` for the project.\n' \
  >> "$fixture/skills/woostack-ask/SKILL.md"
expect_fixture_failure "$fixture" "forbidden local development adapter token" \
  "local development adapter rejection"

fixture="$TMP_ROOT/local-plan-discovery"
make_fixture "$fixture"
printf '\nRead `.woostack/plans/cache.md` to select the active managed project.\n' \
  >> "$fixture/skills/woostack-visualize/SKILL.md"
expect_fixture_failure "$fixture" "positively reads or writes a local development artifact" \
  "local plan discovery rejection"

fixture="$TMP_ROOT/title-selection"
make_fixture "$fixture"
printf '\nSearch Linear and select the issue whose title most closely matches the failure.\n' \
  >> "$fixture/skills/woostack-debug/SKILL.md"
expect_fixture_failure "$fixture" "positively selects managed context by title" \
  "title matching rejection"

fixture="$TMP_ROOT/mixed-policy-title-selection"
make_fixture "$fixture"
printf '\nDo not infer an issue from a branch. Search Linear and select the issue whose title matches the target.\n' \
  >> "$fixture/skills/woostack-debug/SKILL.md"
expect_fixture_failure "$fixture" "positively selects managed context by title" \
  "mixed-policy title matching rejection"

fixture="$TMP_ROOT/remote-mutation"
make_fixture "$fixture"
printf '\nCreate a Linear comment containing the synthesized wisdom after curation.\n' \
  >> "$fixture/skills/woostack-dream/SKILL.md"
expect_fixture_failure "$fixture" "unguarded Linear/provider mutation path" \
  "read-only provider boundary"

fixture="$TMP_ROOT/tdd-owner-cross-type"
make_fixture "$fixture"
printf '\nFor an app engineer, compare the authenticated principal to the native issue assignee before editing tests.\n' \
  >> "$fixture/skills/woostack-tdd/SKILL.md"
expect_fixture_failure "$fixture" "maps an app engineer to assignee instead of delegate" \
  "type-aware TDD owner validation"


fixture="$TMP_ROOT/tdd-issue-only"
make_fixture "$fixture"
printf '\nAn issue-only input is sufficient authority to edit repository tests.\n' \
  >> "$fixture/skills/woostack-tdd/SKILL.md"
expect_fixture_failure "$fixture" "accepts issue-only authority without an exact feature project" \
  "TDD issue-plus-project requirement"
fixture="$TMP_ROOT/missing-rejected-eval"
make_fixture "$fixture"
python3 - "$fixture/skills/woostack-ask/evals/evals.json" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
data["cases"] = [case for case in data["cases"] if case["id"] != "rejects-local-discovery-title-matching-and-adapters"]
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
expect_fixture_failure "$fixture" "expected exactly one rejects-local-discovery-title-matching-and-adapters case" \
  "rejected input eval coverage"

fixture="$TMP_ROOT/dream-trigger-drift"
make_fixture "$fixture"
python3 - "$fixture/skills/woostack-dream/evals/trigger-evals.json" <<'PY'
import json
import sys
from pathlib import Path
path = Path(sys.argv[1])
data = json.loads(path.read_text(encoding="utf-8"))
for case in data["cases"]:
    if case["id"] == "verified-linear-context-corroborates-local-curation":
        case["shouldTrigger"] = False
path.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
PY
expect_fixture_failure "$fixture" "trigger routing drift for verified-linear-context-corroborates-local-curation" \
  "verified corroboration trigger coverage"

finish
