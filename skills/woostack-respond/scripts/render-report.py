#!/usr/bin/env python3
"""Strict deterministic renderer for sanitized provider-neutral response input."""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unicodedata

TOP_FIELDS = {"schema_version", "signal", "scope", "environment", "window", "generated_at", "outcome", "investigation_bound", "coverage", "ranked_groups", "impact_summary", "timeline", "investigations", "verified_root_causes", "external_incidents", "observability_gaps", "issue_dispositions", "blocked_evidence"}
SECTIONS = ("Response & Scope", "Query Coverage", "Ranked Error Queue", "Impact Summary", "Incident Timeline", "Investigated Groups", "Verified Root Causes", "External or Non-Code Incidents", "Observability Gaps", "Remediation", "Uncovered and Blocked Evidence")
LATEST_INSTANT = datetime.max.replace(tzinfo=timezone.utc)

class InputError(ValueError): pass

def text(value, field):
    if not isinstance(value, str) or not value.strip() or any(c in value for c in "\r\n\0"):
        raise InputError(f"{field} must be a non-empty single line string")
    return value.strip()

def strings(value, field):
    if not isinstance(value, list): raise InputError(f"{field} must be a list")
    return [text(item, f"{field}[]") for item in value]

def exact_object(value, required, optional, field):
    if not isinstance(value, dict): raise InputError(f"{field} must be an object")
    missing, unknown = sorted(required-set(value)), sorted(set(value)-required-optional)
    if missing: raise InputError(f"{field} missing field: {missing[0]}")
    if unknown: raise InputError(f"{field} unknown field: {unknown[0]}")

def timestamp(value, field):
    value = text(value, field)
    try: parsed = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error: raise InputError(f"{field} must be an ISO-8601 timestamp") from error
    return parsed if parsed.tzinfo else parsed.replace(tzinfo=timezone.utc)

def newest_first(value, field):
    return LATEST_INSTANT - timestamp(value, field).astimezone(timezone.utc)

def validate(data):
    exact_object(data, TOP_FIELDS, set(), "input")
    if data["schema_version"] != 1 or isinstance(data["schema_version"], bool): raise InputError("schema_version must be 1")
    bound = data["investigation_bound"]
    if isinstance(bound, bool) or not isinstance(bound, int) or bound < 1 or bound > 5: raise InputError("investigation_bound must be an integer from 1 to 5")
    for field in ("signal", "scope", "environment"): text(data[field], field)
    timestamp(data["generated_at"], "generated_at")
    exact_object(data["window"], {"start", "end"}, set(), "window")
    start, end = timestamp(data["window"]["start"], "window.start"), timestamp(data["window"]["end"], "window.end")
    if start >= end: raise InputError("window.start must precede window.end")
    if data["outcome"] not in {"complete", "partial", "blocked"}: raise InputError("outcome must be complete, partial, or blocked")
    if not isinstance(data["coverage"], list) or not data["coverage"]: raise InputError("coverage must be non-empty")
    keys, states = set(), []
    for n, item in enumerate(data["coverage"]):
        exact_object(item, {"provider", "role", "state"}, {"receipt", "records_returned", "reason"}, f"coverage[{n}]")
        provider, role, state = text(item["provider"], "coverage.provider"), text(item["role"], "coverage.role"), item["state"]
        if (provider, role) in keys: raise InputError("coverage provider-role entries must be unique")
        keys.add((provider, role)); states.append(state)
        if state == "executed":
            if set(item) != {"provider", "role", "state", "receipt", "records_returned"}: raise InputError("executed coverage requires only receipt and records_returned")
            text(item["receipt"], "coverage.receipt")
            if not isinstance(item["records_returned"], int) or isinstance(item["records_returned"], bool) or item["records_returned"] < 0: raise InputError("records_returned must be a non-negative integer")
        elif state == "blocked":
            if set(item) != {"provider", "role", "state", "reason"}: raise InputError("blocked coverage requires only reason")
            text(item["reason"], "coverage.reason")
        else: raise InputError("coverage state must be executed or blocked")
    executed, blocked = states.count("executed"), states.count("blocked")
    outcome = data["outcome"]
    if outcome == "complete" and blocked: raise InputError("complete outcome requires all coverage executed")
    if outcome == "partial" and not (executed and blocked): raise InputError("partial outcome requires executed and blocked coverage")
    if outcome == "blocked" and not (blocked and not executed): raise InputError("blocked outcome requires all coverage blocked")
    if not isinstance(data["ranked_groups"], list): raise InputError("ranked_groups must be a list")
    group_ids = set(); investigated = 0
    for n, group in enumerate(data["ranked_groups"]):
        required={"id","summary","impact","frequency","recency","investigation"}; exact_object(group, required, set(), f"ranked_groups[{n}]")
        gid=text(group["id"],"group.id"); text(group["summary"],"group.summary"); timestamp(group["recency"],"group.recency")
        if gid in group_ids: raise InputError("ranked group ids must be unique")
        group_ids.add(gid)
        for field in ("impact","frequency"):
            if not isinstance(group[field],int) or isinstance(group[field],bool) or group[field] < 0: raise InputError(f"group.{field} must be non-negative integer")
        status = group["investigation"]
        if status not in {"verified","rejected","blocked","deferred"}: raise InputError("group investigation is invalid")
        investigated += status != "deferred"
    if investigated > bound: raise InputError(f"at most {bound} group(s) may be investigated")
    if not isinstance(data["investigations"], list): raise InputError("investigations must be a list")
    investigation_ids = set()
    for n,item in enumerate(data["investigations"]):
        exact_object(item,{"id","status","hypothesis","evidence"},set(),f"investigations[{n}]"); iid=text(item["id"],"investigation.id"); text(item["hypothesis"],"investigation.hypothesis"); strings(item["evidence"],"investigation.evidence")
        if item["status"] not in {"verified","rejected","blocked"}: raise InputError("investigation status is invalid")
        if iid in investigation_ids: raise InputError("investigation ids must be unique")
        investigation_ids.add(iid)
    if len(investigation_ids) > bound: raise InputError(f"at most {bound} investigation entries are allowed")
    verified_cause_ids=set()
    for field in ("verified_root_causes","external_incidents"):
        if not isinstance(data[field],list): raise InputError(f"{field} must be a list")
        seen=set()
        for n,item in enumerate(data[field]):
            exact_object(item,{"id","summary","evidence"},set(),f"{field}[{n}]"); iid=text(item["id"],f"{field}.id"); text(item["summary"],f"{field}.summary"); strings(item["evidence"],f"{field}.evidence")
            if iid in seen: raise InputError(f"{field} ids must be unique")
            seen.add(iid)
            if field == "verified_root_causes": verified_cause_ids.add(iid)
    if not isinstance(data["issue_dispositions"],list): raise InputError("issue_dispositions must be a list")
    disposition_ids=set()
    for n,item in enumerate(data["issue_dispositions"]):
        base={"cause_id","kind"}
        if not isinstance(item,dict): raise InputError(f"issue_dispositions[{n}] must be an object")
        cause_id=text(item.get("cause_id"),"issue_disposition.cause_id")
        if cause_id in disposition_ids: raise InputError("issue disposition cause ids must be unique")
        disposition_ids.add(cause_id)
        kind=item.get("kind")
        if kind == "proposed-managed-issue-contract":
            required=base|{"canonical_repository","problem","scope","evidence","acceptance_criteria"}
            exact_object(item,required,set(),f"issue_dispositions[{n}]")
            for field in ("canonical_repository","problem","scope"): text(item[field],f"issue_disposition.{field}")
            if not strings(item["evidence"],"issue_disposition.evidence"): raise InputError("proposed disposition evidence must be non-empty")
            if not strings(item["acceptance_criteria"],"issue_disposition.acceptance_criteria"): raise InputError("proposed disposition acceptance_criteria must be non-empty")
        elif kind == "verified-existing-issue-evidence":
            required=base|{"issue_client_id","issue_native_id","issue_url","role","project_client_id","project_native_id","projectless","owner_kind","owner_principal_id","assignment_receipt","assignment_verified_absent","read_receipt","read_at"}
            exact_object(item,required,set(),f"issue_dispositions[{n}]")
            for field in ("issue_client_id","issue_native_id","issue_url","owner_principal_id","read_receipt"): text(item[field],f"issue_disposition.{field}")
            timestamp(item["read_at"],"issue_disposition.read_at")
            if item["role"] not in {"work-item","increment"}: raise InputError("verified disposition role is invalid")
            if item["owner_kind"] not in {"human","app"}: raise InputError("verified disposition owner_kind is invalid")
            if not isinstance(item["projectless"],bool) or not isinstance(item["assignment_verified_absent"],bool): raise InputError("verified disposition boolean fields are invalid")
            assignment=item["assignment_receipt"]
            if item["assignment_verified_absent"]:
                if assignment is not None: raise InputError("verified-absent assignment cannot include a receipt")
            else:
                text(assignment,"issue_disposition.assignment_receipt")
            if item["role"] == "work-item":
                if not item["projectless"] or item["project_client_id"] is not None or item["project_native_id"] is not None: raise InputError("work-item disposition must be explicitly projectless")
            else:
                if item["projectless"]: raise InputError("increment disposition cannot be projectless")
                text(item["project_client_id"],"issue_disposition.project_client_id"); text(item["project_native_id"],"issue_disposition.project_native_id")
        else:
            raise InputError("issue disposition kind is invalid")
    if disposition_ids != verified_cause_ids: raise InputError("issue_dispositions must contain exactly one entry per verified repository cause")
    for field in ("impact_summary","timeline","observability_gaps","blocked_evidence"): strings(data[field],field)
    return data

def slug(value):
    value=unicodedata.normalize("NFKD",value).encode("ascii","ignore").decode().lower()
    return re.sub(r"[^a-z0-9]+","-",value).strip("-")

def bullets(items, empty="None."): return [f"- {item}" for item in items] or [empty]
def findings(items):
    result=[]
    for item in sorted(items,key=lambda x:x["id"]): result += [f'### {item["id"]} — {item["summary"]}',"",*bullets(item["evidence"]),""]
    return result or ["None."]

def render_dispositions(items):
    result=["Authority: non-authoritative diagnostic evidence",""]
    for item in sorted(items,key=lambda value:value["cause_id"]):
        result += [f'### {item["cause_id"]} — {item["kind"]}',""]
        if item["kind"] == "proposed-managed-issue-contract":
            result += [
                f'- Canonical repository: {item["canonical_repository"]}',
                f'- Proved problem: {item["problem"]}',
                f'- Bounded scope: {item["scope"]}',
                *[f"- Evidence: {entry}" for entry in item["evidence"]],
                *[f"- Observable acceptance criterion: {entry}" for entry in item["acceptance_criteria"]],
                "",
            ]
        else:
            project = "explicitly projectless" if item["projectless"] else f'{item["project_client_id"]} / {item["project_native_id"]}'
            assignment = "independently verified absent" if item["assignment_verified_absent"] else item["assignment_receipt"]
            result += [
                f'- Issue: {item["issue_client_id"]} / {item["issue_native_id"]} / {item["issue_url"]}',
                f'- Role/project: {item["role"]} / {project}',
                f'- Owner: {item["owner_kind"]} / {item["owner_principal_id"]}',
                f"- Assignment: {assignment}",
                f'- Independent read: {item["read_receipt"]} at {item["read_at"]}',
                "",
            ]
    return result or ["Authority: non-authoritative diagnostic evidence","", "No verified repository cause requires an issue disposition."]

def render(data,date):
    providers=sorted({item["provider"] for item in data["coverage"]}); provider=providers[0] if len(providers)==1 else "multiple"
    lines=["Non-authoritative diagnostic evidence — report only.","","---","type: response",f'outcome: {data["outcome"]}',f"provider: {provider}",f'environment: {data["environment"]}',f'window_start: {data["window"]["start"]}',f'window_end: {data["window"]["end"]}',f"date: {date}","---","",f'# Production Error Response — {data["signal"]}',""]
    coverage=sorted(data["coverage"],key=lambda x:(x["provider"],x["role"]))
    groups=sorted(data["ranked_groups"],key=lambda x:(-x["impact"],-x["frequency"],newest_first(x["recency"],"group.recency"),x["id"]))
    sections={
      "Response & Scope":[f'- Signal: {data["signal"]}',f'- Scope: {data["scope"]}',f'- Environment: {data["environment"]}',f'- UTC window: {data["window"]["start"]} through {data["window"]["end"]}',f'- Outcome: {data["outcome"]}',f'- Deep-investigation bound: {data["investigation_bound"]}'],
      "Query Coverage":[f'- {x["provider"]} / {x["role"]}: {x["state"]} — '+(f'{x["records_returned"]} records; receipt `{x["receipt"]}`' if x["state"]=="executed" else x["reason"]) for x in coverage],
      "Ranked Error Queue":[f'{n}. {x["id"]} — {x["summary"]} (impact {x["impact"]}, frequency {x["frequency"]}; {"Deferred" if x["investigation"]=="deferred" else x["investigation"]})' for n,x in enumerate(groups,1)] or ["No error groups matched the executed queries."],
      "Impact Summary":bullets(data["impact_summary"]), "Incident Timeline":bullets(data["timeline"]),
      "Investigated Groups":[f'- {x["id"]}: {x["status"]} — {x["hypothesis"]}; evidence: {"; ".join(x["evidence"]) or "None"}' for x in sorted(data["investigations"],key=lambda x:x["id"])] or ["None."],
      "Verified Root Causes":findings(data["verified_root_causes"]), "External or Non-Code Incidents":findings(data["external_incidents"]),
      "Observability Gaps":bullets(data["observability_gaps"]), "Remediation":render_dispositions(data["issue_dispositions"]), "Uncovered and Blocked Evidence":bullets(data["blocked_evidence"]),
    }
    for section in SECTIONS: lines += [f"## {section}","",*sections[section],""]
    return "\n".join(lines)

def persist(markdown, directory, stem, sanitizer):
    directory.mkdir(parents=True,exist_ok=True); fd,name=tempfile.mkstemp(prefix=".respond-",suffix=".md",dir=directory); temporary=Path(name)
    try:
        with os.fdopen(fd,"w",encoding="utf-8",newline="\n") as handle: handle.write(markdown); handle.flush(); os.fsync(handle.fileno())
        subprocess.run([sys.executable,str(sanitizer),"--check",str(temporary)],check=True)
        number=1
        while True:
            destination=directory/(f"{stem}.md" if number==1 else f"{stem}-{number}.md")
            try: os.link(temporary,destination); break
            except FileExistsError: number+=1
        temporary.unlink(); return destination
    except BaseException: temporary.unlink(missing_ok=True); raise

def main():
    parser=argparse.ArgumentParser(); parser.add_argument("--input",required=True,type=Path); parser.add_argument("--output-dir",required=True,type=Path); parser.add_argument("--date",required=True); args=parser.parse_args()
    try:
        datetime.strptime(args.date,"%Y-%m-%d")
        data=validate(json.loads(args.input.read_text(encoding="utf-8"))); report_slug="-".join(filter(None,(slug(data["signal"]),slug(data["scope"]))))
        if not report_slug: raise InputError("signal and scope must produce an ASCII slug")
        destination=persist(render(data,args.date),args.output_dir,f"{args.date}-{report_slug}",Path(__file__).with_name("sanitize-telemetry.py")); print(destination); return 0
    except (ValueError,OSError,json.JSONDecodeError,subprocess.CalledProcessError) as error: print(f"render-report: {error}",file=sys.stderr); return 1
if __name__=="__main__": raise SystemExit(main())
