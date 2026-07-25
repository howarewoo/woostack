#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
paths = {
    "build": root / "skills/woostack-build/SKILL.md",
    "markdown_procedure": root / "skills/woostack-build/references/markdown-procedure.md",
    "linear_procedure": root / "skills/woostack-build/references/linear-procedure.md",
    "plan": root / "skills/woostack-plan/SKILL.md",
    "harden": root / "skills/woostack-harden/SKILL.md",
    "ideate": root / "skills/woostack-ideate/SKILL.md",
    "markdown": root / "skills/woostack-init/scripts/artifacts/markdown.sh",
    "metadata": root / "skills/woostack-init/scripts/artifacts/linear-metadata.py",
    "linear": root / "skills/woostack-init/scripts/artifacts/linear.sh",
    "plan_template": root / "skills/woostack-plan/references/plan-template.md",
    "spec_md": root / "skills/woostack-build/references/spec-template.md",
    "spec_html": root / "skills/woostack-build/references/spec-template.html",
    "conventions": root / "skills/woostack-status/references/conventions.md",
    "building_rules": root / "site/content/docs/concepts/building-rules.mdx",
}
texts = {name: path.read_text(encoding="utf-8") for name, path in paths.items()}

def fail(message):
    raise SystemExit(f"test-linear-build-contract: {message}")

def section(text, start, end=None):
    try:
        begin = text.index(start)
        finish = len(text) if end is None else text.index(end, begin + len(start))
    except ValueError:
        fail(f"section boundary missing: {start!r} -> {end!r}")
    return text[begin:finish]

def must(text, token, scope):
    if token not in text:
        fail(f"{scope} missing {token!r}")

def must_not(text, token, scope):
    if token in text:
        fail(f"{scope} unexpectedly contains {token!r}")

def ordered(text, tokens, scope):
    position = -1
    for token in tokens:
        position = text.find(token, position + 1)
        if position < 0:
            fail(f"{scope} missing or misorders {token!r}")

build = texts["build"]
markdown_branch = build + "\n" + texts["markdown_procedure"]
linear_branch = build + "\n" + texts["linear_procedure"]
must_not(texts["markdown_procedure"], "linear-procedure.md", "Markdown selected procedure")
must_not(texts["linear_procedure"], "markdown-procedure.md", "Linear selected procedure")
linear_spec_gate = section(
    linear_branch,
    '<HARD-GATE backend="linear" name="spec-approval">',
    "</HARD-GATE>",
)
plan_terminal = section(texts["plan"], "## Terminal state and gate boundary", "## Hard constraints")
plan_linear = section(texts["plan"], "### Linear", "## Deferral markers")

# Each backend branch owns exactly the same three ordered hard gates.
for backend, branch in (("markdown", markdown_branch), ("linear", linear_branch)):
    names = re.findall(r'<HARD-GATE backend="' + backend + r'" name="([^"]+)">', branch)
    if names != ["design-approval", "spec-approval", "execution-handoff"]:
        fail(f"{backend} gate set/order is {names!r}")
    must(branch, f"<!-- {backend}-gates: design-approval | spec-approval | execution-handoff -->", f"{backend} branch")
    for name in names:
        if not re.search(
            rf'<HARD-GATE backend="{backend}" name="{name}">\s*\S.*?</HARD-GATE>',
            branch,
            re.DOTALL,
        ):
            fail(f"{backend} gate {name!r} is empty")

# Gate barriers precede the first work they authorize, not just one another.
ordered(markdown_branch, (
    'name="design-approval"',
    "</HARD-GATE>",
    "2. **Write the spec as markdown.**",
), "Markdown design gate barrier")
ordered(markdown_branch, (
    'name="spec-approval"',
    "</HARD-GATE>",
    "4. **Plan.**",
), "Markdown spec gate barrier")
ordered(markdown_branch, (
    'name="execution-handoff"',
    "</HARD-GATE>",
    "9. **Execute.**",
), "Markdown execution gate barrier")
ordered(linear_branch, (
    'name="design-approval"',
    "</HARD-GATE>",
    "linear.sh feature-create",
), "Linear design gate barrier")
ordered(linear_branch, (
    'name="spec-approval"',
    "</HARD-GATE>",
    "4. **Plan in Linear.**",
), "Linear spec gate barrier")
for token in ("woostack-plan", "linear.sh plan-read", "linear.sh plan-reconcile"):
    must_not(linear_spec_gate, token, "Linear spec gate")

# Markdown branch pins the complete pre-backend execution and terminal behavior.
for token in (
    ".woostack/specs/YYYY-MM-DD-<slug>.md",
    "`**Source:** [[specs/<basename>]]`",
    "per-increment commit/review/distill cadence",
    "pausing on a blocking stop",
    "logging the blocker and continuing per its halt policy",
    "`executing` → `in-review` band",
    "terminal `status: done`",
    "board still **computes** that band",
    "only the spec+plan PR is open (no increment PRs)",
    "reviewed increment PR",
    "tree-stacked across",
    "morning report under",
):
    must(markdown_branch, token, "Markdown branch")
for token in (
    "git worktree remove --force",
    "delete the `feature/<slug>` branch",
    "close the now-open PR",
):
    must(markdown_branch, token, "Markdown abandon cleanup")
must_not(texts["markdown_procedure"], "`abandoned`", "Markdown procedure")
must(linear_branch, "preserve the project/document audit history", "Linear abandon persistence")

# Linear preflight is captured once and every later command consumes UUID context, not names.
ordered(linear_branch, (
    "linear.sh preflight",
    "LINEAR_CONTEXT",
    "LINEAR_TEAM_ID",
    "LINEAR_PROJECT_STATUSES",
    "LINEAR_ISSUE_STATES",
    "linear.sh feature-resolve",
    "linear.sh feature-create",
), "Linear preflight propagation")
for token in (
    "preflight input only",
    "every later adapter command uses these extracted UUID values",
    "exactly one eligible managed project",
    "mandatory read-back receipt",
    "one managed Linear project, exactly one",
    "one ordered managed issue set",
):
    must(linear_branch, token, "Linear branch")
for token in (
    "one issue per increment",
    "native `blocked by` relations",
    "explicit unique positive integer ordinal",
    "Git parent",
    "acceptance coverage",
):
    must(plan_linear, token, "Linear planning")

# Linear contains explicit prohibitions, and no Markdown/Git authoring command leaks into it.
must(linear_branch, "no spec/plan worktree, branch, commit, or docs-only PR", "Linear branch")
must(linear_branch, "`.woostack/specs/` or `.woostack/plans/` source file", "Linear branch")
for forbidden in ("git worktree add", "gt create", "woostack-commit"):
    must_not(texts["linear_procedure"], forbidden, "Linear procedure")

# Ready precedes the provisional branch/SHA freeze; explicit Go/overnight approval makes the
# frozen base immutable before either executor starts.
ordered(linear_branch, (
    "planning → ready",
    "Immediately before the execution-handoff gate",
    "baseBranch",
    "baseCommitSha",
    "designState: ready",
    "linear.sh feature-read",
    'name="execution-handoff"',

), "Linear freeze/handoff")
for token in (
    "pair is provisional",
    "accidental `ready → ready` pair change fails closed",
    "Explicit replan sequence",
    "--target planning --replan",
    "repository-owned spec",
    "project/spec lifecycle mismatch",
    "no implementation branch, worktree, commit, or",
):
    must(linear_branch, token, "Linear handoff/replan")
linear_handoff = section(
    linear_branch,
    '8. <HARD-GATE backend="linear" name="execution-handoff">',
    "</HARD-GATE>",
)
ordered(linear_handoff, (
    "**Go**",
    "**Run overnight**",
    "**Hand off**",
    "linear.sh plan-read",
    "null branch/PR evidence",
    "linear.sh spec-read",
    "linear.sh spec-write",
    "designState: executionApproved",
    "linear.sh feature-read",
), "Linear execution approval")
for token in (
    "base pair becomes immutable",
    "Ambiguous or no answer is not Go",
    "Create no implementation Git",
):
    must(linear_handoff, token, "Linear execution approval")
for token in (
    "9. **Execute.**",
    "run `woostack-execute`",
    "`woostack-execute-overnight` unattended",
    "root increment branches start from the frozen SHA",
):
    must(linear_branch, token, "Linear execution handoff")
for token in ("after execution is", "explicitly approved"):
    must(texts["building_rules"], token, "served build-loop docs")

# Planning propagates preflight UUID context and standalone stops before harden/ready/freeze/handoff.
for token in (
    "LINEAR_TEAM_ID",
    "LINEAR_PROJECT_STATUSES",
    "LINEAR_ISSUE_STATES",
    "linear.sh plan-reconcile",
    "linear.sh plan-read",
):
    must(plan_linear if token != "LINEAR_PROJECT_STATUSES" else texts["plan"], token, "Linear planning")
for token in (
    "`approved` or `planning` project",
    "already `planning` while the project remains `approved`",
    "remaining project transition",
    "When both artifacts report `planning`",
    "resume without repeating either",
    "Reject the inverse split",
):
    must(texts["plan"], token, "Linear planning retry")
must(plan_terminal, "not execute-ready", "plan terminal")
must(plan_terminal, "Do not offer `/woostack-execute`", "plan terminal")
must(plan_terminal, "must still invoke harden", "plan terminal")
must_not(plan_terminal, "standalone, name the selected artifact and offer", "plan terminal")

# Status ownership is canonical; workflow docs carry only local operational details.
for token in ("canonical lifecycle and ownership", "woostack-status/references/conventions.md", "no Markdown artifact survives", "status-only abandonment", "status is `inReview`"):
    must(build, token, "status ownership")
for token in ("Spec frontmatter owns design approval: `draft -> hardened -> approved`", "Plan frontmatter owns implementation lifecycle", "Retained Markdown artifacts may also carry terminal `abandoned`", "build spec-gate cleanup path leaves no retained"):
    must(texts["conventions"], token, "canonical Markdown lifecycle")
for token in ("In Markdown, this spec owns `draft`, `hardened`, or `approved`", "leaving no artifact or authored abandoned status", "plan owns later implementation phases", "managed spec document owns `designState`", "project mirrors the applicable feature lifecycle", "increment issues own their separate normalized lifecycle", "normalized lifecycle including `inReview`"):
    must(texts["spec_md"], token, "spec template status")
must_not(texts["spec_md"], "this spec owns `draft`, `hardened`, `approved`, or terminal `abandoned`", "spec template status")
for token in (
    "Linear design lifecycle is closed",
    "executionApproved",
    "same-state writes are idempotent",
    "active states may explicitly become `abandoned`",
    "Every other jump or backtrack fails closed",
):
    must(build, token, "closed Linear lifecycle")

# Frozen schema is adapter-owned, evidence-aware, emitted, and not duplicated as transport code.
for token in ("baseBranch", "baseCommitSha", "GIT_COMMIT_SHA_RE", "DESIGN_SEQUENCE", "DESIGN_STATES", "increment_evidence", "eligible evidence-free replan", "terminal design lifecycle is immutable", "non-canonical design lifecycle transition"):
    must(texts["metadata"], token, "metadata adapter")
for token in ("baseBranch:$baseBranch", "baseCommitSha:$baseCommitSha", "--replan", "--issue-state-map", "--expected-revision", "project and managed spec lifecycle mismatch blocks replanning"):
    must(texts["linear"], token, "Linear adapter")
for token in ("retain its `.revision`", "--expected-revision", "claims the revisioned spec as", "before it attempts the project transition", "verified, resumable `planning` spec receipt"):
    must(linear_branch, token, "Linear replan caller")
for workflow in (build, texts["linear_procedure"], texts["plan"], texts["harden"], texts["ideate"]):
    for forbidden in ("api.linear.app/graphql", "query {", "mutation {"):
        must_not(workflow, forbidden, "workflow skill")

# Templates retain normalized input and exact Markdown joins; spec Markdown/HTML stay 1:1.
must(texts["plan_template"], "Normalized backend input", "plan template")
must(texts["plan_template"], "type: plan", "plan template")
must(texts["plan_template"], "**Source:** [[specs/{{SPEC_BASENAME}}]]", "plan template")
md_sections = [(int(n), title.strip()) for n, title in re.findall(r"^## (\d+)\. (.+)$", texts["spec_md"], re.M)]
html_sections = [(int(n), title.replace("&amp;", "&").strip()) for n, title in re.findall(r"<h2>(\d+)\. ([^<]+)</h2>", texts["spec_html"])]
if md_sections != html_sections or len(md_sections) != 9:
    fail("spec Markdown/HTML numbered sections drifted")
for template in (texts["spec_md"], texts["spec_html"]):
    must(template, "{{ARTIFACT_REFERENCE}}", "spec template")

must(texts["harden"], "selected backend artifact in place", "harden")
must(texts["harden"], "LINEAR_CONTEXT.team.id", "harden")
must(texts["harden"], "owns **no approval gate**", "harden")
must(texts["ideate"], "selected artifact backend", "ideate")
must_not(texts["markdown"], "woostack-defer(increment 5)", "Markdown adapter")

print("test-linear-build-contract: OK")
PY
