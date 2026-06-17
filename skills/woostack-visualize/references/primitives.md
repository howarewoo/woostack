# Visual primitives palette

These are optional building blocks to combine in bespoke HTML renders — not a fixed template.
Pick only the primitives that the source evidence supports. Omit any primitive (or mark its
fields unknown) when the source does not supply the needed evidence.

---

## source summary

**When:** always — opens every render with a one-paragraph framing of what was visualized,
who it is for, and what the key takeaway is.

**Source evidence:** the request, the audience, and whatever documents or code were supplied.

**Omit/unknown:** omit fields that cannot be inferred; do not fabricate scope, ownership, or
status not present in the source.

---

## file map

**When:** the change or feature spans multiple files and the reader needs spatial orientation
before diving into detail.

**Source evidence:** a file tree, diff stat, or explicit enumeration of affected paths.

**Omit/unknown:** omit directories or files not mentioned in the source; do not guess at
sibling files or infer a broader project layout.

---

## annotated code

**When:** a specific code path, function, or snippet is central to understanding the change
and the audience is technical.

**Source evidence:** verbatim code supplied in the request or attached diff.

**Omit/unknown:** omit code blocks when only a prose description is available; never
reconstruct code from description alone.

---

## before/after

**When:** a change replaces or modifies existing behavior and the contrast is the clearest
way to communicate the delta.

**Source evidence:** a diff, explicit old/new values, or a before state plus a described
change.

**Omit/unknown:** omit the "before" column when the prior state is unknown; do not infer old
behavior from new code alone.

---

## API/data contract

**When:** the visualization covers an interface boundary — REST endpoint, function signature,
schema, or event shape — and the reader needs to know what flows across it.

**Source evidence:** explicit schema, OpenAPI spec, type definitions, or interface
declarations in the supplied source.

**Omit/unknown:** mark fields as unknown when types or shapes are absent from the source; do
not invent field names, types, or constraints.

---

## state matrix

**When:** the subject has discrete states and transitions that are otherwise hard to reason
about in prose.

**Source evidence:** explicit state names and transitions in code, docs, or the request.

**Omit/unknown:** omit transition rows when the trigger or target state is not evidenced;
never guess at implied states.

---

## flow diagram

**When:** a sequential or branching process (request lifecycle, user journey, data pipeline)
is the primary subject and a linear description would lose the branching structure.

**Source evidence:** step-by-step logic, conditional branches, or a described user or data
path in the source.

**Omit/unknown:** omit branches or steps not described in the source; mark entry and exit
points unknown if not stated.

---

## decision table

**When:** multiple conditions combine to produce distinct outcomes and a truth-table layout
surfaces the logic more clearly than prose.

**Source evidence:** explicit conditions and their outcomes stated in code, config, or docs.

**Omit/unknown:** omit rows for condition combinations not evidenced; do not extrapolate
outcomes from partial rules.

---

## risk register

**When:** the visualization targets a decision-maker who needs to weigh known unknowns,
failure modes, or open tradeoffs before acting.

**Source evidence:** risks, caveats, or tradeoffs explicitly called out in the source or
derivable from stated constraints.

**Omit/unknown:** mark likelihood and impact unknown when not evidenced; do not fabricate
risk severity or assign owners not named in the source.

---

## open questions

**When:** the source leaves material gaps — unresolved decisions, missing specs, or
unknowns that affect what the reader would do next.

**Source evidence:** explicit "TBD", missing fields, or contradictions found in the source.

**Omit/unknown:** omit this primitive entirely when the source is complete; never invent
questions that are not implied by an actual gap in the evidence.
