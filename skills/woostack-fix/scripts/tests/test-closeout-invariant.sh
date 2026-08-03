#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
python3 - "$ROOT" <<'PY'
import copy,hashlib,json,re,sys,unicodedata
from pathlib import Path
root=Path(sys.argv[1]); failures=[]
skill=re.sub(r"\s+"," ",(root/"skills/woostack-fix/SKILL.md").read_text())
artifact=re.sub(r"\s+"," ",(root/"skills/woostack-init/references/artifact-backends.md").read_text())
combined=f"{skill} {artifact}"

def fingerprint(value):
    if not isinstance(value,dict) or set(value) != {"title","description","dependencies"}: raise ValueError("fingerprint input fields")
    if not isinstance(value["title"],str) or not isinstance(value["description"],str) or not isinstance(value["dependencies"],list): raise ValueError("fingerprint input types")
    whitespace={*(range(0x0009,0x000E)),0x0020,0x0085,0x00A0,0x1680,*range(0x2000,0x200B),0x2028,0x2029,0x202F,0x205F,0x3000}
    def normalize(text): return unicodedata.normalize("NFC",text).replace("\r\n","\n").replace("\r","\n")
    def trim_explicit(text):
        start=0; end=len(text)
        while start<end and ord(text[start]) in whitespace: start+=1
        while end>start and ord(text[end-1]) in whitespace: end-=1
        return text[start:end]
    def collapse_title(text):
        output=[]; in_run=False
        for char in text:
            if ord(char) in whitespace:
                if not in_run: output.append(" ")
                in_run=True
            else: output.append(char); in_run=False
        return trim_explicit("".join(output))
    dependencies=[]; seen=set()
    for dependency in value["dependencies"]:
        if not isinstance(dependency,dict) or set(dependency) != {"direction","kind","targetId"}: raise ValueError("dependency fields")
        if any(not isinstance(dependency[key],str) for key in ("direction","kind","targetId")): raise ValueError("dependency types")
        projected=tuple(normalize(dependency[key]) for key in ("direction","kind","targetId"))
        if projected[0] not in {"blocks","depends-on"} or projected[1]!="native-issue" or not projected[2]: raise ValueError("dependency projection")
        if projected in seen: raise ValueError("duplicate dependency")
        seen.add(projected); dependencies.append(projected)
    dependencies.sort()
    canonical={
        "title":collapse_title(normalize(value["title"])),
        "description":normalize(value["description"]),
        "dependencies":[{"direction":d,"kind":k,"targetId":t} for d,k,t in dependencies],
    }
    encoded=json.dumps(canonical,ensure_ascii=False,separators=(",",":")).encode("utf-8")
    return "sha256:"+hashlib.sha256(encoded).hexdigest()

vectors=[
    ({"title":"  Café\t refresh  ","description":"\r\nOne line \t\r\nTwo  spaces\r\n","dependencies":[{"direction":"blocks","kind":"native-issue","targetId":"z"},{"direction":"depends-on","kind":"native-issue","targetId":"a"}]},"sha256:603c1feee4d9d2cf2f83b309609655153096d17c4b987bc82e9268dcdcfacf8a"),
    ({"title":"Cafe\u0301 refresh","description":"\nOne line \t\nTwo  spaces\n","dependencies":[{"direction":"depends-on","kind":"native-issue","targetId":"a"},{"direction":"blocks","kind":"native-issue","targetId":"z"}]},"sha256:603c1feee4d9d2cf2f83b309609655153096d17c4b987bc82e9268dcdcfacf8a"),
    ({"title":"Cache refresh!","description":"One line\nTwo  spaces","dependencies":[]},"sha256:d628b361d4b1bf159e541cea20c1817dffa5e5f2229c7c8278486961068129e0"),
    ({"title":"\u00a0A\u0085B\u00a0","description":"raw","dependencies":[{"direction":"blocks","kind":"native-issue","targetId":"x"}]},"sha256:0ac4af60e7fdc72dfa898a8961925f23d7808a20ff9c5cd1bf34c6d4297ff249"),
    ({"title":"\ufeffA\u200bB\u001cC","description":"raw","dependencies":[]},"sha256:5f716498cd632e6dfac9dfe79b1d451c766ff50ca9551cd8a7619dafab67664d")]
for vector,expected in vectors:
    if fingerprint(vector)!=expected: failures.append("fingerprint golden vector")
if fingerprint(vectors[0][0])!=fingerprint(vectors[1][0]): failures.append("NFC/order equality")
if fingerprint(vectors[0][0])==fingerprint({**vectors[0][0],"description":"material change"}): failures.append("material inequality")
if fingerprint(vectors[3][0])!=fingerprint({**vectors[3][0],"title":" A B "}): failures.append("explicit NBSP/NEL title normalization")
if fingerprint(vectors[4][0])==fingerprint({**vectors[4][0],"title":"ABC"}): failures.append("BOM/ZWSP/control separator preservation")
try: fingerprint({**vectors[0][0],"dependencies":[vectors[0][0]["dependencies"][0],vectors[0][0]["dependencies"][0]]})
except ValueError: pass
else: failures.append("fingerprint rejects duplicate dependency")

checks={
"debug boundary":r"free-form prompt only.*fix-origin.*omit/defer.*--issue.*prohibit all provider",
"driver default":r"Use a subagent when available by default",
"driver degradation":r"explicitly requested subagent is unavailable.*disclose the degradation.*run inline only when safe",
"no project grammar":r"no `--project` path",
"proved root cause":r"root cause and causal chain",
"no patch":r"Do not patch during diagnosis",
"no issue before proof":r"before root-cause proof.*no provider read or write",
"one issue":r"bind exactly one issue",
"exact compatibility":r"native work-item type.*Reject an incompatible project-backed build/plan artifact",
"exact native team":r"Accept any native team in the resolved caller-selected workspace.*configured team defaults apply only when creating",
"stable create":r"stable client mutation identity",
"same identity recovery":r"same mutation identity",
"independent readback":r"independently read.*back",
"official MCP":r"authenticated official Linear MCP",
"security":r"Never read, print, copy, or request credentials",
"one gate":r"one hard gate.*approve-to-execute",
"approval record":r"fixApprovalRecord.*issueId.*canonicalContentFingerprint.*approvedBy.*approvedAt.*approvalEventRef",
"execute issue":r"woostack-execute.*--issue.*exactly one matching `fixApprovalRecord`",
"native approval":r"responsible user.*approve the exact Linear issue revision.*approve-to-execute comment or decision",
"no sibling plan payload":r"write only the selected title and description plus required dependencies",
"explicit whitespace":r"U\+0009.*U\+3000.*U\+FEFF.*U\+200B",
"native dependency projection":r"blocks.*blockedBy.*direction.*kind.*targetId.*native-issue",
"projection exclusions":r"Exclude project membership, parent/child containment, duplicate, related",
"review":r"Require task-wide contract and quality review.*woostack-commit.*final exact issue/relation/approval-record recheck",
"delivery":r"independently read the write back",
"abandon":r"preserve the exact bound or created issue",
"closure distinction":r"Project cancellation applies only to project-backed build/plan workflows",
"executor-ready fields":r"observed and expected behavior.*direct evidence.*ordered file/symbol.*documentation, migration effects",
"approval fingerprint":r"canonicalContentFingerprint.*Normalize `title`.*Normalize `description`.*native-relation read",
"approval provenance":r"approvedBy.*stable native principal ID.*approvedAt.*approvalEventRef.*explicit approval",
"material invalidation":r"material.*invalidates approval.*unrelated comments.*metadata.*do not",
"recheck cadence":r"before execution.*after every worker handback.*before every redispatch.*immediately before commit",
"linear failure boundary":r"required Linear read.*blocks.*no conversational",
"never merge":r"never merges"}
for n,p in checks.items():
    if not re.search(p,combined,re.I|re.S): failures.append(n)
if re.search(r"fix plan is persisted as one project|fixes use one project.*parent plan issue.*child increment",skill,re.I|re.S): failures.append("fix hierarchy")
if "historicalProjectBackedFix" in combined or "fixApprovalReceipt" in combined: failures.append("removed fix compatibility shape")
if re.search(r"title/description/plan/dependency payload",skill,re.I|re.S): failures.append("production sibling plan payload")
if not re.search(r"write only the selected title and description plus required dependencies",skill,re.I|re.S): failures.append("production description-only plan proof")
evals=json.loads((root/"skills/woostack-fix/evals/evals.json").read_text()); ids={c["id"] for c in evals["cases"]}
for x in ("blocks-before-issue-when-root-cause-is-unproven","fix-debug-defers-supplied-issue-before-proof","plain-prompt-safe-creates-one-issue","exact-issue-reuses-only-that-issue","ambiguous-foreign-conflicting-identities-block","timeout-recovery-reuses-same-mutation-identity"):
 if x not in ids: failures.append(f"missing eval {x}")
for x in ("exact-project-classification.json","explicit-project-create.json","selected-project-persistence.json"):
 if (root/"skills/woostack-fix/evals/fixtures"/x).exists(): failures.append(f"obsolete {x}")
f=json.loads((root/"skills/woostack-fix/evals/fixtures/approved-fix.json").read_text()); snapshots=f.get("approvalSnapshots")
if not isinstance(snapshots,dict) or set(snapshots)!={"positive","artifactOnly"}: failures.append("approval snapshots must have positive and artifactOnly")
else:
 positive=snapshots["positive"]; artifact_only=snapshots["artifactOnly"]
 def deep_normalize(value):
  if isinstance(value,dict): return {key:deep_normalize(value[key]) for key in sorted(value)}
  if isinstance(value,list): return [deep_normalize(item) for item in value]
  return value
 def snapshot_events(snapshot,name):
  events=snapshot.get("eventTranscript")
  if not isinstance(events,list) or not events: failures.append(f"{name} raw event transcript")
  if not isinstance(snapshot.get("issue"),dict) or not isinstance(snapshot.get("readBack"),dict): failures.append(f"{name} raw issue/read-back fields")
  if not isinstance(events,list): return []
  seen=set()
  for expected_sequence,event in enumerate(events,1):
   if not isinstance(event,dict) or not all(key in event for key in ("eventId","sequence","source","kind","causalRefs")): failures.append(f"{name} event shape"); continue
   if event["eventId"] in seen or event["sequence"]!=expected_sequence: failures.append(f"{name} event identity/order")
   seen.add(event["eventId"])
   if not isinstance(event["causalRefs"],list) or any(ref not in seen for ref in event["causalRefs"]): failures.append(f"{name} event causal references")
  return events
 positive_events=snapshot_events(positive,"positive"); artifact_events=snapshot_events(artifact_only,"artifactOnly")
 forbidden={"afterIssueReadBack","issueIdentityMatched","fingerprintMatched","otherPrerequisitesSatisfied","approvalAfterReadBack","approvalCausallyReferencesReadBack"}
 for name,snapshot in (("positive",positive),("artifactOnly",artifact_only)):
  if any(key in snapshot for key in forbidden): failures.append(f"{name} exposes derived approval booleans")
 responsible=[event for event in positive_events if isinstance(event,dict) and event.get("source")=="provider" and event.get("kind")=="responsible-user-native-approval"]
 negative_responsible=[event for event in artifact_events if isinstance(event,dict) and event.get("kind")=="responsible-user-native-approval"]
 if len(responsible)!=1: failures.append("positive responsible native approval event count")
 if negative_responsible: failures.append("artifactOnly responsible native approval event")
 if len(positive_events)!=len(artifact_events)+1: failures.append("approval counterfactual event count")
 elif len(responsible)==1:
  without_responsible_snapshot=copy.deepcopy(positive); counterfactual_events=without_responsible_snapshot["eventTranscript"]; responsible_event_id=responsible[0].get("eventId")
  matching_indexes=[index for index,event in enumerate(counterfactual_events) if isinstance(event,dict) and event.get("eventId")==responsible_event_id]
  if len(matching_indexes)!=1: failures.append("counterfactual responsible event removal")
  else:
   counterfactual_events.pop(matching_indexes[0])
   if deep_normalize(without_responsible_snapshot)!=deep_normalize(artifact_only): failures.append("approval snapshots differ beyond one event")
   drifted_artifact_only=copy.deepcopy(artifact_only); drifted_artifact_only["repositoryState"]["mutationCount"]+=1
   if deep_normalize(without_responsible_snapshot)==deep_normalize(drifted_artifact_only): failures.append("repository state drift escaped snapshot comparison")
 issue=positive.get("issue",{}); read_back=positive.get("readBack",{})
 if issue.get("issueId")!=read_back.get("issueId"): failures.append("positive issue identity derivation")
 if issue.get("canonicalContentFingerprint")!=read_back.get("canonicalContentFingerprint"): failures.append("positive fingerprint derivation")
 if issue.get("issueId")!=artifact_only.get("issue",{}).get("issueId") or issue.get("canonicalContentFingerprint")!=artifact_only.get("issue",{}).get("canonicalContentFingerprint"): failures.append("scenario raw identity/fingerprint mismatch")
 if responsible:
  approval=responsible[0]; readback_events=[event for event in positive_events if isinstance(event,dict) and event.get("kind")=="issue-read-back"]
  if len(readback_events)!=1: failures.append("positive issue read-back event count")
  else:
   readback=readback_events[0]
   if approval.get("sequence",0)<=readback.get("sequence",0): failures.append("approval sequence does not follow read-back")
   if readback.get("eventId") not in approval.get("causalRefs",[]): failures.append("approval causal reference does not name read-back")
  approval_record={key:approval.get(key) for key in ("issueId","canonicalContentFingerprint","approvedBy","approvedAt","approvalEventRef")}
  if approval_record!={
   "issueId":issue.get("issueId"),
   "canonicalContentFingerprint":issue.get("canonicalContentFingerprint"),
   "approvedBy":"user-adam",
   "approvedAt":"2026-08-02T18:41:00Z",
   "approvalEventRef":"comment-approval-241",
  } or approval.get("actor")!="user-adam" or approval.get("role")!="responsible-user" or approval.get("decision")!="approve-to-execute" or approval.get("explicit") is not True:
   failures.append("responsible native approval provenance")
def native_projection(event,name):
 raw=event.get("nativeRelations")
 if not isinstance(raw,list) or not raw:
  failures.append(f"{name} native relation read")
  return []
 directions={"blocks":"blocks","blockedBy":"depends-on"}
 projected=[]
 seen=set()
 for relation in raw:
  if not isinstance(relation,dict) or set(relation)!={"type","targetId"} or relation.get("type") not in directions or not isinstance(relation.get("targetId"),str) or not relation["targetId"]:
   failures.append(f"{name} native relation shape")
   continue
  item={"direction":directions[relation["type"]],"kind":"native-issue","targetId":relation["targetId"]}
  key=(item["direction"],item["kind"],item["targetId"])
  if key in seen: failures.append(f"{name} duplicate projected relation")
  seen.add(key); projected.append(item)
 return sorted(projected,key=lambda item:(item["direction"],item["kind"],item["targetId"]))
c=f["canonicalContent"]; canonical_input={"title":c["title"],"description":c["description"],"dependencies":c["dependencies"]}; expected_fingerprint="sha256:a58a9de055b26c0618e0ddc71eead9f1bf6ddf5f66bf49768c6488a4b74a1a12"
if fingerprint(canonical_input)!=expected_fingerprint: failures.append("fixture fingerprint digest")
for issue_key in ("suppliedIssue","createdIssue"):
 issue=f[issue_key]
 if "plan" in issue["content"] or issue["content"]["description"]!=c["description"] or issue["content"]["dependencies"]!=c["dependencies"]: failures.append(f"{issue_key} stores a plan outside the description")
 if "fixApprovalRecord" in issue: failures.append(f"{issue_key} exposes derived approval record")
 if any(key in issue for key in ("status","decision","result","expected","outputOracle")): failures.append(f"{issue_key} exposes derived oracle")
if "plan" in c: failures.append("canonical plan projection")
authority=f.get("authority",{})
if {key:authority.get(key) for key in ("approvalEventRef","approvedBy","approvedAt","fixApprovalSource")}!={"approvalEventRef":"comment-approval-241","approvedBy":"user-adam","approvedAt":"2026-08-02T18:41:00Z","fixApprovalSource":"responsible-user-native-approval"}: failures.append("fixture approval authority")
case_b=f["invocationRecords"].get("caseB",{}); events=f["providerEvents"]
for event_key in ("caseAReadBack","caseBReadBack"):
 if native_projection(events.get(event_key,{}),event_key)!=c["dependencies"]: failures.append(f"{event_key} native relation projection")
if case_b.get("issueArgument") is not None: failures.append("caseB must be plain prompt")
if case_b.get("providerEventRefs") != ["caseBCreateAttempt","caseBReadBack"]: failures.append("caseB ordered provider refs")
if case_b.get("workflowEventRefs") != []: failures.append("caseB approval refs must be empty")
attempt=events.get("caseBCreateAttempt",{}); readback=events.get("caseBReadBack",{})
if attempt.get("type")!="issue-create-attempt" or attempt.get("sequence")!=1 or attempt.get("eventId")!="caseB-create-attempt-242": failures.append("caseB raw create attempt")
if attempt.get("clientMutationId")!="12222222-2222-4222-8222-222222222222" or attempt.get("configuredTeamId")!=f["config"]["teamId"]: failures.append("caseB create identity/team")
if attempt.get("causalRefs")!=[]: failures.append("caseB create attempt causal refs")
if readback.get("type")!="issue-create-read-back" or readback.get("sequence")!=2 or readback.get("eventId")!="caseB-read-back-242": failures.append("caseB raw read-back")
if readback.get("causalRefs")!=["caseB-create-attempt-242"]: failures.append("caseB read-back causal link")
if any(readback.get(key)!=attempt.get(key) for key in ("issueId","clientMutationId")): failures.append("caseB read-back identity binding")
if readback.get("canonicalContentFingerprint")!=expected_fingerprint or readback.get("independentReadBack") is not True or readback.get("readComplete") is not True: failures.append("caseB read-back content completeness")
created=f["createdIssue"]
if created.get("issueId")!=readback.get("issueId") or created.get("clientMutationId")!=readback.get("clientMutationId"): failures.append("caseB created issue binding")
if created.get("content")!=c: failures.append("caseB created content raw match")
eval_case=next((case for case in evals["cases"] if case.get("id")=="plain-prompt-safe-creates-one-issue"),{})
assertions={assertion.get("id"):assertion for assertion in eval_case.get("assertions",[])}
if assertions.get("created-record-null-before-approval",{}).get("expected","missing") is not None: failures.append("caseB pre-approval null record assertion")
if assertions.get("created-approval-event-refs-empty",{}).get("expected","missing") != []: failures.append("caseB pre-approval event refs assertion")
if assertions.get("created-ready-for-decision",{}).get("expected","missing") is not True: failures.append("caseB ready-for-decision assertion")
if assertions.get("created-issue-count",{}).get("expected","missing") != 1: failures.append("caseB created issue count assertion")
for token in (f["contract"]["identities"]["worktree"],f["contract"]["identities"]["branch"],"## Ordered implementation steps","## Acceptance criteria","## Verification contract","## Documentation and migration effects"):
 if token not in c["description"]: failures.append("incomplete persisted description")
stale=f["staleMaterialRevision"]; changed_input={"title":c["title"],"description":stale["changedDescription"],"dependencies":stale["changedDependencies"]}; changed_fingerprint=fingerprint(changed_input)
if changed_fingerprint==expected_fingerprint or changed_fingerprint==fingerprint(canonical_input): failures.append("material description change did not change fingerprint")
if not (stale["sameIssueId"]=="issue-app-241" and stale["changedField"]=="description"): failures.append("stale raw provider event")
metadata=f["metadataOnlyRevision"]
if not (metadata["sameIssueId"]=="issue-app-241" and metadata["commentAdded"] and metadata["statusChanged"]): failures.append("metadata raw provider events")
unavailable=f["unavailableLinear"]
if unavailable.get("missingCapabilities") != ["exact issue read", "independent read-back"]: failures.append("unavailable raw capabilities")
for section in ("unavailableLinear","authority","safeCreate","exactReuse","blockedIdentities","timeoutRecovery"):
 if any(key in f[section] for key in ("status","decision","candidateDecisions","executionDelegated","providerMutationCount","localFallback","replacementCreated","allCandidatesRejected","createAttempts")): failures.append(f"{section} exposes derived workflow output")
if "candidateIdentities" in f["blockedIdentities"] or not f["blockedIdentities"].get("providerSnapshots"): failures.append("candidate identities must derive from one provider snapshot list")
if f["timeoutRecovery"].get("clientMutationId") != f["timeoutRecovery"].get("retryClientMutationId"): failures.append("timeout raw mutation identity")
exact_reuse=f["exactReuse"]
if exact_reuse.get("resolvedWorkspaceId")!=f["config"]["workspaceId"] or exact_reuse.get("resolvedTeamId")==f["config"]["teamId"] or exact_reuse.get("resolvedIssue")!=exact_reuse.get("suppliedIssue"): failures.append("exact supplied issue native-team admission")
if failures:
 print("fix contract violations:",file=sys.stderr); print("\n".join(f"- {x}" for x in failures),file=sys.stderr); raise SystemExit(1)
print("fix issue contract: ok")
PY
