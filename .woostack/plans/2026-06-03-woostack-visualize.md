---
type: plan
source: .woostack/specs/2026-06-03-woostack-visualize.md
status: done
branch: feature/woostack-visualize
---

**Source:** .woostack/specs/2026-06-03-woostack-visualize.md


# woostack-visualize Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a `woostack-visualize` skill that reads any source and writes a self-contained, audience-tailored HTML visualization, and wire the existing docs to it.

**Architecture:** A new self-contained skill bundle (`skills/woostack-visualize/`) holding `SKILL.md` (command + four-step procedure + hard constraints) and `references/audiences.md` (three audience presets + free-form rubric). Five existing docs are edited to register and delegate to it. No code, no app build, no CI for this repo — the deliverable is Markdown + agent behavior. Source: [.woostack/specs/2026-06-03-woostack-visualize.md](../specs/2026-06-03-woostack-visualize.md).

**Tech Stack:** Markdown skill files; generated output is self-contained HTML (inline CSS/SVG, offline-viewable). No new dependencies.

**Out of scope (explicit):** Do NOT migrate or touch the two orphan HTML specs in `.woostack/specs/`. Do NOT move or rename any existing `SKILL.md`. Do NOT add app code, lockfiles, or CI workflows.

---

## File Structure

- **Create** `skills/woostack-visualize/SKILL.md` — discovery frontmatter, `/woostack-visualize` command, four-step procedure, hard constraints.
- **Create** `skills/woostack-visualize/references/audiences.md` — `engineer` / `non-technical` / `investor` profiles + the shared dimension rubric for free-form audiences.
- **Modify** `.gitignore` — gitignore `.woostack/visuals/` (disposable renders).
- **Modify** `skills/woostack-build/SKILL.md` — step 2 "visualize on demand" delegates to woostack-visualize.
- **Modify** `skills/using-woostack/SKILL.md` — add `/woostack-visualize` routing row.
- **Modify** `AGENTS.md` — "seven" → "eight" shipped skills; add list entry + file-map entry.
- **Modify** `README.md` — add to install collection list + a "How it works" subsection.

---

## Task 1: Skill bundle (SKILL.md + audiences.md + gitignore)

**Files:**
- Create: `skills/woostack-visualize/SKILL.md`
- Create: `skills/woostack-visualize/references/audiences.md`
- Modify: `.gitignore`

- [x] **Step 1: Write `skills/woostack-visualize/SKILL.md`**

```markdown
---
name: woostack-visualize
description: Use when you want an HTML visualization of any source — a spec, plan, file, directory, or concept — tailored to a target audience (engineer, non-technical, investor, or any free-form reader). Reads the real source and writes one self-contained, offline-viewable HTML file; never the source of truth.
---

# woostack-visualize

Turn any source into one self-contained HTML visualization, tailored to who will read it.
The Markdown/code source stays the source of truth; the HTML is a disposable render.

## Command

- `/woostack-visualize <source> [for <audience>]`
  - `<source>` — a spec/plan path, a file, a glob, a directory, or a free-form subject.
  - `<audience>` — a preset (`engineer` | `non-technical` | `investor`) or any free-form
    string ("a security auditor", "a designer"). Defaults to `engineer`.
  - Examples:
    - `/woostack-visualize .woostack/specs/2026-06-03-auth.md for an investor`
    - `/woostack-visualize packages/api for a non-technical PM`
    - `/woostack-visualize the review swarm architecture`

## Procedure

1. **Resolve input.** Read the actual source. For a file/glob, read the files. For a
   directory, read enough structure (entry points, key modules, READMEs) to characterize it
   honestly; state in the visual what you sampled versus read in full. For a free-form
   subject with no path, build only from what the repo and conversation actually contain.
   Never invent content. If the source cannot be read, stop and say so — do not render guesses.
2. **Resolve audience.** A preset loads its profile from
   [references/audiences.md](references/audiences.md). A free-form audience is interpreted
   against the same dimension rubric in that file. Default `engineer`.
3. **Compose bespoke HTML.** Design the layout, section set, and diagrams to fit *this*
   content and *this* audience, guided by the audience profile — not a fixed template. Emit a
   single self-contained `.html` file: inline `<style>` always; diagrams as inline SVG or
   pure CSS; JavaScript only when it adds real value and can be inlined. The file MUST render
   its core content offline, with no network fetch (no CDN-loaded library). For the
   engineer-audience spec case, [woostack-build's spec-template.html](../woostack-build/references/spec-template.html)
   is an available starting point.
4. **Write and report.** Write to `.woostack/visuals/YYYY-MM-DD-<slug>-<audience>.html`
   (derive `<slug>` from the source name/subject; kebab-case a free-form audience to a short
   form). Honor an explicit user-supplied path instead. Print the path and offer to open it
   — do not open a browser unprompted. If `.woostack/` does not exist, write next to the
   source or to a user-supplied path and note that `visuals/` is the default once initialized;
   do not require `/woostack-init`.

## Hard constraints

- **Source of truth is the source.** Generated HTML is a disposable render. Re-render anytime.
- **Never write into `.woostack/specs/`.** That holds Markdown source only. Renders go to
  `.woostack/visuals/` (gitignored) or a user path.
- **Self-contained and offline.** No CDN, no external fetch to render core content. Inline
  everything. Prefer inline SVG over a network-loaded diagram runtime.
- **No fabrication.** Visualize only what the source contains. When a metric, timeline, or
  benchmark is absent, omit it or mark it unknown — never invent one. This binds hardest for
  the investor audience.
- **Audience is open.** The three presets are shortcuts, not an allow-list; any free-form
  audience is valid, interpreted against the rubric.
- **No browser without consent.** Report the path; open only if the user agrees.
```

- [x] **Step 2: Write `skills/woostack-visualize/references/audiences.md`**

```markdown
# Audience profiles

Each visualization targets one reader. A preset below is a shortcut; any free-form audience
("a designer", "a security auditor") is valid and is interpreted against the **dimension
rubric** at the end. Default audience is `engineer`.

## Dimensions

Every profile answers these five questions. Free-form audiences answer them by inference.

- **Surface** — what to show and what to hide.
- **Depth** — how far down to go (mechanism vs. outcome).
- **Vocabulary** — technical, plain, or business language.
- **Visual density** — dense reference vs. spacious headline-driven.
- **Cares about** — what this reader is actually trying to learn.

## engineer

- **Surface:** data flow, interfaces, components, key decisions, tradeoffs, edge cases,
  failure modes. Hide marketing framing.
- **Depth:** full technical depth, down to mechanism and contracts.
- **Vocabulary:** precise technical terms; name the real types, files, and functions.
- **Visual density:** dense — diagrams, tables, code/identifier callouts welcome.
- **Cares about:** how it works, how to build it, how to maintain and extend it safely.

## non-technical

- **Surface:** what it does and why it matters; the user-facing shape. Hide implementation.
- **Depth:** shallow on mechanism; concrete on outcomes and examples.
- **Vocabulary:** plain language and analogies; expand or avoid jargon.
- **Visual density:** moderate, with generous whitespace and clear signposting.
- **Cares about:** what changes for people, the benefit, the "so what".

## investor

- **Surface:** the problem, the opportunity, scope, milestones, and risk. No code.
- **Depth:** outcome-level; tie everything to value and feasibility.
- **Vocabulary:** business language; crisp and confident, never hand-wavy.
- **Visual density:** low — high-signal, headline-driven, a few strong visuals.
- **Cares about:** what this is worth, what it costs, what could go wrong.
- **Guard:** never fabricate numbers, timelines, or traction. Absent data is omitted or
  labelled unknown — not invented.

## Free-form audiences

When the audience is not a preset, infer the five dimensions from who they are. A "security
auditor" wants threat surface, trust boundaries, and failure modes at high depth in technical
vocabulary; a "designer" wants flows, states, and UI surface at moderate depth. State the
inferred framing briefly at the top of the visual so the reader knows the lens.
```

- [x] **Step 3: Add the visuals gitignore line**

Modify `.gitignore`. Under the existing `# woostack:` block (after the `.woostack/metrics.json` line, near the `.woostack/memory/` line), add:

```
# woostack: disposable HTML renders (regenerated from source)
.woostack/visuals/
```

- [x] **Step 4: Verify structure**

Run:
```bash
test -f skills/woostack-visualize/SKILL.md && test -f skills/woostack-visualize/references/audiences.md && echo "files OK"
head -4 skills/woostack-visualize/SKILL.md          # frontmatter: name + description present
grep -n "woostack/visuals" .gitignore               # gitignore line present
git ls-files skills/ | grep -c SKILL.md              # still 7 tracked SKILL.md (new one untracked yet)
```
Expected: `files OK`; frontmatter shows `name: woostack-visualize`; gitignore line printed; existing SKILL.md count unchanged (no renames).

- [x] **Step 5: Commit**

```bash
git add skills/woostack-visualize/SKILL.md skills/woostack-visualize/references/audiences.md .gitignore
git commit -m "feat: add woostack-visualize skill bundle"
```

---

## Task 2: Wire existing docs to the new skill

**Files:**
- Modify: `skills/woostack-build/SKILL.md` (step 2 delegation)
- Modify: `skills/using-woostack/SKILL.md` (routing row)
- Modify: `AGENTS.md` (count + list + file map)
- Modify: `README.md` (install list + How it works)

- [x] **Step 1: Delegate woostack-build's render-on-demand to the new skill**

In `skills/woostack-build/SKILL.md`, in Procedure step 2 ("Write the spec as markdown"), the
"Visualize on demand" sentence currently points directly at `references/spec-template.html`.
Replace it so it delegates to woostack-visualize while keeping the template as the engineer
starting point:

Old (the trailing sentence of step 2):
> **Visualize on demand** — if a rich view is wanted, render the markdown through [references/spec-template.html](references/spec-template.html); the HTML is a presentation target only, never the authored source.

New:
> **Visualize on demand** — if a rich view is wanted, hand the markdown to [`woostack-visualize`](../woostack-visualize/SKILL.md) (audience `engineer` for specs; it uses [references/spec-template.html](references/spec-template.html) as a starting point). The HTML is a presentation target only, never the authored source.

- [x] **Step 2: Add the routing row in using-woostack**

In `skills/using-woostack/SKILL.md`, in the Command Routing table, add a row (keep table
alignment with the existing rows):

```
| `/woostack-visualize <source> [for <audience>]`, render a source as audience-tailored HTML | `woostack-visualize` |
```

- [x] **Step 3: Update AGENTS.md count, list, and file map**

In `AGENTS.md`:
- Change "The seven shipped skills are:" → "The eight shipped skills are:".
- Add to that bulleted list, after the `woostack-review` entry:
  ```
  - [`woostack-visualize`](skills/woostack-visualize/SKILL.md)
  ```
- In "Quick file map", add an entry after the Review engine line:
  ```
  - Visualization engine (audience-tailored HTML renders):
    [`skills/woostack-visualize/`](skills/woostack-visualize/SKILL.md)
  ```

- [x] **Step 4: Update README.md**

In `README.md`:
- In the Install section, the parenthetical skills list currently reads
  `(skills: using-woostack, woostack-init, woostack-bootstrap, woostack-build, woostack-commit, woostack-review, woostack-address-comments)`.
  Add `, woostack-visualize` to the end of that list.
- In "How it works", add a subsection after the `/woostack-address-comments` one and before "Growing scope":
  ```markdown
  ### `/woostack-visualize <source> [for <audience>]`: audience-tailored HTML render

  Reads any source — a markdown spec or plan, a file, a directory, or a described concept — and
  writes one self-contained HTML visualization tailored to who will read it: an engineer, a
  non-technical stakeholder, an investor, or any free-form audience you name. The markdown/code
  source stays the source of truth; the HTML is a disposable render under `.woostack/visuals/`
  (gitignored, regenerated on demand). It never fabricates data and renders offline with no
  external dependencies. `woostack-build` delegates its spec render to this skill. → [SKILL.md](skills/woostack-visualize/SKILL.md)
  ```

- [x] **Step 5: Verify cross-links and count**

Run:
```bash
grep -n "eight shipped skills" AGENTS.md
grep -n "woostack-visualize" AGENTS.md README.md skills/using-woostack/SKILL.md skills/woostack-build/SKILL.md
grep -c "woostack-visualize" README.md          # >=2 (install list + how-it-works)
```
Expected: AGENTS.md says "eight"; each file references `woostack-visualize`; README hit count ≥ 2. Manually confirm no broken relative paths (each links to an existing file).

- [x] **Step 6: Commit**

```bash
git add skills/woostack-build/SKILL.md skills/using-woostack/SKILL.md AGENTS.md README.md
git commit -m "docs: register woostack-visualize and delegate spec render to it"
```

---

## Task 3: End-to-end render exercise (proves the skill works)

**Files:**
- Output (gitignored, not committed): `.woostack/visuals/*.html`

- [x] **Step 1: Render this spec for all three presets**

Following `skills/woostack-visualize/SKILL.md`, render
`.woostack/specs/2026-06-03-woostack-visualize.md` three times:
- `for engineer` → `.woostack/visuals/2026-06-03-woostack-visualize-engineer.html`
- `for non-technical` → `...-non-technical.html`
- `for investor` → `...-investor.html`

- [x] **Step 2: Verify self-contained + offline + differentiation**

Run:
```bash
ls .woostack/visuals/
# No external network refs in any render:
grep -rliE "https?://[^\"']*(cdn|unpkg|jsdelivr|googleapis|mermaid)" .woostack/visuals/ && echo "FAIL: external dep found" || echo "offline OK"
```
Then inspect each file:
- engineer view carries technical depth (data flow, file/identifier names, tradeoffs);
- non-technical view carries no jargon (plain language, no code);
- investor view carries no code and **no fabricated numbers/timelines** (the spec has none, so the render must not invent any);
- each opens standalone in a browser with no network.

Expected: `offline OK`; three differentiated files; investor file fabricates nothing.

- [x] **Step 3: Confirm renders are gitignored**

Run:
```bash
git status --porcelain .woostack/visuals/   # expect NO output (ignored)
git check-ignore .woostack/visuals/2026-06-03-woostack-visualize-engineer.html  # prints the path => ignored
```
Expected: status shows nothing under `visuals/`; `check-ignore` prints the path.

- [x] **Step 4: No commit**

Renders are disposable and gitignored — nothing to commit. Task 3 is verification only.

---

## Self-Review

**Spec coverage:**
- Spec §4 step 1 (resolve input) → Task 1 SKILL.md Procedure 1. ✓
- Spec §4 step 2 + audience presets/free-form → Task 1 SKILL.md Procedure 2 + audiences.md. ✓
- Spec §4 step 3 (bespoke, self-contained, offline) → Task 1 SKILL.md Procedure 3 + hard constraints; verified Task 3 Step 2. ✓
- Spec §4 step 4 + output location/slug/audience-in-name → Task 1 Procedure 4; verified Task 3. ✓
- Spec §5 new files → Task 1. ✓
- Spec §5 integration edits (build, using-woostack, AGENTS, README, gitignore) → Task 1 Step 3 (gitignore) + Task 2. ✓
- Spec §6 error handling (unreadable source, dir sampling, no-fabrication, no `.woostack/`) → SKILL.md Procedure 1/4 + hard constraints. ✓
- Spec §7 testing (frontmatter, cross-links, behavioral, no-fabrication, delegation) → Task 1 Step 4, Task 2 Step 5, Task 3. ✓
- Spec §3 non-goals (don't move SKILL.md, no app/CI, don't replace template) → respected; Task 1 Step 4 asserts no SKILL.md renames. ✓
- Orphan HTML specs → explicitly out of scope, untouched. ✓

**Placeholder scan:** No TBD/TODO; both new files have full content; doc edits give exact old→new anchor text. ✓

**Type consistency:** Filename scheme `YYYY-MM-DD-<slug>-<audience>.html` used consistently across SKILL.md, spec, and Task 3. Output dir `.woostack/visuals/` consistent everywhere. ✓
