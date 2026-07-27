#!/usr/bin/env bash
# Structural and adversarial contract for provider-neutral engineer-agent authority.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$HERE/../../woostack-init/scripts/tests/assert.sh"
set +e

ROOT="${WOOSTACK_ENGINEER_ROOT:-$(cd "$HERE/../../.." && pwd)}"
TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/woostack-engineer-contract.XXXXXX")" || exit 1
trap 'rm -rf -- "$TMP_ROOT"' EXIT HUP INT TERM

CONTRACT_FILES=(
  skills/using-woostack/references/engineer-agents.md
  skills/using-woostack/SKILL.md
  skills/woostack-execute/references/controller.md
  skills/woostack-review/SKILL.md
  skills/woostack-execute/references/subagent-driver.md
)

analyze_root() {
  python3 - "$1" <<'PY'
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
paths = {
    "generic": root / "skills/using-woostack/references/engineer-agents.md",
    "routing": root / "skills/using-woostack/SKILL.md",
    "controller": root / "skills/woostack-execute/references/controller.md",
    "review": root / "skills/woostack-review/SKILL.md",
    "subagent": root / "skills/woostack-execute/references/subagent-driver.md",
}
texts = {}
failures = []


def failure(label: str, message: str):
    failures.append(f"{label}: {message}")


def fold(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def require(label: str, pattern: str, message: str):
    if not re.search(pattern, fold(texts.get(label, "")), re.I | re.S):
        failure(label, message)


def ordered(label: str, needles, message: str):
    subject = fold(texts.get(label, ""))
    cursor = -1
    for needle in needles:
        match = re.search(needle, subject[cursor + 1 :], re.I | re.S)
        if not match:
            failure(label, message)
            return
        cursor += match.end()


def paragraphs(value: str):
    for raw in re.split(r"\n\s*\n", value):
        paragraph = fold(raw)
        if paragraph:
            yield paragraph


for label, path in paths.items():
    if not path.is_file():
        failure(label, f"missing {path.relative_to(root)}")
        texts[label] = ""
    else:
        texts[label] = path.read_text(encoding="utf-8")

# The reusable authority must remain host-neutral and must link, rather than duplicate, canonical
# Linear envelope/event/lifecycle schemas.
generic = texts.get("generic", "")
if re.search(r"\b(?:Hermes|OMP)\b", generic):
    failure("generic", "leaks a concrete Hermes/OMP host into the provider-neutral contract")

for pattern, message in (
    (r"role names are abstract.{0,180}any host", "does not declare host-neutral abstract roles"),
    (r"artifact-backends\.md#versioned-managed-metadata", "does not link the canonical managed envelope schema"),
    (r"artifact-backends\.md#canonical-issue-event-dispatch-and-pre-commit-evidence", "does not link the canonical issue-event schema"),
    (r"conventions\.md#issue-state-and-events", "does not link the canonical issue lifecycle"),
    (r"official host-exposed Linear MCP is the only development-record interface", "does not require official host-exposed Linear MCP"),
    (r"No alternate authority.{0,320}local specification, plan, fix.{0,240}Linear document.{0,220}repository credential.{0,220}custom Linear HTTP/GraphQL", "does not reject alternate development authority"),
    (r"standing authority only when.{0,180}exact canonical repository.{0,180}configured workspace/team", "does not bind an exact standing repository/workspace envelope"),
    (r"exact managed project identity.{0,160}pinned project lead.{0,180}standalone work-item identity.{0,120}verified dispatcher", "does not bind project-lead or standalone-dispatcher authority"),
    (r"responsible human principal", "does not bind the human escalation principal"),
    (r"standing envelope.{0,180}grants no assignment.{0,220}side effect by itself", "treats standing authority as side-effect permission"),
    (r"Every gate or consequential decision requires its deliberate canonical typed event and independent read-back.{0,80}silence is never a decision", "does not require deliberate gate/decision events"),
    (r"pins exactly this non-secret identity before allocation.{0,180}one stable `ENGINEER_NAME`", "does not pin one stable ENGINEER_NAME before allocation"),
    (r"one authenticated Linear principal kind and native principal ID", "does not pin one exact Linear principal"),
    (r"one decision-maker profile and its isolated controller session", "does not pin one isolated decision-maker profile/session"),
    (r"one coding profile and its isolated coding session", "does not pin one isolated coding profile/session"),
    (r"profiles belong to the unit's one Linear principal", "does not bind both profiles to the unit principal"),
    (r"each profile resolves that principal only through its own official host MCP/OAuth secret store", "does not isolate the two host secret stores"),
    (r"credential, token.{0,140}never copied or passed between profiles", "allows profile credential/token transfer"),
    (r"Concurrent engineer units must have distinct `ENGINEER_NAME` values, Linear principals, decision-maker profiles, coding profiles, authentication/token contexts.{0,160}sessions", "does not isolate concurrent engineer identities/profiles/tokens/sessions"),
    (r"Pinned project lead or verified standalone dispatcher.{0,420}allocation/reassignment", "does not define lead/dispatcher allocation authority"),
    (r"Assigned issue decision-maker.{0,420}unchanged assigned-issue contract", "does not define issue decision-maker authority"),
    (r"Paired coding profile.{0,360}exactly one accepted issue", "does not define the paired coder's one-issue authority"),
    (r"Decision-maker does not code.{0,320}must not author or modify tracked implementation or test bytes.{0,120}run implementation or test commands", "does not prohibit decision-maker coding or test execution"),
    (r"Coder has one bounded surface.{0,360}only the selected issue.{0,420}must not inspect or mutate another issue", "does not confine the coder to one issue/surface"),
    (r"managed event not explicitly named by that bounded brief and permitted by the canonical actor schema", "does not bound coder event production to an explicit canonical brief"),
    (r"Controller-authorized source-control handoff.{0,180}directly completes the task-scoped spec and quality reviews.{0,180}pre-commit receipts.{0,180}exact issue, owner, assignment, relations, worktree, branch, parent, and reviewed diff", "does not gate coder source control on direct reviews, receipts, and a fresh exact recheck"),
    (r"one bounded `woostack-commit` action for that exact issue/worktree/branch", "does not constrain the coder to one exact commit action"),
    (r"own implementation Git/Graphite/GitHub credentials and separate official MCP context.{0,180}execute exactly the `woostack-commit` boundary", "does not isolate the coder's Git and official MCP contexts"),
    (r"commit and push the reviewed bytes.{0,120}submit or update that issue's PR", "does not bound the delegated commit and PR source-control actions"),
    (r"append and read back its `implementationEvidence`", "does not permit exact commit-owned implementation evidence"),
    (r"create or refresh and read back the exact native PR relation", "does not permit the exact commit-owned PR relation"),
    (r"initial submission only.{0,120}`executing` to `inReview`.{0,100}read that state back", "does not bound the initial commit-owned inReview transition"),
    (r"later PR update.{0,160}issue remains `inReview`.{0,100}may not replay the transition", "allows a later update to replay the inReview transition"),
    (r"native Git, GitHub, relation, event, and state receipts.{0,120}independent controller read-back", "does not return complete delegated-commit receipts"),
    (r"handoff grants no second implementation pass, merge, acceptance.{0,180}any other lifecycle, event, relation, gate, project, or issue mutation.{0,100}retry requires another fresh controller authorization", "allows source-control handoff to broaden authority or retry stale authorization"),
    (r"freshly re-resolved pinned project lead deliberately allocates each project issue", "does not require deliberate lead allocation"),
    (r"never selects the first available issue, claims an unowned issue", "does not reject self-selection/self-claim"),
    (r"human engineer is assigned through the native issue assignee.{0,180}app engineer is delegated through the native issue delegate", "does not enforce type-aware assignee/delegate ownership"),
    (r"Neither field is a fallback for the other", "allows assignee/delegate fallback"),
    (r"Assignment acceptance before work.{0,460}canonical state and `assignmentAccepted` boundary.{0,180}independently reads both receipts back", "does not require assignmentAccepted and state read-back before work"),
    (r"No worktree or registry claim, branch, worker dispatch, tracked edit, test mutation, commit, push, PR action, or lifecycle side effect may occur before", "does not gate all side effects on assignment acceptance"),
    (r"Immediately before every such side effect or redispatch.{0,220}re-reads the issue, type-aware owner, current `assignmentAccepted`, state, project/relations", "does not recheck state/owner/relations before side effects"),
    (r"Parallel work is permitted only for dependency-independent.{0,300}disjoint issue IDs", "does not make parallelism relation-aware and disjoint"),
    (r"One engineer unit admits at most one actively executing issue", "allows one unit to execute multiple issues concurrently"),
    (r"Handoff.{0,180}appends and reads back canonical `handoff`.{0,220}changes and reads back the correct assignee/delegate.{0,260}new `assignmentAccepted` before resuming", "does not enforce typed handoff/reassignment/reacceptance order"),
    (r"Collision.{0,300}stop before delete, overwrite, reassign, replay, or create-around", "does not stop safely on a collision"),
    (r"outside the standing authority envelope.{0,220}escalates to the named human principal and remains stopped", "does not escalate out-of-envelope questions to the human principal"),
    (r"By default the decision-maker performs.{0,220}never delegates review back to the paired coding profile", "does not keep ordinary review with the decision-maker"),
    (r"Only an explicit user invocation of `/woostack-review` permits.{0,240}independent reviewer profiles", "does not constrain the explicit review delegation exception"),
    (r"implementing coding profile.{0,100}(?:is not an eligible reviewer|fails the review gate)", "allows the implementing coder to review its work"),
    (r"For each dispatch, the controller records the reviewer profile, session ID, native host principal ID, and non-secret credential context ID from host-owned metadata.{0,180}implementing-coder and decision-maker constraints", "does not pin delegated reviewer identity from host-owned metadata"),
    (r"never derives that manifest from a worker claim", "allows a review worker to define its own identity manifest"),
    (r"receipt is valid only when its exact binding matches that manifest, differs from both engineer roles, and declares `authority:\"advisory-only\"`", "does not require exact independent advisory reviewer receipts"),
    (r"missing/foreign binding, the implementing coding profile, or a shared profile, session, principal, or credential context fails the review gate", "does not fail closed on paired or shared reviewer identity"),
    (r"Native GitHub actor proof.{0,260}implementation author's immutable native GitHub principal ID.{0,260}authenticated reviewer's immutable native GitHub principal ID", "does not require native implementation-author and reviewer principal read-backs"),
    (r"Both reads must be complete and unambiguous", "allows incomplete or ambiguous native GitHub actor proof"),
    (r"host-profile, session, login, credential, or token-store name.{0,180}is not a native actor read-back", "allows a host/profile or credential label to substitute for native actor proof"),
    (r"`APPROVE` is eligible only when the two proven native IDs differ", "does not require distinct proven native GitHub principals before APPROVE"),
    (r"If they match, or either ID is missing, ambiguous, or unproved.{0,180}accurate review status line.{0,100}`COMMENT`", "does not preserve COMMENT fallback when native actor proof fails"),
    (r"A coder, implementing profile, reviewer, delegated review worker, or unauthenticated controller must never accept its own work", "does not prohibit self-acceptance"),
    (r"Project acceptance remains with the freshly re-resolved pinned project lead", "does not preserve project acceptance authority"),
    (r"Every dispatch and handback carries.{0,500}It carries no credential or token", "does not define a non-secret fail-closed handback"),
):
    require("generic", pattern, message)

ordered(
    "generic",
    (r"Lead allocation", r"Assignment acceptance before work", r"Relation-aware parallelism"),
    "does not order allocation before acceptance and execution classification",
)
ordered(
    "generic",
    (r"outgoing decision-maker appends", r"lead/dispatcher deliberately changes", r"incoming decision-maker refreshes", r"new `assignmentAccepted`"),
    "does not order outgoing handoff, reassignment, refresh, and incoming acceptance",
)

# Entry routing must make the shared protocol and canonical schemas unavoidable.
for pattern, message in (
    (r"references/engineer-agents\.md", "does not route paired-profile work through the shared contract"),
    (r"artifact-backends\.md#versioned-managed-metadata", "does not link the canonical managed envelope schema"),
    (r"artifact-backends\.md#canonical-issue-event-dispatch-and-pre-commit-evidence", "does not link the canonical issue-event schema"),
    (r"conventions\.md#issue-state-and-events", "does not link the canonical issue lifecycle"),
    (r"one standing authority envelope, one stable `ENGINEER_NAME`, one Linear principal, one decision-maker profile/session, one isolated coding profile/session", "does not summarize the complete engineer unit"),
    (r"separate host secret/token/session contexts", "does not preserve per-profile secret/session isolation"),
    (r"project lead or standalone dispatcher deliberately allocates work.{0,180}`assignmentAccepted` before work", "does not summarize allocation before assignment acceptance"),
    (r"rechecks owner, state, and relations before each side effect", "does not summarize the pre-side-effect recheck"),
):
    require("routing", pattern, message)

# Execute repeats the barriers in the actual coding-worker admission/dispatch surface.
for pattern, message in (
    (r"using-woostack/references/engineer-agents\.md", "does not load the shared engineer authority"),
    (r"artifact-backends\.md#versioned-managed-metadata", "does not link the canonical managed envelope schema"),
    (r"artifact-backends\.md#canonical-issue-event-dispatch-and-pre-commit-evidence", "does not link the canonical issue-event schema"),
    (r"conventions\.md#issue-state-and-events", "does not link the canonical issue lifecycle"),
    (r"standing authority envelope, stable `ENGINEER_NAME`, exact Linear principal kind/native ID, decision-maker profile/session, isolated coding profile/session", "does not bind the complete engineer unit before allocation"),
    (r"each resolves it through a separate official host secret/token/MCP session", "does not isolate the controller/coder authority contexts"),
    (r"Never self-claim an unassigned issue.{0,220}deliberately assign or delegate", "does not reject self-claim before deliberate allocation"),
    (r"No branch, worktree, edit, test mutation, commit, push, or PR action may precede.{0,100}`assignmentAccepted` receipts", "does not gate repository side effects on assignment acceptance"),
    (r"Decision-maker/coder separation.{0,280}never authors or modifies tracked implementation/test bytes.{0,120}runs implementation or test commands", "does not prohibit controller implementation/test execution"),
    (r"No self-admission.{0,220}cannot self-claim.{0,160}author `assignmentAccepted`", "does not prohibit coder self-admission"),
    (r"Bounded mutation only.{0,300}cannot read or mutate another issue/worktree", "does not prohibit out-of-scope coder mutation"),
    (r"implementing coding profile is never its own spec, quality, or PR reviewer and never accepts its own work", "does not prohibit coder review/self-acceptance"),
    (r"make a product or scope decision.{0,240}any other issue", "does not prohibit coder product/scope and other-issue mutation"),
    (r"touch another issue/worktree.{0,240}append project updates.{0,160}clear a gate", "does not prohibit coder issue/project/gate mutation"),
    (r"self-claim, author `assignmentAccepted`.{0,220}accept its own work.{0,100}terminal `done`", "does not repeat coder self-claim/self-acceptance/terminal prohibitions"),
    (r"commit, push, submit, create/update a PR, merge, force-push, or restack when the controller owns those boundaries", "does not preserve controller-owned source-control boundaries"),
    (r"Immediately before every driver dispatch or redispatch, first tracked edit, registry/worktree claim, lifecycle mutation, commit, push, or PR/GitHub side effect.{0,260}current semantic state.{0,180}relations.{0,180}`assignmentAccepted`.{0,140}owner", "does not recheck issue state/owner/relations before every side effect"),
):
    require("controller", pattern, message)

# The subagent driver must select the engineer-pair review path without removing generic execution.
for pattern, message in (
    (r"using-woostack/references/engineer-agents\.md", "does not load the shared engineer authority"),
    (r"Engineer pair.{0,180}paired coder implements and self-checks.{0,180}decision-maker performs the ordered task-scoped spec review then quality review directly", "does not route paired implementation and ordered review to the coder and decision-maker"),
    (r"Generic non-paired execution.{0,180}fresh implementer.{0,180}spec-compliance reviewer.{0,180}quality reviewer", "does not preserve generic implementer and reviewer dispatch"),
    (r"complete engineer unit.{0,220}decision-maker profile/session.{0,180}coding profile/session.{0,180}selects the engineer-pair route", "does not select paired execution from a complete verified unit"),
    (r"partial, stale, shared, or inferred pairing blocks.{0,140}must not degrade into generic execution", "allows an invalid engineer pair to degrade into generic execution"),
    (r"engineer-pair route, only the paired coding profile implements.{0,220}self-checks.{0,260}decision-maker.{0,220}performs both ordered reviews.{0,120}authors the review receipts", "does not keep paired implementation/self-check and direct review with their proper roles"),
    (r"decision-maker.{0,320}never modifies implementation/test bytes, runs implementation or test commands, or applies a fix", "allows the reviewing decision-maker to code or run implementation checks"),
    (r"paired coder is never a spec, quality, or PR reviewer.{0,100}self-check is not independent review evidence", "allows paired-coder self-check to become independent review"),
    (r"Perform task-scoped spec review.{0,260}Engineer pair.{0,180}decision-maker directly reviews.{0,180}authors the spec-review receipt.{0,120}does not dispatch a separate reviewer", "does not perform paired spec review directly without separate delegation"),
    (r"Generic non-paired execution.{0,120}dispatch a spec-compliance reviewer", "does not preserve generic spec-reviewer dispatch"),
    (r"Perform task-scoped quality review only after spec compliance passes.{0,260}Engineer pair.{0,180}decision-maker directly reviews.{0,180}authors the quality-review receipt.{0,120}does not dispatch a separate reviewer", "does not perform paired quality review directly and after spec review"),
    (r"Generic non-paired execution.{0,120}dispatch a quality reviewer", "does not preserve generic quality-reviewer dispatch"),
    (r"For an engineer pair, the decision-maker authors the two ordered task review receipts.{0,180}generic non-paired execution.{0,180}dispatched reviewers return those receipts", "does not assign receipt authorship by route"),
    (r"Only an explicit user invocation of `/woostack-review` permits.{0,220}configured independent reviewer profiles", "does not limit independent reviewer delegation to the explicit review command"),
    (r"paired coder is never eligible", "allows the paired coder to become a delegated reviewer"),
    (r"engineer-pair decision-maker.{0,180}authors canonical `precommitReview`.{0,220}two ordered `PASS` receipt records", "does not make the paired decision-maker author ordered precommit review evidence"),
    (r"sole exception to the paired coder's source-control prohibition.{0,180}generic non-paired execution keeps its existing controller-owned `woostack-commit` path", "does not preserve generic controller-owned commit while bounding the paired exception"),
    (r"Only after the decision-maker has directly completed every task-scoped spec review then quality review.{0,220}pre-commit receipts.{0,180}canonical `precommitReview`.{0,260}exact issue, type-aware owner, assignment, relations, worktree, branch, parent, and reviewed diff.{0,180}one bounded `woostack-commit`", "does not gate paired source control on ordered reviews, receipts, read-back, and a fresh exact recheck"),
    (r"own isolated implementation Git/Graphite/GitHub credentials.{0,100}separately isolated official Linear MCP authentication context.{0,180}canonical `woostack-commit` order", "does not isolate the paired coder's Git and official MCP contexts"),
    (r"append and independently read back.{0,100}`implementationEvidence`.{0,180}create or refresh and read back.{0,100}native Linear PR relation.{0,180}initial submission only.{0,120}`executing` to `inReview` once.{0,100}read it back", "does not bound the paired commit event, relation, and initial state mutations"),
    (r"later update independently confirms.{0,100}remains `inReview`.{0,100}cannot replay the transition", "allows a paired later update to replay the inReview transition"),
    (r"all native Git, GitHub, and Linear receipts.{0,120}decision-maker's independent read-back", "does not return complete paired-commit receipts"),
    (r"grants no second implementation pass, merge, force-push, restack, acceptance.{0,180}other Linear event/relation/lifecycle or project/issue mutation.{0,180}cross-issue authority.{0,180}retry requires another fresh controller authorization", "allows the paired source-control action to broaden authority or reuse stale authorization"),
    (r"Acceptance remains exclusively with the freshly verified responsible authority", "does not preserve responsible acceptance authority"),
):
    require("subagent", pattern, message)

ordered(
    "subagent",
    (
        r"Perform task-scoped spec review",
        r"Perform task-scoped quality review only after spec compliance passes",
        r"Produce evidence",
        r"authors canonical `precommitReview`",
        r"Controller-authorized source-control handoff",
        r"one bounded `woostack-commit`",
    ),
    "does not order paired spec review, quality review, receipts, precommitReview, and source-control handoff",
)

# Review repeats both paired-coder and delegated-reviewer prohibitions at the dispatch boundary.
for pattern, message in (
    (r"using-woostack/references/engineer-agents\.md", "does not load the shared engineer authority"),
    (r"artifact-backends\.md#versioned-managed-metadata", "does not link the canonical managed envelope schema"),
    (r"artifact-backends\.md#canonical-issue-event-dispatch-and-pre-commit-evidence", "does not link the canonical issue-event schema"),
    (r"conventions\.md#issue-state-and-events", "does not link the canonical issue lifecycle"),
    (r"decision-maker profile reviews and comments directly by default and never authors or modifies implementation/test bytes.{0,120}runs implementation or test commands", "does not keep ordinary review with a non-coding decision-maker"),
    (r"paired coding profile is ineligible for default or independent review and is barred from.{0,40}accepting its own work", "allows the paired coder to review or self-accept"),
    (r"Only an explicit user invocation of `/woostack-review`.{0,180}independent reviewer delegation", "does not constrain delegated review to explicit invocation"),
    (r"paired coding profile remains confined to its accepted issue and verified repository surface", "does not preserve the paired coder's one-issue surface"),
    (r"cannot self-claim or author `assignmentAccepted`.{0,420}issue/project contract.{0,300}another issue/worktree", "does not repeat paired-coder admission and out-of-scope mutation prohibitions"),
    (r"post a review verdict.{0,120}author `reviewResult`.{0,120}accept its own work.{0,120}terminal completion", "does not repeat paired-coder review/acceptance prohibitions"),
    (r"implementing coder and every delegated reviewer use distinct profiles and fresh isolated sessions", "does not isolate reviewers from the implementing coder"),
    (r"reviewer receives no engineer/Linear principal credential or token.{0,280}writable repository surface", "does not isolate reviewer credentials and write surfaces"),
    (r"Review workers are advisory only.{0,280}change Git/GitHub/Linear state.{0,220}acceptance.{0,20}terminal[- ]completion", "does not keep review workers advisory-only"),
    (r"Do not claim or accept the issue.{0,220}edit implementation/tests.{0,220}post to GitHub.{0,180}author Linear events.{0,180}accept your own or the coder's work", "does not repeat prohibitions in the spawned reviewer brief"),
    (r"engineer-unit local run.{0,180}controller MUST set `WOO_REVIEW_ENGINEER_UNIT=true` and write a controller-owned identity manifest", "does not require the controller-owned engineer reviewer manifest"),
    (r"implementingCoder:\{profile,sessionId,principalId,credentialContextId\}.{0,180}decisionMaker:\{profile,sessionId,principalId,credentialContextId\}.{0,240}reviewerProfile,reviewerSessionId,reviewerPrincipalId,reviewerCredentialContextId", "does not bind coder, decision-maker, and reviewer receipt identities"),
    (r"All values are non-secret host bindings.{0,180}exactly one reviewer binding per expected angle/chunk", "does not constrain reviewer manifests to host bindings per dispatch"),
    (r"implementing coder and decision-maker have different profile, session, (?:native host principal, and )?credential-context IDs.{0,180}Every reviewer binding differs from both roles and every other reviewer in profile, session, native host principal, and credential context", "does not require coder, decision-maker, and cross-reviewer identity isolation"),
    (r"Workers receive only their own exact reviewer binding and MUST NOT author or modify the manifest", "allows workers to claim or alter receipt identity"),
    (r"authority:\"advisory-only\".{0,200}exactly match the one controller-owned reviewer binding.{0,180}rejects the paired coder, the decision-maker, a shared profile/session/native principal/credential context", "does not hard-fail non-advisory, paired, decision-maker, or shared reviewer receipts"),
    (r"implementation author's immutable native GitHub principal ID.{0,220}authenticated reviewer actor's immutable native GitHub principal ID", "does not read back both native GitHub actors before posting"),
    (r"Both reads must be complete and unambiguous", "allows incomplete or ambiguous reviewer actor proof"),
    (r"host/profile/session/login, credential or token-store name.{0,180}is not native actor proof", "allows host profile or token-store identity to substitute for native GitHub proof"),
    (r"Permit `APPROVE` only when both native principal-ID read-backs are proven and the IDs differ", "does not require distinct proven native GitHub principals before APPROVE"),
    (r"If the IDs match or either ID is missing, ambiguous, or unproved.{0,180}`COMMENT`.{0,120}accurate STATUS_LINE", "does not preserve COMMENT fallback when native actor proof fails"),
    (r"decision-maker/orchestrator owns this stage.{0,220}Delegated reviewer workers never post, approve, request changes, or comment directly", "does not preserve orchestrator-owned review posting"),
):
    require("review", pattern, message)

unsafe = (
    (r"(?:engineer unit|coding profile|coding worker|coder).{0,100}(?:may|can|should)\s+(?:self-claim|claim an unowned|claim an unassigned)", "positively permits coder self-claim"),
    (r"decision-maker.{0,100}(?:may|can|should).{0,50}(?:author|edit|modify).{0,50}(?:implementation|source|test)", "positively permits decision-maker coding"),
    (r"decision-maker.{0,100}(?:may|can|should).{0,60}run.{0,50}(?:implementation|tests?|test commands?)", "positively permits decision-maker implementation/test execution"),
    (r"concurrent (?:engineer )?units?.{0,120}(?:may|can|should).{0,50}(?:share|reuse|pool).{0,60}(?:identity|principal|profile|credential|token|session)", "positively permits concurrent units to share authority context"),
    (r"(?:paired|implementing) (?:coding profile|coder).{0,100}(?:is|acts as|becomes).{0,30}(?:the )?default reviewer", "positively makes the paired coder the default reviewer"),
    (r"(?:under|for|on) (?:an? )?engineer[- ]pair.{0,120}(?:always|by default|unconditionally|must|should|may|can).{0,80}(?:dispatch|delegate).{0,100}(?:separate|independent).{0,100}(?:spec|quality).{0,60}reviewers?", "positively requires separate reviewer delegation for an engineer pair"),
    (r"(?:reviewer (?:receipt|binding)|delegated reviewer).{0,100}(?:may|can|should).{0,80}(?:share|reuse|match).{0,100}(?:paired|implementing).{0,80}(?:coder|coding profile)", "positively permits a reviewer to share implementing-coder identity"),
    (r"reviewer (?:receipt|binding).{0,100}(?:may|can|should).{0,80}(?:share|reuse|match).{0,100}(?:another|other).{0,40}reviewer", "positively permits reviewers to share identity"),
    (r"(?:coding profile|coding worker|coder).{0,100}(?:may|can|should).{0,60}accept (?:its|their) own work", "positively permits coder self-acceptance"),
    (r"(?:coding profile|coding worker|coder).{0,100}(?:may|can|should)\b.{0,60}(?:change|edit|mutate).{0,80}(?:another issue|project update|project status|project gate|clear a gate)", "positively permits out-of-scope issue/project mutation"),
    (r"(?:coding profile|coding worker|coder).{0,100}(?:may|can|should).{0,60}(?:begin|start|perform).{0,80}(?:edit|side effect).{0,80}before `?assignmentAccepted`?", "positively permits work before assignmentAccepted read-back"),
    (r"app engineer.{0,100}(?:uses|maps|compares).{0,80}(?:native issue )?assignee", "positively maps an app engineer to the assignee"),
    (r"parallel work.{0,100}(?:may|can|should).{0,80}(?:ordinal adjacency|adjacent ordinals)", "positively permits ordinal-derived parallelism"),
    (r"incoming (?:engineer )?unit.{0,100}(?:may|can|should).{0,80}resume.{0,100}reassignment.{0,100}without.{0,100}(?:handoff|`?assignmentAccepted`?)", "positively permits an incomplete handoff"),
)
for label in ("generic", "controller", "subagent", "review"):
    for paragraph in paragraphs(texts.get(label, "")):
        for pattern, message in unsafe:
            if re.search(pattern, paragraph, re.I | re.S):
                failure(label, message)

if failures:
    print("\n".join(failures))
    raise SystemExit(1)
print("validated provider-neutral engineer authority across routing, execution, and review")
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
  local destination="$1" relative
  for relative in "${CONTRACT_FILES[@]}"; do
    mkdir -p "$destination/$(dirname "$relative")"
    cp "$ROOT/$relative" "$destination/$relative"
  done
}

replace_literal() {
  python3 - "$1" "$2" "$3" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
old, new = sys.argv[2], sys.argv[3]
text = path.read_text(encoding="utf-8")
if old not in text:
    raise SystemExit(f"fixture source text not found: {old}")
path.write_text(text.replace(old, new, 1), encoding="utf-8")
PY
}

record_analysis "$ROOT" "repository engineer-agent contract"

fixture="$TMP_ROOT/canonical-schema-link"
make_fixture "$fixture"
replace_literal \
  "$fixture/skills/using-woostack/references/engineer-agents.md" \
  "artifact-backends.md#canonical-issue-event-dispatch-and-pre-commit-evidence" \
  "artifact-backends.md"
expect_fixture_failure "$fixture" "does not link the canonical issue-event schema" \
  "canonical schema cross-link is load-bearing"

fixture="$TMP_ROOT/human-escalation"
make_fixture "$fixture"
replace_literal \
  "$fixture/skills/using-woostack/references/engineer-agents.md" \
  "escalates to the named human principal and remains stopped" \
  "remains unresolved"
expect_fixture_failure "$fixture" "does not escalate out-of-envelope questions to the human principal" \
  "human escalation is load-bearing"

fixture="$TMP_ROOT/shared-unit-secret-store"
make_fixture "$fixture"
replace_literal \
  "$fixture/skills/using-woostack/references/engineer-agents.md" \
  "own official host MCP/OAuth secret store" \
  "a shared host secret store"
expect_fixture_failure "$fixture" "does not isolate the two host secret stores" \
  "paired-profile secret-store isolation"

fixture="$TMP_ROOT/shared-concurrent-context"
make_fixture "$fixture"
printf '\nConcurrent engineer units may share one Linear principal, token, and session.\n' \
  >> "$fixture/skills/using-woostack/references/engineer-agents.md"
expect_fixture_failure "$fixture" "positively permits concurrent units to share authority context" \
  "concurrent identity/token/session isolation"

fixture="$TMP_ROOT/cross-type-owner"
make_fixture "$fixture"
printf '\nAn app engineer uses the native issue assignee as its work owner.\n' \
  >> "$fixture/skills/using-woostack/references/engineer-agents.md"
expect_fixture_failure "$fixture" "positively maps an app engineer to the assignee" \
  "type-aware app delegate ownership"

fixture="$TMP_ROOT/ordinal-parallelism"
make_fixture "$fixture"
printf '\nParallel work may rely on ordinal adjacency when branch names differ.\n' \
  >> "$fixture/skills/using-woostack/references/engineer-agents.md"
expect_fixture_failure "$fixture" "positively permits ordinal-derived parallelism" \
  "relation-aware parallelism"

fixture="$TMP_ROOT/incomplete-handoff"
make_fixture "$fixture"
printf '\nAn incoming engineer unit may resume after reassignment without handoff or `assignmentAccepted`.\n' \
  >> "$fixture/skills/using-woostack/references/engineer-agents.md"
expect_fixture_failure "$fixture" "positively permits an incomplete handoff" \
  "typed handoff and reassignment acceptance"

fixture="$TMP_ROOT/decision-maker-codes"
make_fixture "$fixture"
printf '\nThe decision-maker must not edit implementation bytes, but may modify tests when the coder is busy.\n' \
  >> "$fixture/skills/using-woostack/references/engineer-agents.md"
expect_fixture_failure "$fixture" "positively permits decision-maker coding" \
  "mixed prohibitive and permissive decision-maker paragraph"

fixture="$TMP_ROOT/coder-self-claim"
make_fixture "$fixture"
printf '\nA coding worker may self-claim an unassigned issue and begin implementation.\n' \
  >> "$fixture/skills/woostack-execute/references/controller.md"
expect_fixture_failure "$fixture" "positively permits coder self-claim" \
  "coder self-claim prohibition"

fixture="$TMP_ROOT/preaccept-edit"
make_fixture "$fixture"
printf '\nA coder may begin a tracked edit before `assignmentAccepted` reads back.\n' \
  >> "$fixture/skills/woostack-execute/references/controller.md"
expect_fixture_failure "$fixture" "positively permits work before assignmentAccepted read-back" \
  "assignment acceptance side-effect barrier"

fixture="$TMP_ROOT/out-of-scope-mutation"
make_fixture "$fixture"
printf '\nA coding worker may change another issue or clear a project gate to unblock itself.\n' \
  >> "$fixture/skills/woostack-execute/references/controller.md"
expect_fixture_failure "$fixture" "positively permits out-of-scope issue/project mutation" \
  "out-of-scope coder mutation prohibition"

fixture="$TMP_ROOT/paired-default-review"
make_fixture "$fixture"
printf '\nThe paired coding profile is the default reviewer for its implementation.\n' \
  >> "$fixture/skills/woostack-review/SKILL.md"
expect_fixture_failure "$fixture" "positively makes the paired coder the default reviewer" \
  "paired-coder default-review prohibition"

fixture="$TMP_ROOT/paired-unconditional-review-delegation"
make_fixture "$fixture"
printf '\nUnder an engineer pair, always dispatch separate spec and quality reviewers for every task.\n' \
  >> "$fixture/skills/woostack-execute/references/subagent-driver.md"
expect_fixture_failure "$fixture" "positively requires separate reviewer delegation for an engineer pair" \
  "engineer-pair direct-review authority"

fixture="$TMP_ROOT/native-actor-distinct-approval"
make_fixture "$fixture"
replace_literal \
  "$fixture/skills/woostack-review/SKILL.md" \
  'Permit `APPROVE` only when both native principal-ID read-backs are proven and the IDs differ.' \
  'Permit `APPROVE` whenever the candidate event permits it.'
expect_fixture_failure "$fixture" "does not require distinct proven native GitHub principals before APPROVE" \
  "native GitHub actors must differ for APPROVE"

fixture="$TMP_ROOT/native-actor-comment-fallback"
make_fixture "$fixture"
replace_literal \
  "$fixture/skills/woostack-review/SKILL.md" \
  'If the IDs match or either ID is missing, ambiguous, or unproved, replace the candidate event with `COMMENT` while retaining the accurate STATUS_LINE.' \
  'If native actor proof fails, retain the candidate event.'
expect_fixture_failure "$fixture" "does not preserve COMMENT fallback when native actor proof fails" \
  "unproved or same-actor review falls back to COMMENT"

fixture="$TMP_ROOT/reviewer-worker-claim"
make_fixture "$fixture"
replace_literal \
  "$fixture/skills/using-woostack/references/engineer-agents.md" \
  'it never derives that manifest from a worker claim.' \
  'it may derive that manifest from a worker claim.'
expect_fixture_failure "$fixture" "allows a review worker to define its own identity manifest" \
  "reviewer identity comes from controller-owned host metadata"

fixture="$TMP_ROOT/reviewer-shares-coder-identity"
make_fixture "$fixture"
printf '\nA reviewer receipt may share the paired coder profile, session, principal, and credential context.\n' \
  >> "$fixture/skills/woostack-review/SKILL.md"
expect_fixture_failure "$fixture" "positively permits a reviewer to share implementing-coder identity" \
  "reviewer receipt identity must differ from the paired coder"

fixture="$TMP_ROOT/reviewers-share-identity"
make_fixture "$fixture"
printf '\nA reviewer binding may share another reviewer profile, session, native host principal, and credential context.\n' \
  >> "$fixture/skills/woostack-review/SKILL.md"
expect_fixture_failure "$fixture" "positively permits reviewers to share identity" \
  "reviewer bindings must be mutually unique"

fixture="$TMP_ROOT/coder-self-acceptance"
make_fixture "$fixture"
printf '\nA coding profile may accept its own work after self-review.\n' \
  >> "$fixture/skills/woostack-review/SKILL.md"
expect_fixture_failure "$fixture" "positively permits coder self-acceptance" \
  "coder self-acceptance prohibition"

fixture="$TMP_ROOT/mixed-prohibition-and-permission"
make_fixture "$fixture"
printf '\nA coding profile must not accept its own work, but a coding profile may change another issue.\n' \
  >> "$fixture/skills/woostack-review/SKILL.md"
expect_fixture_failure "$fixture" "positively permits out-of-scope issue/project mutation" \
  "unsafe permission is detected inside a prohibitive paragraph"

finish
