---
name: visualize-quality-rubric
type: spec
status: approved
date: 2026-06-17
branch: feature/visualize-quality-rubric
---

# woostack-visualize Quality Rubric - Design Spec

> **Plan:** [[plans/2026-06-17-visualize-quality-rubric]]
> Visualize on demand: render this file with [spec-template.html](spec-template.html) for a rich view. Markdown is the source of truth; HTML is a presentation target only.
> `status:` is build-loop phase enum. The enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

## 1. Problem

`woostack-visualize` already defines the core contract: read real source, choose an audience, and write one self-contained offline HTML render that is never the source of truth. That boundary is correct and should not change.

The current skill is thin on judgment, though. It tells the agent to compose bespoke HTML, but it does not give much guidance on when a visualization is worth producing, what source-grounding bar to meet before composing, which visual section patterns are useful for different source shapes, or how to self-check high-stakes renders before handoff.

BuilderIO's `visual-plan` skill has useful planning discipline in those areas: gate visual work thoughtfully, research real files first, use richer blocks such as file maps and annotated code, surface open questions, and self-review risky plans. Its hosted Agent-Native Plans model, MCP tools, feedback APIs, auth flow, and publish/export workflow do not fit woostack's offline/disposable render model.

## 2. Goal

Improve `woostack-visualize` so agents produce more useful offline HTML renders without changing the command shape or ownership model.

The skill should:

- explain when to visualize and when to skip it;
- require source-grounded research before composing a render;
- offer concrete offline visual primitives agents can combine in bespoke HTML;
- surface hard-to-reverse decisions and open questions when present in the source;
- add a lightweight self-review checklist for high-stakes architecture, data, migration, or multi-file renders;
- keep every output self-contained, offline-viewable, disposable, and grounded in the source.

## 3. Non-goals

- No hosted Plan MCP, Agent-Native Plans dependency, auth/reconnect workflow, hosted comments, feedback API, publish flow, or export receipt.
- No new slash command and no change to `/woostack-visualize <source> [for <audience>]`.
- No application code, package manager lockfile, build step, runtime dependency, browser server, or CI workflow.
- No MDX plan artifact model. Markdown/code remains the source of truth; HTML remains the disposable render.
- No fixed template that every visualization must follow.
- No fabricated metrics, timelines, traction, benchmark numbers, code facts, or architecture claims.

## 4. Approach

Update `skills/woostack-visualize/SKILL.md` with a stronger procedure:

1. **Decide whether visualization adds value.** Recommend visualization when a reader needs to see relationships, compare options, review architecture or state, approve direction, or inspect a multi-file/code/data shape. Recommend skipping trivial one-line changes or cases where a plain answer is clearer.
2. **Research before composing.** Keep the existing "read actual source" rule, but make the bar explicit: name real files, directories, symbols, data shapes, source sections, and existing helpers when they are relevant. For directories, summarize selection criteria instead of pretending every file was read.
3. **Select visual primitives.** Link a new `references/primitives.md` file that lists reusable offline patterns: source summary, file map, annotated code, diff/before-after panel, API/data contract, state matrix, flow diagram, decision table, risk register, and open questions.
4. **Compose bespoke HTML.** Keep the current self-contained HTML rule. The primitives are a palette, not a template. Use only what the source and audience justify.
5. **Self-review high-stakes renders.** For architecture, backend, data-model, migration, security, multi-file, or public-contract renders, check that the output is source-grounded, offline, audience-framed, and clear about unknowns before reporting the path.

Add `skills/woostack-visualize/references/primitives.md` as a short reference. It should describe each primitive, when to use it, what source evidence it needs, and what not to invent.

Keep `skills/woostack-visualize/references/audiences.md` stable. Audience-specific primitive selection belongs in `SKILL.md`: resolve the audience first, then choose from `primitives.md` based on that audience. This avoids duplicating the primitive palette across two reference files.

Keep the high-stakes self-review checklist inline in `SKILL.md`, not in `primitives.md`. The checklist is part of the command procedure and should be hard to miss. `primitives.md` stays a palette of section patterns, not a second workflow.

No authored docs page is expected to change because this does not alter the command surface or skill count. Still verify the command routing mentions remain accurate.

## 5. Components & data flow

Updated skill behavior:

1. User runs `/woostack-visualize <source> [for <audience>]`.
2. Agent resolves and reads the source as today.
3. Agent decides whether a visualization is useful for the request. If not, it should say so and avoid padded output.
4. Agent resolves the audience using `references/audiences.md`.
5. Agent chooses a small set of primitives from `references/primitives.md` based on the source shape and audience.
6. Agent writes one self-contained HTML file to `.woostack/visuals/YYYY-MM-DD-<slug>-<audience>.html` or the user path.
7. Agent reports the path and does not open a browser without consent.

Files:

- Modify `skills/woostack-visualize/SKILL.md`.
- Add `skills/woostack-visualize/references/primitives.md`.
No `audiences.md` change is expected.

## 6. Error handling

- **Source cannot be read.** Stop and report the missing or unreadable source. Do not compose from memory.
- **Directory is too large.** Read a representative set, state the selection basis in the render, and mark uninspected areas as unknown rather than implying total coverage.
- **Visualization would be filler.** Say the source is better handled as a concise answer or code review; do not create a padded single-step visual.
- **Primitive lacks evidence.** Omit it or mark the field unknown. Do not infer missing metrics, call graphs, API contracts, or timelines.
- **High-stakes render self-review fails.** Fix the render before handoff, or report the specific gap if it cannot be fixed from available source.

## 7. Acceptance criteria

**AC1 - The skill explains when to visualize**

- happy: `SKILL.md` includes guidance to use visualization for comparison, approval, relationship mapping, architecture/state review, and multi-file/code/data inspection.
- error: `SKILL.md` tells agents to skip trivial or clearer-as-text cases instead of padding a visual.
- edge: free-form subjects remain supported when there is enough source/context to ground the render.

**AC2 - The skill requires source-grounded composition**

- happy: `SKILL.md` explicitly requires real source research before composing and names concrete evidence types such as files, symbols, data shapes, source sections, and existing helpers.
- error: unreadable sources remain a stop condition.
- edge: large directories require stated selection criteria and unknowns rather than pretending complete coverage.

**AC3 - Offline primitives are documented**

- happy: `references/primitives.md` documents a reusable palette including file maps, annotated code, diffs/before-after panels, API/data contracts, state matrices, flows, decisions, risks, and open questions.
- error: the reference says primitives are optional and must be omitted when unsupported by source.
- edge: the reference preserves bespoke composition and does not become a mandatory template.

**AC4 - High-stakes renders get self-review**

- happy: `SKILL.md` defines high-stakes render categories and a pre-handoff self-review checklist.
- error: failed self-review leads to fixing the render or reporting the gap.
- edge: small or low-risk renders are not burdened with a heavy review process.
- edge: the self-review checklist is inline in `SKILL.md`, while `primitives.md` remains a palette rather than a workflow.

**AC5 - Offline/disposable contract is preserved**

- happy: `SKILL.md` still says HTML is disposable, source remains source of truth, outputs are self-contained and offline, and browser opening requires consent.
- error: no hosted Plan MCP, auth, feedback API, publish/export flow, dependency, build step, app code, lockfile, or CI workflow is introduced.
- edge: BuilderIO is credited only as source inspiration; its external workflow is not imported.

## 8. Testing

Automated verification is text-structure oriented because this repo is a skill collection, not an app:

- `test -f skills/woostack-visualize/SKILL.md`
- `test -f skills/woostack-visualize/references/primitives.md`
- `rg -n "When to visualize|Research before|primitives|self-review|offline|disposable" skills/woostack-visualize`
- `rg -n "Agent-Native|MCP|auth|publish|feedback API|lockfile|build step|CI workflow" skills/woostack-visualize`
- `git diff --exit-code -- skills/woostack-visualize/references/audiences.md`

Manual checks:

- Read `SKILL.md` and confirm the procedure is still concise enough for a skill description.
- Read `primitives.md` and confirm it is a palette, not a fixed template.
- Confirm command routing in `AGENTS.md` and `skills/using-woostack/SKILL.md` remains accurate without a command-surface edit.

## 9. Open questions

None.
