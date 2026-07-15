#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
commit = (root / "skills/woostack-commit/SKILL.md").read_text(encoding="utf-8")
conventions = (root / "skills/woostack-status/references/conventions.md").read_text(encoding="utf-8")
controller = (root / "skills/woostack-execute/references/controller.md").read_text(encoding="utf-8")


def fail(message):
    raise SystemExit(f"test-linear-attribution: {message}")

def compact(value):
    return re.sub(r"\s+", " ", value)


def must(text, token, scope):
    if compact(token) not in compact(text):
        fail(f"{scope} missing {token!r}")


def must_not(text, token, scope):
    if compact(token) in compact(text):
        fail(f"{scope} unexpectedly contains {token!r}")


def ordered(text, tokens, scope):
    haystack = compact(text)
    position = -1
    for token in tokens:
        position = haystack.find(compact(token), position + 1)
        if position < 0:
            fail(f"{scope} missing or misorders {token!r}")

def section(text, start, end):
    try:
        begin = text.index(start)
        finish = text.index(end, begin + len(start))
    except ValueError:
        fail(f"section boundary missing: {start!r} -> {end!r}")
    return text[begin:finish]


# Backend selection is authoritative and precedes every invariant or draft operation.
ordered(commit, (
    "resolve-backend.sh <repo-root>",
    "### 1. Inspect state",
    "### 4.5 Backend-specific invariant and attribution checks",
    "### 5. Commit",
), "backend-first workflow")
must(commit, "Do not inspect invariants, dispatch a drafting", "backend-first workflow")
must(commit, "draft commit/PR text before this succeeds", "backend-first workflow")
must(commit, "never fall back from Linear to Markdown", "backend-first workflow")

# Markdown attribution remains byte-for-byte compatible with status discovery.
markdown_trailer = "Spec: .woostack/specs/<file>.md"
if commit.count(markdown_trailer) < 2:
    fail("commit workflow no longer preserves the exact Markdown Spec trailer")
must(conventions, "trailer line `Spec: .woostack/specs/<file>.md`", "Markdown conventions")

# Linear must verify one owned project/issue pair before submit or PR update.
for token in (
    "linear.sh feature-read",
    "LINEAR_PROJECT_STATUSES",
    "LINEAR_ISSUE_STATES",
    "exactly one increment whose `identifier` equals",
    "`feature.id` equals the supplied project UUID",
    "foreign project",
    "missing or failed API verification",
    "block submission and PR update",
):
    must(commit, token, "Linear pre-submit verification")
ordered(commit, (
    "linear.sh feature-read",
    "validate the proposed PR body",
    "gt submit",
), "Linear verification before submit")

# Linear trailers are a strict pair, not additive aliases for the Markdown trailer.
for text, scope in ((commit, "commit workflow"), (conventions, "status conventions")):
    must(text, "Linear-Project: <uuid>", scope)
    must(text, "Linear-Issue: <TEAM-NUMBER>", scope)
for token in (
    "exactly one `Linear-Project:` trailer",
    "exactly one `Linear-Issue:` trailer",
    "duplicate",
    "mismatch",
):
    must(commit, token, "Linear trailer validation")
must(commit, "Do not include a `Spec:` trailer in a Linear-backed PR", "Linear trailer validation")

# An existing current-branch PR may recover only from a completely absent trailer pair when
# updates are enabled; conflicting or partial attribution still fails closed.
for token in (
    "may have neither Linear trailer",
    "Treat it as unattributed",
    "proposed body containing the exact pair",
    "post-submit `gh pr edit` path",
    "`--no-pr-update` never permits this missing-pair recovery",
):
    must(commit, token, "unattributed PR recovery")

linear_pr_resolution = section(
    commit,
    "For Linear, a PR must already exist",
    "Immediately call `linear.sh feature-read`",
)
for token in (
    "head branch",
    "git branch --show-current",
    "repository to equal the backend resolver's repository",
    "canonical PR URL for that repository",
    "An edit failure, read failure",
    "leaves the issue unchanged",
):
    must(linear_pr_resolution, token, "Linear post-submit PR identity")

# Attribution is written only after Graphite succeeds, is adapter-owned, and is read back.
ordered(commit, (
    "gt submit",
    "apply the validated title/body with `gh pr edit`",
    "re-fetch its body with `gh pr view`",
    "Only after `gt submit` succeeds",
    "linear.sh issue-transition",
    "--branch",
    "--pull-request",
    "linear.sh feature-read",
), "post-submit attribution")
for token in (
    "`verified: true`",
    "empty `pending`",
    "exact submitted branch and PR URL",
    "Do not merge",
    "regardless of whether the mutation returned success, an error, or timed out",
    "exact intended read-back is success",
    "explicit resume may retry",
    "partial or mismatched evidence requires manual reconciliation",
    "never infer mutation outcome from the transport result",
):
    must(commit, token, "post-submit attribution")

no_update = section(
    commit,
    "If the `--no-pr-update` flag is specified",
    "Use a validated fast-subagent draft",
)
for token in (
    "do not run `gh pr edit`",
    "existing PR body to carry the exact verified trailer pair",
    "records attribution through `linear.sh issue-transition`",
    "mandatory `feature-read` read-back",
    "skips only the field edit",
):
    must(no_update, token, "Linear no-update attribution")
must_not(commit, "linear.sh status-reconcile", "commit merge boundary")
must(conventions, "stored only in the managed issue metadata", "Linear conventions")
must(conventions, "does not prove a merge", "Linear conventions")
must(
    conventions,
    "[backend execution controller](../../woostack-execute/references/controller.md#linear-issue-cadence)",
    "Linear unknown-outcome conventions cross-link",
)
for token in (
    "invoke the attribution transition exactly once",
    "run `feature-read` regardless",
    "observed state remains `executing` with no attribution evidence",
    "later explicit resume",
    "partial or mismatched state/evidence",
    "manual reconciliation",
):
    must(controller, token, "canonical Linear unknown-outcome contract")

print("test-linear-attribution: OK")
PY
