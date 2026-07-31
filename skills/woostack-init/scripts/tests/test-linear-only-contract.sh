#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../../.." && pwd)"
export ROOT

python3 <<'PY'
import json
import os
import re
from pathlib import Path

root = Path(os.environ["ROOT"])
self_relative = "skills/woostack-init/scripts/tests/test-linear-only-contract.sh"
canonical_relative = "skills/woostack-init/references/artifact-backends.md"
canonical_path = root / canonical_relative
config_relatives = (
    ".woostack/config.json",
    "skills/woostack-init/templates/config.json",
)
root_doc_relatives = ("AGENTS.md", "README.md", "CONTRIBUTING.md")

retired_adapter_filenames = (
    "resolve-backend.sh",
    "markdown.sh",
    "linear.sh",
    "linear-request.sh",
    "linear-preflight.sh",
    "linear-metadata.py",
    "graphql-operation.py",
)
retired_graphql_filenames = (
    "document-create.graphql",
    "document-list.graphql",
    "document-update.graphql",
    "identity-document-slug.graphql",
    "identity-document.graphql",
    "identity-issue-key.graphql",
    "identity-issue.graphql",
    "identity-project-slug.graphql",
    "identity-project.graphql",
    "issue-create.graphql",
    "issue-list.graphql",
    "issue-relations.graphql",
    "issue-update.graphql",
    "preflight.graphql",
    "project-create.graphql",
    "project-list.graphql",
    "project-update.graphql",
    "provenance-document.graphql",
    "provenance-issue.graphql",
    "relation-create.graphql",
    "relation-delete.graphql",
)
retired_paths = (
    tuple(
        f"skills/woostack-init/scripts/artifacts/{filename}"
        for filename in retired_adapter_filenames
    )
    + tuple(
        f"skills/woostack-init/scripts/artifacts/graphql/{filename}"
        for filename in retired_graphql_filenames
    )
    + (
        "skills/woostack-init/scripts/tests/test-artifact-backends.sh",
        "skills/woostack-init/scripts/tests/test-linear-transport.sh",
        "skills/woostack-init/scripts/tests/test-linear-resources.sh",
        "skills/woostack-init/scripts/tests/test-linear-metadata.sh",
        "skills/woostack-review/scripts/parse-artifact-trailers.py",
        "skills/woostack-review/scripts/resolve-intent.sh",
        "skills/woostack-review/scripts/tests/test-resolve-intent.sh",
        "skills/woostack-doctor/scripts/checks/doc-type.sh",
        "skills/woostack-doctor/scripts/checks/plan-source.sh",
        "skills/woostack-doctor/scripts/checks/spec-plan-backlink.sh",
        "skills/woostack-doctor/scripts/checks/status-band.sh",
        "skills/woostack-doctor/scripts/checks/status-enum.sh",
        "skills/woostack-doctor/scripts/tests/test-doc-type.sh",
        "skills/woostack-doctor/scripts/tests/test-plan-source.sh",
        "skills/woostack-doctor/scripts/tests/test-repair-apply.sh",
        "skills/woostack-doctor/scripts/tests/test-spec-plan-backlink.sh",
        "skills/woostack-doctor/scripts/tests/test-status-band.sh",
        "skills/woostack-doctor/scripts/tests/test-status-enum.sh",
        "skills/woostack-doctor/scripts/tests/test-linear-backend.sh",
    )
)
retired_path_set = set(retired_paths)
findings: list[str] = []


def check_configs() -> None:
    expected_linear = {"repository", "workspace", "team", "projectStatuses", "issueStates"}
    expected_project = {"backlog", "planned", "started", "paused", "completed", "canceled"}
    expected_issue = {"planned", "executing", "inReview", "done", "blocked"}
    credential = re.compile(
        r"(?:api.?key|token|secret|password|authorization|credential)", re.I
    )

    for relative in config_relatives:
        path = root / relative
        if not path.is_file():
            findings.append(f"{relative}: required Linear policy configuration is missing")
            continue
        try:
            data = json.loads(path.read_text())
        except (OSError, json.JSONDecodeError) as error:
            findings.append(f"{relative}: unreadable Linear policy configuration: {error}")
            continue
        if "artifacts" in data:
            findings.append(f"{relative}: artifacts.specPlan/backend selector remains active")
        linear = data.get("linear")
        if not isinstance(linear, dict) or set(linear) != expected_linear:
            findings.append(
                f"{relative}: linear policy keys must be exactly {sorted(expected_linear)!r}"
            )
            continue
        if set(linear["projectStatuses"]) != expected_project:
            findings.append(f"{relative}: projectStatuses keys are not canonical")
        if set(linear["issueStates"]) != expected_issue:
            findings.append(f"{relative}: issueStates keys are not canonical")
        for key in linear:
            if credential.search(key):
                findings.append(f"{relative}: credential-like linear key {key!r}")


prose_suffixes = {".md", ".mdx", ".html", ".json", ".txt", ".yml", ".yaml"}
script_suffixes = {".sh", ".py", ".js", ".mjs", ".cjs", ".ts", ".graphql", ".gql"}
excluded_skill_corpus_roots = {"evals", "fixtures", "history", "migrations", "tests"}
workspace_history_prefixes = (
    ".woostack/specs/",
    ".woostack/plans/",
    ".woostack/fixes/",
    ".woostack/overnight/",
    ".woostack/migrations/",
)


def active_surface_kind(relative: str) -> str | None:
    """Return the shipped active surface kind, or None for input data/history/migrations."""
    if relative == self_relative:
        return None
    if relative in retired_path_set:
        return None
    if relative in config_relatives:
        return "configuration"
    if relative in root_doc_relatives:
        return "root document"
    if relative.startswith(workspace_history_prefixes):
        # Legacy development records and migration inputs are retained history, not authority.
        return None
    if relative.startswith(".woostack/"):
        # Other workspace-local knowledge and tooling state are not shipped active surfaces.
        return None
    if relative in {"action.yml", ".github/workflows/reusable-review.yml"}:
        return "action"

    parts = relative.split("/")
    suffix = Path(relative).suffix.lower()
    if parts[:3] == ["site", "content", "docs"]:
        if len(parts) > 3 and parts[3] == "skills":
            # Per-skill pages are generated from SKILL.md and are not an authored surface.
            return None
        return "authored site" if suffix in prose_suffixes else None

    if len(parts) < 3 or parts[0] != "skills":
        return None
    if parts[2] == "templates":
        # Templates become live consumer files, so every shipped template is active even when
        # its filename has no extension (for example, templates/gitignore).
        return "generated-source template"
    if parts[2] in excluded_skill_corpus_roots:
        return None
    if parts[-1] == "SKILL.md":
        return "skill"
    if parts[2] == "references" and suffix in prose_suffixes:
        return "reference"
    if parts[2] == "prompts" and suffix in prose_suffixes:
        return "prompt"
    if parts[2] == "scripts":
        tail = parts[3:]
        # Test and fixture corpora deliberately quote rejected inputs. Deleted compatibility
        # tests are pinned above; only runtime scripts are part of the active transport surface.
        if "tests" in tail or "fixtures" in tail:
            return None
        if suffix in script_suffixes or not suffix:
            return "script"
    return None


retired_adapter_re = re.compile(
    r"(?<![A-Za-z0-9_.-])(?:"
    + "|".join(re.escape(name) for name in retired_adapter_filenames)
    + r")(?![A-Za-z0-9_.-])",
    re.I,
)
retired_graphql_re = re.compile(
    r"(?<![A-Za-z0-9_.-])(?:"
    + "|".join(re.escape(name) for name in retired_graphql_filenames)
    + r")(?![A-Za-z0-9_.-])",
    re.I,
)
graphql_document_re = re.compile(
    r"(?<![A-Za-z0-9_.-])[A-Za-z0-9_.-]+\.(?:graphql|gql)(?![A-Za-z0-9_.-])",
    re.I,
)
backend_rules = (
    (re.compile(r"\bartifacts\.specPlan\b", re.I), False),
    (re.compile(r"(?<![A-Za-z0-9_.-])specPlan(?![A-Za-z0-9_.-])", re.I), False),
    (
        re.compile(
            r"(?<![A-Za-z0-9_.-])(?:WOOSTACK_)?"
            r"(?:ARTIFACT|ARTIFACTS|SPEC_PLAN)_BACKEND(?![A-Za-z0-9_.-])",
            re.I,
        ),
        False,
    ),
    (
        re.compile(
            r"\b(?:Markdown|Linear)\s+(?:artifact\s+|development\s+)?backend\b",
            re.I,
        ),
        False,
    ),
    (
        re.compile(
            r"\bbackend(?:\s+mode)?\s*(?:(?:==|=|:)\s*|\bis\s+)"
            r"[`\"']?(?:markdown|linear)\b",
            re.I,
        ),
        False,
    ),
    (re.compile(r"--(?:artifact-|spec-plan-)?backend\b", re.I), True),
    (
        re.compile(
            r"\b(?:selected|resolved|configured|chosen)\s+"
            r"(?:artifact\s+|development\s+|spec(?:ification)?(?:/plan)?\s+)?backend\b",
            re.I,
        ),
        True,
    ),
    (
        re.compile(
            r"\b(?:artifact|development|spec(?:ification)?(?:/plan)?)"
            r"[- ]backend\b",
            re.I,
        ),
        False,
    ),
    (re.compile(r"\bbackend\s+(?:selection|resolution|selectors?|resolver)\b", re.I), True),
    (re.compile(r"\bbackend-specific\b", re.I), True),
    (
        re.compile(
            r"\b(?:choose|select|resolve|switch)\s+(?:the\s+)?"
            r"(?:artifact\s+|development\s+|spec(?:ification)?(?:/plan)?\s+)?backend\b",
            re.I,
        ),
        True,
    ),
)
backend_context_re = re.compile(
    r"\b(?:artifact|specification|spec|plan|development|Markdown|Linear|woostack)\b"
    r"|\.woostack/",
    re.I,
)
linear_credential_re = re.compile(
    r"\bLINEAR_(?:[A-Z0-9]+_)*(?:KEY|TOKEN|SECRET)\b",
    re.I,
)
linear_sdk_client_re = re.compile(
    r"(?<![A-Za-z0-9_.-])@linear/sdk(?![A-Za-z0-9_.-])"
    r"|(?<![A-Za-z0-9_])LinearClient(?![A-Za-z0-9_])"
    r"|(?<![A-Za-z0-9_])linear[_-]?client(?![A-Za-z0-9_])",
    re.I,
)
hard_coded_linear_mcp_tool_re = re.compile(
    r"(?<![A-Za-z0-9_])mcp__linear_[A-Za-z0-9_]+(?![A-Za-z0-9_])",
    re.I,
)
linear_endpoint_re = re.compile(r"(?:https?://)?api\.linear\.app(?:/graphql)?(?:\b|/)", re.I)
linear_custom_transport_re = re.compile(
    r"\b(?:"
    r"Linear\s+(?:HTTP\s*(?:/|or)\s*)?GraphQL(?:\s+(?:transport|client|request|"
    r"query|mutation|operation|endpoint)s?)?"
    r"|custom\s+Linear\s+(?:(?:HTTP|GraphQL)\s*(?:/|or)\s*)?"
    r"(?:HTTP|GraphQL|endpoint|transport|client|request|operation)"
    r"|GraphQL\s+(?:transport|client|request|query|mutation|operation)s?"
    r"\s+(?:for|against)\s+Linear"
    r")\b",
    re.I,
)
linear_document_re = re.compile(
    r"\b(?:"
    r"Linear\s+documents?"
    r"|managed\s+(?:Linear\s+)?documents?"
    r"|(?:specification|spec)[ -]documents?"
    r"|document-backed\s+(?:specification|spec|feature|development state)"
    r")\b",
    re.I,
)
graphql_operation_re = re.compile(
    r"(?:\b(?:query|mutation)\s*(?:[A-Za-z_][A-Za-z0-9_]*\s*)?\("
    r"|\b(?:query|mutation)\s+[A-Za-z_][A-Za-z0-9_]*\s*\{"
    r"|\b(?:query|mutation)\s*\{"
    r"|--operation\s+(?:query|mutation)\b"
    r"|\brequest_(?:query|mutation)\b"
    r"|\bGRAPHQL_(?:QUERY|MUTATION|DOCUMENT)\b)",
    re.I,
)
linear_context_re = re.compile(
    r"\bLinear\b|api\.linear\.app|\bLINEAR_[A-Z0-9_]+\b|"
    r"(?:^|/)[^/\s]*linear[^/\s]*(?:/|$)",
    re.I,
)
linear_provider_marker_re = re.compile(r"\bLinear\b|\bLINEAR_[A-Z0-9_]+\b", re.I)
linear_graphql_schema_operation_re = re.compile(
    r"(?<![A-Za-z0-9_])(?:"
    r"(?:issue|project)(?:Create|Update|Archive|Unarchive|Delete|AddLabel|RemoveLabel)"
    r"|(?:Issue|Project)(?:Create|Update|Archive|Unarchive|Delete)Input"
    r")(?![A-Za-z0-9_])",
    re.I,
)
explicit_github_graphql_re = re.compile(
    r"\bGitHub\s+GraphQL\b|\bgh\s+api\s+graphql\b|github\.com/graphql", re.I
)
github_graphql_paths = (
    "skills/woostack-review/scripts/",
    "skills/woostack-address-comments/scripts/",
    "action.yml",
    ".github/workflows/reusable-review.yml",
)
local_strong_re = re.compile(
    r"(?:"
    r"\.woostack/(?:specs|plans|fixes|overnight)(?:/|(?=[`'\"\s),]|$))"
    r"|\[\[(?:specs|plans|fixes|overnight)/"
    r"|<(?:spec|plan|fix|overnight)-path>"
    r")",
    re.I,
)
local_noun_re = re.compile(
    r"\blocal\s+(?:"
    r"specifications?|specs?|plans?|fix(?:es)?|"
    r"overnight(?:\s+(?:execution|run|report|record))?"
    r")(?:\s+(?:path|file|record|artifact|authority))?\b",
    re.I,
)
retired_overnight_report_re = re.compile(
    r"\b(?:local\s+)?(?:morning|overnight)\s+reports?\b",
    re.I,
)
local_action_re = re.compile(
    r"\b(?:read|load|open|discover|enumerate|scan|find|join|resolve|consume|parse|"
    r"render|write|create|author|update|edit|save|store|persist|append|execute|"
    r"invoke|run|delegate|tick|resume|continue|derive|select|use|own|determine)"
    r"(?:s|d|ed|ing)?\b|source of truth|development (?:state|authority)|authoritative|\bauthority\b",
    re.I,
)
local_mutating_authority_re = re.compile(
    r"\b(?:write|create|author|update|edit|save|store|persist|append|execute|"
    r"invoke|run|delegate|tick|resume|continue|own|determine|select)"
    r"(?:s|d|ed|ing)?\b|source of truth|authoritative|development authority",
    re.I,
)
migration_context_re = re.compile(
    r"\b(?:legacy|historical|one-way migration|migration (?:input|record|records|"
    r"diagnosis|classification|cleanup|receipt)|classif(?:y|ies|ied|ication)|"
    r"detect(?:s|ed|ing|ion)?|diagnos(?:e|es|ed|is|tic)|"
    r"block(?:s|ed|ing)?|archive|recoverable from Git)\b",
    re.I,
)
spec_token_re = re.compile(r"(?<![A-Za-z0-9_-])Spec:")
spec_value_re = re.compile(
    r"\s*`?\s*(?:"
    r"\.woostack/(?:specs|plans|fixes)/"
    r"|(?:specs|plans|fixes)/[^\s`]+"
    r"|<[^>]*(?:spec|path)[^>]*>"
    r"|\{\{[^}]*(?:SPEC|PATH)[^}]*\}\}"
    r"|[^\s`\"']+\.md\b"
    r")",
    re.I,
)
spec_trailer_context_re = re.compile(
    r"\b(?:PR|pull request|trailer|attribution|body suffix|final suffix|"
    r"starts?with|ends?with|grep|regular expression|regex|re\.(?:search|match))\b",
    re.I,
)
spec_rejection_context_re = re.compile(
    r"\b(?:reject(?:s|ed|ing)?|rejection|forbid(?:s|ding|den)?|"
    r"block(?:s|ed|ing|er)?|guard(?:s|ed|ing)?(?:\s+passes?)?)\b",
    re.I,
)
spec_affirmative_before_re = re.compile(
    r"(?:^|[,:]\s*|\b(?:we|they|it|(?:(?:the|a|this)\s+)?"
    r"(?:agent|workflow|repository|skill|command|script))\s+)"
    r"(?:(?:please|always|directly|then)\s+)*"
    r"(?:accept(?:s|ed|ing)?|append(?:s|ed|ing)?|consum(?:e|es|ed|ing)|"
    r"cop(?:y|ies|ied|ying)|creat(?:e|es|ed|ing)|load(?:s|ed|ing)?|"
    r"normaliz(?:e|es|ed|ing)|read(?:s|ing)?|repair(?:s|ed|ing)?|"
    r"rewrit(?:e|es|ing|ten)|translat(?:e|es|ed|ing)|"
    r"us(?:e|es|ed|ing)|writ(?:e|es|ing|ten))\b.{0,120}$",
    re.I | re.S,
)

clause_boundary_re = re.compile(
    r"(?:[;!?]|\.(?=\s|$))\s*"
    r"|(?:,\s*)?\b(?:but|however|yet|whereas|although|except|instead|then)\b"
    r"(?:,\s*)?"
    r"|\n(?=\s*(?:#{1,6}\s|[-*+]\s|\d+\.\s|\||```))",
    re.I,
)
negative_before_re = re.compile(
    r"(?:"
    r"\b(?:never|cannot|can't|must\s+not|mustn't|should\s+not|shouldn't|"
    r"may\s+not|do\s+not|don't|does\s+not|doesn't|did\s+not|won't)\b"
    r"|\bneither\b"
    r"|(?:^|[:(]\s*)no\b"
    r"|\b(?:there\s+(?:is|are)|has|have|with|accepts?|contains?|requires?|uses?|"
    r"creates?|reads?|writes?|allows?|supports?)\s+no\b"
    r"|\bno\s+(?:alternate|local|development|artifact|backend|repository|"
    r"Linear|custom|Markdown|Spec)\b"
    r"|\bno\s*[`'\"]?\s*$"
    r"|\bnot\s*[`'\"]?\s*$"
    r")",
    re.I,
)
scoped_rejection_before_re = re.compile(
    r"(?:"
    r"\b(?:forbid|reject|disallow|prohibit|prevent)(?:s|ed|ing)?\b"
    r"|\b(?:remove|retire|decommission|eliminate)(?:s|d|ed|ing)?\b"
    r"|\b(?:removed|retired|obsolete|unsupported|forbidden)\b"
    r"(?:\s+(?:adapter|path|transport|credential|selector|backend|document|"
    r"trailer|field|variable|filename))?\s*$"
    r"|\b(?:scrub(?:s|bed|bing)?|unset|strip(?:s|ped|ping)?|"
    r"redact(?:s|ed|ing)?|drop(?:s|ped|ping)?|omit(?:s|ted|ting)?|"
    r"exclude(?:s|d|ing)?)\b"
    r"|\bmigrat(?:e|es|ed|ing)\s+(?:away\s+from|off)\b"
    r"|\bwithout\b"
    r")",
    re.I,
)
positive_action_re = re.compile(
    r"\b(?:"
    r"accept(?:s|ed|ing)?|append(?:s|ed|ing)?|author(?:s|ed|ing)?|"
    r"call(?:s|ed|ing)?|consum(?:e|es|ed|ing)|creat(?:e|es|ed|ing)|"
    r"invok(?:e|es|ed|ing)|load(?:s|ed|ing)?|persist(?:s|ed|ing)?|"
    r"read(?:s|ing)?|requir(?:e|es|ed|ing)|resolv(?:e|es|ed|ing)|"
    r"run(?:s|ning)?|select(?:s|ed|ing)?|us(?:e|es|ed|ing)|"
    r"writ(?:e|es|ing|ten)"
    r")\b",
    re.I,
)
negative_after_re = re.compile(
    r"(?:"
    r"^\s*`?\s*(?:(?:adapters?|paths?|transports?|credentials?|selectors?|"
    r"backends?|documents?|trailers?|fields?|variables?|filenames?|URIs?)\s+)?"
    r"(?:is|are|was|were|be|been|remains?)\s+(?:explicitly\s+)?"
    r"(?:forbidden|prohibited|unsupported|removed|retired|obsolete|rejected|"
    r"disallowed|not\s+(?:accepted|required|supported|allowed|permitted|used|"
    r"invoked|read|written|authored|consumed|created))\b"
    r"|^\s*(?:has|have|was|were)\s+been\s+(?:removed|retired|rejected)\b"
    r"|^.{0,100}\b(?:must\s+not|should\s+not|may\s+not)\s+"
    r"(?:be\s+)?(?:used|invoked|read|written|authored|consumed|accepted|required)\b"
    r"|^.{0,160}\bnever\s+(?:provide|determine|select|supplement|discover|"
    r"author|consume|invoke|read|write|create|be\s+used|be\s+read|"
    r"be\s+written|be\s+authored|be\s+consumed)\w*\b"
    r"|^.{0,220}\b(?:is|are)\s+invalid\b"
    r"|^.{0,220}\bblocks?\s+before\b"
    r"|^.{0,260}\b(?:fails?|blocks?)\s+closed\b"
    r")",
    re.I | re.S,
)
authority_disclaimer_after_re = re.compile(
    r"(?:"
    r"^.{0,220}\b(?:is|are|was|were)\s+not\s+(?:a\s+)?(?:development\s+)?"
    r"(?:authority|authoritative|source of truth|(?:new\s+)?provenance|"
    r"(?:development\s+|status\s+)?inputs?)\b"
    r"|^.{0,220}\b(?:is|are|was|were)\s+never\s+"
    r"(?:development\s+|status\s+)?(?:inputs?|authority|authoritative|source of truth)\b"
    r"|^.{0,220}\b(?:is|are|was|were)\s+(?:explicitly\s+)?non-authoritative\b"
    r"|^.{0,320}\bnever\s+becomes?\s+(?:scope|lifecycle|development)"
    r".{0,100}\bauthority\b"
    r"|^.{0,220}\b(?:never\s+)?(?:serves?|acts?|functions?)\s+as\s+"
    r"(?:a\s+)?(?:development\s+)?(?:authority|source of truth)\b"
    r"|^.{0,220}\b(?:stays?|remains?|is|are|was|were)\s+"
    r"(?:(?:strictly|only)\s+)?(?:host|provider)[ -]owned\b"
    r"|^\s*(?:is|are|was|were)?\s*not\s+(?:a\s+)?(?:development\s+)?"
    r"(?:authority|authoritative|source of truth)\b"
    r"|^\s*(?:is|are|was|were)?\s*migration input only\b"
    r")",
    re.I | re.S,
)


def context_for(lines: list[str], index: int, kind: str) -> tuple[str, int]:
    if kind not in {"skill", "reference", "prompt", "authored site", "root document"}:
        return lines[index], 0
    start = index
    for candidate in range(index - 1, max(-1, index - 3), -1):
        if not lines[candidate].strip():
            break
        start = candidate
    end = index + 1
    for candidate in range(index + 1, min(len(lines), index + 3)):
        if not lines[candidate].strip():
            break
        end = candidate + 1
    selected = lines[start:end]
    return "\n".join(selected), sum(len(line) + 1 for line in selected[: index - start])


def clause_for(context: str, start: int, end: int) -> tuple[str, int, int]:
    left = 0
    right = len(context)
    for boundary in clause_boundary_re.finditer(context):
        if boundary.group(0).lstrip().startswith(";"):
            prefix = context[max(0, boundary.start() - 320):boundary.start()]
            suffix = context[boundary.end():boundary.end() + 180]
            continued_negative_list = bool(
                negative_before_re.search(prefix)
                and re.match(
                    r"\s*(?:a|an|the|or|local|Linear|repository|custom|provider)\b",
                    suffix,
                    re.I,
                )
            )
            continued_table_reality = bool(
                context.lstrip().startswith("|")
                and re.match(r"\s*(?:local|those|it|they|this)\b", suffix, re.I)
                and re.search(
                    r"\b(?:never|cannot|must\s+not|does\s+not|is\s+not|are\s+not)\b",
                    suffix,
                    re.I,
                )
            )
            if continued_negative_list or continued_table_reality:
                continue
        if boundary.end() <= start:
            left = boundary.end()
        elif boundary.start() >= end:
            right = boundary.start()
            break
    return context[left:right], start - left, end - left


def policy_negative(context: str, start: int, end: int) -> bool:
    clause, local_start, local_end = clause_for(context, start, end)
    before = clause[max(0, local_start - 260):local_start]
    after = clause[local_end:local_end + 260]
    if negative_before_re.search(before) or negative_after_re.search(after):
        return True
    if (
        authority_disclaimer_after_re.search(after)
        and not positive_action_re.search(before)
    ):
        return True
    return any(
        not positive_action_re.search(before[rejection.end():])
        for rejection in scoped_rejection_before_re.finditer(before)
    )


def spec_trailer_exception(context: str, start: int, end: int) -> bool:
    clause, local_start, _ = clause_for(context, start, end)
    before = clause[max(0, local_start - 260):local_start]
    if spec_affirmative_before_re.search(before):
        return False
    if policy_negative(context, start, end):
        return True
    return bool(spec_rejection_context_re.search(clause))


def linear_document_exception(context: str, start: int, end: int) -> bool:
    if policy_negative(context, start, end):
        return True
    clause, _, _ = clause_for(context, start, end)
    return bool(
        migration_context_re.search(clause)
        and not local_mutating_authority_re.search(clause)
    )


def local_exception(relative: str, context: str, start: int, end: int, line: str) -> bool:
    if policy_negative(context, start, end):
        return True
    clause, _, _ = clause_for(context, start, end)
    if (
        relative == "skills/woostack-doctor/scripts/checks/memory.sh"
        and re.search(
            r"\.woostack/specs/\*\|\.woostack/plans/\*\|\.woostack/fixes/\*", line
        )
    ):
        return True
    if migration_context_re.search(clause) and not local_mutating_authority_re.search(clause):
        return True
    return False


def active_linear_provider_evidence(context: str) -> bool:
    for pattern in (
        linear_endpoint_re,
        linear_sdk_client_re,
        linear_custom_transport_re,
        linear_credential_re,
        linear_graphql_schema_operation_re,
        linear_provider_marker_re,
    ):
        for match in pattern.finditer(context):
            if not policy_negative(context, match.start(), match.end()):
                return True
    return False


def github_graphql_context(relative: str, context: str) -> bool:
    if active_linear_provider_evidence(context):
        return False
    review_path = any(
        relative == prefix or relative.startswith(prefix)
        for prefix in github_graphql_paths
    )
    return bool(
        explicit_github_graphql_re.search(context)
        or (
            review_path
            and re.search(r"\breviewThreads?\b|\bpullRequest\s*\(", context, re.I)
        )
    )


def classify_line(
    relative: str,
    line: str,
    context: str,
    line_start: int,
) -> set[str]:
    labels: set[str] = set()

    def active(match: re.Match[str]) -> bool:
        return not policy_negative(
            context, line_start + match.start(), line_start + match.end()
        )

    for match in hard_coded_linear_mcp_tool_re.finditer(line):
        labels.add("hard-coded official Linear MCP tool name")
    for match in retired_adapter_re.finditer(line):
        if active(match):
            labels.add("retired adapter reference")
    for match in retired_graphql_re.finditer(line):
        if active(match):
            labels.add("retired Linear GraphQL document")
    for pattern, requires_context in backend_rules:
        for match in pattern.finditer(line):
            absolute_start = line_start + match.start()
            absolute_end = line_start + match.end()
            clause, _, _ = clause_for(context, absolute_start, absolute_end)
            if (
                relative == "skills/woostack-doctor/references/checks.md"
                and line.lstrip().startswith("| `linear-policy` |")
            ):
                continue
            if requires_context and not backend_context_re.search(clause):
                continue
            if not policy_negative(context, absolute_start, absolute_end):
                labels.add("backend selector")
    for match in linear_credential_re.finditer(line):
        if active(match):
            labels.add("repository Linear credential")
    for match in linear_sdk_client_re.finditer(line):
        if active(match):
            labels.add("custom Linear GraphQL transport")
    for match in linear_endpoint_re.finditer(line):
        if active(match):
            labels.add("custom Linear GraphQL endpoint")
    for match in linear_custom_transport_re.finditer(line):
        if active(match):
            labels.add("custom Linear GraphQL transport")
    for match in linear_document_re.finditer(line):
        absolute_start = line_start + match.start()
        absolute_end = line_start + match.end()
        if not linear_document_exception(context, absolute_start, absolute_end):
            labels.add("Linear document dependency")

    for match in graphql_operation_re.finditer(line):
        absolute_start = line_start + match.start()
        absolute_end = line_start + match.end()
        clause, _, _ = clause_for(context, absolute_start, absolute_end)
        if not (
            linear_context_re.search(relative + "\n" + clause)
            or active_linear_provider_evidence(clause)
        ):
            continue
        if github_graphql_context(relative, clause):
            continue
        if not policy_negative(context, absolute_start, absolute_end):
            labels.add("custom Linear GraphQL operation")
    for match in graphql_document_re.finditer(line):
        if retired_graphql_re.fullmatch(match.group(0)):
            continue
        absolute_start = line_start + match.start()
        absolute_end = line_start + match.end()
        clause, _, _ = clause_for(context, absolute_start, absolute_end)
        if not (
            linear_context_re.search(relative + "\n" + clause)
            or active_linear_provider_evidence(clause)
        ):
            continue
        if github_graphql_context(relative, clause):
            continue
        if not policy_negative(context, absolute_start, absolute_end):
            labels.add("custom Linear GraphQL document")

    for match in retired_overnight_report_re.finditer(line):
        absolute_start = line_start + match.start()
        absolute_end = line_start + match.end()
        clause, _, _ = clause_for(context, absolute_start, absolute_end)
        if (
            not policy_negative(context, absolute_start, absolute_end)
            and not migration_context_re.search(clause)
        ):
            labels.add("retired local overnight-report contract")

    for match in local_strong_re.finditer(line):
        absolute_start = line_start + match.start()
        absolute_end = line_start + match.end()
        clause, _, _ = clause_for(context, absolute_start, absolute_end)
        structural_reference = bool(
            match.group(0).startswith(("[[", "<"))
            or re.search(r"(?:=|:)\s*[`\"']?\s*$", line[:match.start()])
        )
        if not structural_reference and not local_action_re.search(clause):
            continue
        if not local_exception(relative, context, absolute_start, absolute_end, line):
            labels.add("local development-record authority")
    for match in local_noun_re.finditer(line):
        absolute_start = line_start + match.start()
        absolute_end = line_start + match.end()
        clause, _, _ = clause_for(context, absolute_start, absolute_end)
        if not local_action_re.search(clause):
            continue
        if not local_exception(relative, context, absolute_start, absolute_end, line):
            labels.add("local development-record authority")

    for match in spec_token_re.finditer(line):
        absolute_start = line_start + match.start()
        absolute_end = line_start + match.end()
        clause, _, _ = clause_for(context, absolute_start, absolute_end)
        after = line[match.end():]
        if not (
            spec_value_re.match(after)
            or spec_trailer_context_re.search(clause)
            or re.search(r"(?:\^|\\A)\\?Spec:", line)
        ):
            continue
        if not spec_trailer_exception(context, absolute_start, absolute_end):
            labels.add("Spec trailer")
    return labels


def fixture_labels(relative: str, line: str) -> set[str]:
    kind = active_surface_kind(relative)
    if kind is None:
        return set()
    return classify_line(relative, line, line, 0)


# These fixtures test path classification as well as every forbidden content class. A mixed
# rejection/use sentence makes sure a nearby prohibition cannot suppress a real active caller.
path_fixtures = (
    ("skills/example/SKILL.md", "skill"),
    ("skills/example/references/contract.md", "reference"),
    ("skills/example/prompts/worker.md", "prompt"),
    ("skills/example/scripts/sync.graphql", "script"),
    ("skills/woostack-init/templates/gitignore", "generated-source template"),
    ("skills/example/templates/generated/workspace.seed", "generated-source template"),
    ("skills/example/scripts/run.sh", "script"),
    ("action.yml", "action"),
    (".github/workflows/reusable-review.yml", "action"),
    ("AGENTS.md", "root document"),
    ("README.md", "root document"),
    ("CONTRIBUTING.md", "root document"),
    ("site/content/docs/concepts/example.mdx", "authored site"),
    ("site/content/docs/skills/generated.mdx", None),
    ("skills/example/scripts/tests/test-run.sh", None),
    ("skills/example/scripts/fixtures/linear-output.txt", None),
    ("skills/example/evals/evals.json", None),
    ("skills/woostack-dream/evals/fixtures/legacy-report.md", None),
    ("skills/example/history/legacy-tools.md", None),
    ("skills/example/migrations/legacy-tools.md", None),
    (".woostack/migrations/legacy-tools.md", None),
    (self_relative, None),
    (".woostack/plans/2026-07-26-linear-only-collaboration.md", None),
    (".woostack/overnight/2026-06-12-legacy-report.md", None),
)
for fixture_path, expected_kind in path_fixtures:
    actual_kind = active_surface_kind(fixture_path)
    if actual_kind != expected_kind:
        findings.append(
            "guard path-fixture mismatch: "
            f"{fixture_path!r}: expected {expected_kind!r}, got {actual_kind!r}"
        )

content_fixtures: list[tuple[str, str, set[str]]] = [
    (
        "skills/woostack-build/references/linear-context.md",
        "Invoke `mcp__linear_update_project` to persist the feature specification.",
        {"hard-coded official Linear MCP tool name"},
    ),
    (
        "skills/example/templates/engineer-profile",
        'import { LinearClient } from "@linear/sdk"; const key = process.env.LINEAR_API_KEY;',
        {"custom Linear GraphQL transport", "repository Linear credential"},
    ),
    (
        "skills/example/templates/development-record.yaml",
        "Load .woostack/specs/payments.md and .woostack/plans/payments.md as development authority.",
        {"local development-record authority"},
    ),
    (
        "skills/example/templates/pull-request-body",
        "Append a `Spec:` attribution line to the PR body.",
        {"Spec trailer"},
    ),
    (
        "skills/example/templates/overnight/handoff",
        "Write the overnight report to .woostack/overnight/payments.md.",
        {
            "local development-record authority",
            "retired local overnight-report contract",
        },
    ),
    (
        "skills/example/references/contract.md",
        "Resolve artifacts.specPlan before loading the selected development backend.",
        {"backend selector"},
    ),
    (
        "action.yml",
        "env: { LINEAR_API_KEY: ${{ inputs.linear_api_key }} }",
        {"repository Linear credential"},
    ),
    (
        "skills/example/SKILL.md",
        "Read LINEAR_API_KEY, which is not development authority.",
        {"repository Linear credential"},
    ),
    (
        "skills/example/scripts/client.ts",
        'import { LinearClient } from "@linear/sdk";',
        {"custom Linear GraphQL transport"},
    ),
    (
        "skills/example/scripts/client.ts",
        "await linearClient.createIssue({ title });",
        {"custom Linear GraphQL transport"},
    ),
    (
        "skills/example/scripts/client.ts",
        "const { LINEAR_CLIENT_SECRET: linearSecret } = process.env;",
        {"repository Linear credential"},
    ),
    (
        "skills/example/scripts/sync.sh",
        'ENDPOINT="https://api.linear.app/graphql"',
        {"custom Linear GraphQL endpoint"},
    ),
    (
        "skills/example/scripts/sync.py",
        'LINEAR_GRAPHQL_DOCUMENT = "mutation UpdateIssue($id: ID!) {"',
        {"custom Linear GraphQL operation"},
    ),
    (
        "skills/example/SKILL.md",
        "Use Linear GraphQL mutations to update project state.",
        {"custom Linear GraphQL transport"},
    ),
    (
        "skills/woostack-review/scripts/prefetch.sh",
        'LINEAR_GRAPHQL_DOCUMENT = "mutation UpdateIssue($id: ID!) {"',
        {"custom Linear GraphQL operation"},
    ),
    (
        "skills/woostack-review/scripts/prefetch.sh",
        "# GitHub GraphQL helper: mutation IssueUpdate($id: String!, $input: IssueUpdateInput!) { issueUpdate(id: $id, input: $input) { success } }",
        {"custom Linear GraphQL operation"},
    ),
    (
        "skills/example/references/contract.md",
        "Load issue-update.graphql before the request.",
        {"retired Linear GraphQL document"},
    ),
    (
        "skills/example/scripts/sync.graphql",
        "Load sync.graphql against Linear before issuing the request.",
        {"custom Linear GraphQL document"},
    ),
    (
        "skills/example/SKILL.md",
        "Create a managed spec document in Linear as the feature record.",
        {"Linear document dependency"},
    ),
    (
        "AGENTS.md",
        "Multi-issue work uses one Linear project, one specification document, and ordered increment issues.",
        {"Linear document dependency"},
    ),
    (
        "README.md",
        "Multi-issue work uses one Linear project, one spec document, and ordered increment issues.",
        {"Linear document dependency"},
    ),
    (
        "CONTRIBUTING.md",
        "Read the project's specification document before planning.",
        {"Linear document dependency"},
    ),
    (
        "site/content/docs/concepts/status-tracking.mdx",
        "The spec-document is the approved development authority.",
        {"Linear document dependency"},
    ),
    (
        "skills/example/prompts/worker.md",
        "Read .woostack/specs/cache.md as the source of truth.",
        {"local development-record authority"},
    ),
    (
        "skills/example/SKILL.md",
        "Write the approved work to .woostack/plans/cache.md.",
        {"local development-record authority"},
    ),
    (
        "skills/example/SKILL.md",
        "Persist acceptance in .woostack/fixes/cache.md.",
        {"local development-record authority"},
    ),
    (
        "skills/example/SKILL.md",
        "Write the morning record to .woostack/overnight/cache.md.",
        {"local development-record authority"},
    ),
    (
        "CONTRIBUTING.md",
        "Change the overnight execute phase (unattended autonomous run, morning report).",
        {"retired local overnight-report contract"},
    ),
    (
        "skills/woostack-dream/SKILL.md",
        "Read .woostack/overnight/cache.md as a curation input.",
        {"local development-record authority"},
    ),
    (
        "site/content/docs/concepts/workflows.mdx",
        "Append a `Spec:` trailer to the PR body.",
        {"Spec trailer"},
    ),
    (
        "skills/example/SKILL.md",
        "Read the `Spec:` attribution even when the legacy guard forbids it.",
        {"Spec trailer"},
    ),
    (
        "skills/example/SKILL.md",
        "Normalize the `Spec:` trailer into Linear attribution.",
        {"Spec trailer"},
    ),
    (
        "skills/example/SKILL.md",
        "Never use LINEAR_API_KEY; invoke linear.sh for project state.",
        {"retired adapter reference"},
    ),
    (
        "skills/example/SKILL.md",
        "Never use LINEAR_API_KEY but invoke linear.sh for project state.",
        {"retired adapter reference"},
    ),
    (
        "skills/example/SKILL.md",
        "Omit LINEAR_API_KEY and invoke linear.sh for project state.",
        {"retired adapter reference"},
    ),
]
content_fixtures.extend(
    (
        "skills/example/SKILL.md",
        f"Invoke {filename} for the current feature.",
        {"retired adapter reference"},
    )
    for filename in retired_adapter_filenames
)
content_fixtures.extend(
    (
        "skills/example/references/contract.md",
        f"Load {filename} for the Linear request.",
        {"retired Linear GraphQL document"},
    )
    for filename in retired_graphql_filenames
)
content_fixtures.extend(
    (
        fixture_path,
        fixture_line,
        set(),
    )
    for fixture_path, fixture_line in (
        (
            "skills/example/templates/engineer-profile",
            "Discover official host-exposed Linear MCP operations by capability and independently read every mutation back.",
        ),
        (
            "skills/example/templates/migration-note",
            "Read historical .woostack/plans/legacy.md only for one-way migration diagnosis; it is not development authority.",
        ),
        (
            "skills/example/templates/overnight-history",
            "Historical overnight reports are retained only for migration diagnosis and are never development authority.",
        ),
        (
            "skills/woostack-review/scripts/prefetch.sh",
            "gh api graphql -f query='query($owner: String!) { repository(owner: $owner) { pullRequest { reviewThreads { nodes { id } } } } }'",
        ),
        (
            "skills/woostack-address-comments/scripts/resolve.sh",
            "gh api graphql -f query='mutation ResolveReviewThread($threadId: ID!) { resolveReviewThread(input: {threadId: $threadId}) { thread { id isResolved } } }' # GitHub GraphQL",
        ),
        (
            "skills/example/SKILL.md",
            "`LINEAR_API_KEY` must not be read by repository code.",
        ),
        (
            "skills/example/SKILL.md",
            "Repository tooling must not load LINEAR_ACCESS_TOKEN.",
        ),
        (
            "skills/example/SKILL.md",
            "LINEAR_CLIENT_SECRET stays host-owned and is never consumed by repository tooling.",
        ),
        (
            "skills/example/SKILL.md",
            "Reject @linear/sdk and never construct LinearClient; use official Linear MCP.",
        ),
        (
            "skills/woostack-commit/SKILL.md",
            "Follow the legacy-`Spec:` rejection rule for every PR body.",
        ),
        (
            "skills/woostack-commit/references/pr-body.md",
            "A case-insensitive exact `Spec:` label is a forbidden legacy attribution candidate.",
        ),
        (
            "skills/woostack-commit/references/pr-body.md",
            "After the legacy-`Spec:` guard passes, existing PR text may provide accurate context.",
        ),
        (
            "skills/example/SKILL.md",
            "Use official Linear MCP at https://mcp.linear.app/mcp and GitHub GraphQL for review threads.",
        ),
        (
            "skills/woostack-build/references/linear-context.md",
            "Discover official Linear MCP operations by required capability through https://mcp.linear.app/mcp.",
        ),
        (
            "skills/woostack-build/scripts/tests/test-linear-tools.sh",
            "Invoke `mcp__linear_update_project` to exercise the rejected host binding.",
        ),
        (
            "skills/woostack-build/scripts/fixtures/linear-output.txt",
            "Recorded host output named `mcp__linear_update_project`.",
        ),
        (
            "skills/woostack-build/evals/fixtures/legacy-tool.md",
            "The evaluated response invoked `mcp__linear_update_project`.",
        ),
        (
            "skills/woostack-build/history/legacy-tools.md",
            "Historical guidance invoked `mcp__linear_update_project`.",
        ),
        (
            ".woostack/migrations/legacy-tools.md",
            "Migration evidence records `mcp__linear_update_project`.",
        ),
        (
            "skills/example/SKILL.md",
            "There is no backend selection, no Linear document, and no local spec or plan authority; never use LINEAR_API_KEY or linear.sh. Custom Linear GraphQL is forbidden, and `Spec:` trailers are removed.",
        ),
        (
            "skills/example/SKILL.md",
            "Omit LINEAR_API_KEY from every delegated worker environment.",
        ),
        (
            "skills/example/SKILL.md",
            "A supplied Linear document blocks before repository mutation.",
        ),
        (
            "site/content/docs/concepts/memory.mdx",
            "Linear documents and local specifications are not new provenance or development authority.",
        ),
        (
            "AGENTS.md",
            "No Linear specification document is created; project updates own the specification.",
        ),
        (
            "README.md",
            "Historical project specification documents are retained only for migration diagnosis.",
        ),
        (
            "CONTRIBUTING.md",
            "A quoted spec document is explicitly non-authoritative evidence.",
        ),
        (
            "site/content/docs/concepts/index.mdx",
            "One Linear project has specification-bearing project updates and ordered increment issues; no Linear document is created.",
        ),
        (
            "site/content/docs/concepts/workflows.mdx",
            "Run overnight renders a terminal handback and does not write a local morning report.",
        ),
        (
            "skills/example/SKILL.md",
            "Linear documents, backend resolvers, and custom transports are never status inputs.",
        ),
        (
            "skills/using-woostack/SKILL.md",
            '| "I will identify the work by a local spec or plan." | Development work is selected only by an exact Linear identity; local knowledge never becomes scope or lifecycle authority. |',
        ),
        (
            "skills/using-woostack/references/engineer-agents.md",
            "Neither profile may use a local plan; a Linear document; a repository credential; or a custom Linear HTTP/GraphQL client as development authority.",
        ),
        (
            "skills/woostack-init/references/artifact-backends.md",
            "Duplicate trailers, a `Spec:` trailer, or mismatched attribution fails closed.",
        ),
        (
            "skills/woostack-init/references/memory.md",
            "Nested segments and Linear document URIs are rejected.",
        ),
        (
            "skills/woostack-respond/SKILL.md",
            "The report contains no raw payload, local fix/spec/plan artifact, assignment, or approval.",
        ),
        (
            "skills/woostack-status/SKILL.md",
            "No backend selection, Linear document, repository credential, or direct Linear HTTP/GraphQL call.",
        ),
        (
            "skills/woostack-status/references/conventions.md",
            "Every body contains no `Spec:` attribution.",
        ),
        (
            "skills/example/SKILL.md",
            "Doctor detects legacy .woostack/specs/ records and blocks until one-way migration completes.",
        ),
        (
            "skills/woostack-doctor/scripts/checks/memory.sh",
            ".woostack/specs/*|.woostack/plans/*|.woostack/fixes/*)",
        ),
        (
            "skills/woostack-doctor/references/checks.md",
            "| `linear-policy` | backend selector or credential-like key | error | report |",
        ),
        (
            "skills/example/references/api.md",
            "Review GraphQL schema files such as schema.graphql and `extend type Query`.",
        ),
        (
            "skills/example/SKILL.md",
            "The unrelated helper legacy-linear.sh is not the retired adapter filename.",
        ),
        (
            self_relative,
            "Invoke linear.sh with LINEAR_API_KEY and append Spec: .woostack/specs/x.md.",
        ),
        (
            ".woostack/specs/2026-07-26-linear-only-collaboration.md",
            "Historical release prose invokes linear.sh with LINEAR_API_KEY on the Markdown backend.",
        ),
        (
            ".woostack/overnight/2026-06-12-legacy-report.md",
            "Historical release evidence records the retired local morning report producer.",
        ),
        (
            "site/content/docs/skills/generated.mdx",
            "Invoke linear.sh with LINEAR_API_KEY.",
        ),
    )
)
for fixture_path, fixture_line, expected_labels in content_fixtures:
    actual_labels = fixture_labels(fixture_path, fixture_line)
    if actual_labels != expected_labels:
        findings.append(
            "guard content-fixture mismatch: "
            f"{fixture_path!r} {fixture_line!r}: expected {sorted(expected_labels)!r}, "
            f"got {sorted(actual_labels)!r}"
        )


def active_surfaces() -> list[Path]:
    selected: set[Path] = set()
    for base in (root / "skills", root / "site/content/docs"):
        if not base.is_dir():
            continue
        for path in base.rglob("*"):
            if not path.is_file():
                continue
            relative = path.relative_to(root).as_posix()
            if active_surface_kind(relative) is not None:
                selected.add(path)
    for relative in (
        *root_doc_relatives,
        *config_relatives,
        "action.yml",
        ".github/workflows/reusable-review.yml",
    ):
        path = root / relative
        if path.is_file() and active_surface_kind(relative) is not None:
            selected.add(path)
    return sorted(selected)


check_configs()
for relative in retired_paths:
    if (root / relative).exists():
        findings.append(f"{relative}: retired path still exists")
legacy_graphql_dir = root / "skills/woostack-init/scripts/artifacts/graphql"
if legacy_graphql_dir.is_dir():
    for path in legacy_graphql_dir.rglob("*.graphql"):
        relative = path.relative_to(root).as_posix()
        if relative not in retired_path_set:
            findings.append(f"{relative}: unexpected retired Linear GraphQL document exists")

for path in active_surfaces():
    relative = path.relative_to(root).as_posix()
    kind = active_surface_kind(relative)
    if kind is None:
        continue
    try:
        lines = path.read_text(errors="replace").splitlines()
    except OSError as error:
        findings.append(f"{relative}: unable to scan active {kind}: {error}")
        continue
    for index, line in enumerate(lines):
        context, line_start = context_for(lines, index, kind)
        for label in sorted(classify_line(relative, line, context, line_start)):
            findings.append(
                f"{relative}:{index + 1}: active {kind} {label}: {line.strip()}"
            )

if not canonical_path.is_file():
    findings.append(f"{canonical_relative}: canonical Linear MCP contract is missing")
else:
    canonical = canonical_path.read_text()
    required = [
        "official Linear MCP",
        "feature",
        "increment",
        "work-item",
        "designApproved",
        "executionApproved",
        "blockerResolved",
        "assignmentAccepted",
        "implementationEvidence",
        "reviewResult",
        "+++ Woostack metadata — managed, do not edit",
        "client-generated UUID",
        "projectStatuses",
        "issueStates",
        "Linear-Project: <project UUID>",
        "Linear-Issue: <TEAM-NUMBER>",
    ]
    for value in required:
        if value not in canonical:
            findings.append(
                f"{canonical_relative}: missing canonical contract value {value!r}"
            )

if findings:
    print("Linear-only contract violations:")
    for finding in sorted(set(findings)):
        print(f"  {finding}")
    raise SystemExit(1)

print("Linear-only contract: PASS")
PY
