# Visual primitives palette

Choose the smallest set that answers the reader's question. These are examples, not required
sections or an exhaustive catalog. Every node, edge, label, and value needs source support or an
explicit inference label. Omit unsupported detail or mark a material gap; do not complete a shape
by inventing data. The source-specific limits below still apply.

## source summary

Open with what was read, who the explanation serves, and the main takeaway. Identify proposed
versus observed behavior. Keep this framing brief rather than adding a separate dashboard of cards.

## file map

Orient the reader across paths evidenced by a tree, diff, or explicit file list. Group by
responsibility where supported; do not infer sibling files or a broader repository layout.

## annotated code

Show a short, verbatim excerpt when the mechanism matters. Put explanation beside the relevant
lines and identify omissions. Never reconstruct code from prose or insert annotations as source.

## before/after

Use aligned views to explain a change evidenced by a diff or explicit old/new descriptions.
Keep comparable labels and scales consistent. Omit the before view when the old state is unknown;
label proposed changes rather than presenting them as shipped behavior.

## API/data contract

Show what crosses an interface using supplied schemas, signatures, types, or event definitions.
Preserve field names, constraints, and requiredness. Mark missing facts unknown, not optional.

## state matrix

Use a table or state diagram for evidenced states, triggers, and transitions. Label transition
conditions; omit unsupported transitions rather than guessing what fills an empty cell.

## flow diagram

Show an evidenced user journey, request path, architecture relationship, or data pipeline.
Label what each arrow means and distinguish containment, dependency, and sequence. Include relevant
branches and failure paths that the source supports; mark unknown entry/exit points explicitly.
Split an unreadable graph into an overview and focused detail instead of shrinking the labels.

## decision table

Compare evidenced conditions and outcomes. Do not extrapolate missing combinations from partial
rules or imply that an omitted case succeeds.

## risk register

Show stated risks or clearly labeled inferences from stated constraints. Leave unsupported
likelihood, impact, severity, and ownership unknown; do not assign scores to make a chart.

## open questions

Surface unresolved decisions, contradictions, or missing facts that affect the reader's question.
Omit this section when there is no material gap; it is not a prompt to invent more planning work.

## Visual composition

Use a clear reading order, consistent spacing and typography, and grouping that explains structure.
Reserve accent color for meaning, paired with text or shape. Prefer a readable table to an elaborate
diagram that adds no understanding. Use units, baselines, and consistent scales for supplied data.
Progressively disclose secondary detail without hiding key conclusions or uncertainty. Every view
must remain understandable with no interaction; controls should help exploration, not gate reading.
