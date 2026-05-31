# woo-stack Skill Collection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Repackage the woo-stack repo from a single bootstrap skill into a collection of four orchestration skills (`bootstrap`, `build`, `review`, `address-comments`), porting woo-review in as first-party.

**Architecture:** Markdown + skill assets only — no application code, no test runner. Each skill dir is self-contained (SKILL.md references its assets by relative path; scripts resolve siblings via `BASH_SOURCE`). `review` is the full ported woo-review engine with `review`/`address` verbs; `address-comments` is a thin SKILL that preflights `woo-stack-review` and invokes its `address` verb (engine shared by delegation, not file-sharing). `build` chains superpowers + grill-me, overriding their write step to author HTML specs to `.woo-stack/specs/` and markdown plans to `.woo-stack/plans/`.

**Tech Stack:** Bash scripts (ported woo-review), Markdown SKILL.md files, a self-contained HTML spec template. Verification is by static checks (`bash -n`, `jq`, link resolution, `grep`), not unit tests.

**Source spec:** [`.woo-stack/specs/2026-05-31-woo-stack-skill-collection-design.html`](../specs/2026-05-31-woo-stack-skill-collection-design.html)

**PR slicing (honors the ≤500 LOC ethos):** Tasks are grouped into five independently shippable PRs — A: rename bootstrap; B: port woo-review; C: add build; D: add address-comments; E: docs reframe. Commit at the end of each task; open a PR at each group boundary.

---

## File Structure

```
skills/
├── woo-stack-bootstrap/          # PR A — renamed from skills/woo-stack/
│   ├── SKILL.md                  #   frontmatter name → woo-stack-bootstrap
│   └── references/               #   unchanged content
│       ├── decisions.md  architecture.md  frameworks.md
│       ├── infrastructure.md  patterns.md  bootstrap.md  development.md
├── woo-stack-review/             # PR B — ported woo-review (full engine)
│   ├── SKILL.md                  #   verbs: review (default) + address
│   ├── scripts/  prompts/        #   .woo-review/ → .woo-stack/ rewritten
├── woo-stack-build/              # PR C — new
│   ├── SKILL.md                  #   chains brainstorming→grill-me→plans→execute
│   └── references/
│       └── spec-template.html    #   self-contained HTML spec skeleton
└── woo-stack-address-comments/   # PR D — new, thin
    └── SKILL.md                  #   delegates to woo-stack-review address verb

.claude/skills/                   # repoint symlinks to dogfood first-party skills
skills-lock.json                  # drop external woo-review entry
README.md  AGENTS.md              # PR E — reframe to the collection
.gitignore                        # .woo-stack/metrics.json
```

Each task below names exact paths. Run every command from the repo root (`/Users/adamwoo/Documents/GitHub/woo-stack`).

---

## PR A — Rename the bootstrap skill

### Task A1: Move the skill directory

**Files:**
- Move: `skills/woo-stack/` → `skills/woo-stack-bootstrap/`

- [ ] **Step 1: Move the directory with git**

```bash
git mv skills/woo-stack skills/woo-stack-bootstrap
```

- [ ] **Step 2: Verify the move**

Run: `ls skills/woo-stack-bootstrap/SKILL.md skills/woo-stack-bootstrap/references/`
Expected: `SKILL.md` plus the seven reference files listed; `skills/woo-stack` no longer exists.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "refactor(skill): rename woo-stack -> woo-stack-bootstrap"
```

### Task A2: Update the bootstrap SKILL.md frontmatter name

**Files:**
- Modify: `skills/woo-stack-bootstrap/SKILL.md:2`

- [ ] **Step 1: Change the frontmatter `name`**

Change line 2 from `name: woo-stack` to:

```yaml
name: woo-stack-bootstrap
```

Also update the H1 (`# woo-stack` → `# woo-stack-bootstrap`) and the Invocation block, replacing `/woo-stack <goal>` with `/woo-stack-bootstrap <goal>` and the two example lines (`/woo-stack create ...` → `/woo-stack-bootstrap create ...`).

- [ ] **Step 2: Verify no stale self-references remain**

Run: `grep -n "/woo-stack " skills/woo-stack-bootstrap/SKILL.md`
Expected: no matches (all invocations now read `/woo-stack-bootstrap`).

- [ ] **Step 3: Verify relative cross-links still resolve**

Run: `cd skills/woo-stack-bootstrap && for f in $(grep -o 'references/[a-z-]*\.md' SKILL.md | sort -u); do test -f "$f" && echo "OK $f" || echo "MISSING $f"; done; cd -`
Expected: every line starts with `OK`.

- [ ] **Step 4: Commit**

```bash
git add skills/woo-stack-bootstrap/SKILL.md
git commit -m "refactor(skill): update bootstrap SKILL name and invocation"
```

> **PR A boundary:** open a PR with A1–A2. Pure rename, no behavior change.

---

## PR B — Port woo-review as first-party `woo-stack-review`

### Task B1: Copy the woo-review engine into skills/

**Files:**
- Create: `skills/woo-stack-review/` (from `.agents/skills/woo-review/`)

- [ ] **Step 1: Copy the dev vendored copy into the canonical location**

```bash
git mv .agents/skills/woo-review skills/woo-stack-review
```

- [ ] **Step 2: Verify the engine arrived intact**

Run: `ls skills/woo-stack-review/scripts/ | wc -l && ls skills/woo-stack-review/prompts/ | wc -l && test -f skills/woo-stack-review/SKILL.md && echo SKILL_OK`
Expected: a non-zero script count, a non-zero prompt count, and `SKILL_OK`.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat(review): port woo-review engine to skills/woo-stack-review"
```

### Task B2: Rewrite internal skill-dir source paths

The scripts carry `# shellcheck source=skills/woo-review/scripts/...` directives and any self-referential `skills/woo-review/` paths. These must point at the new dir.

**Files:**
- Modify: every file under `skills/woo-stack-review/` containing `skills/woo-review/`

- [ ] **Step 1: Find the references**

Run: `grep -rl "skills/woo-review/" skills/woo-stack-review/`
Expected: a list of script files (e.g. `chunk-diff.sh`, `detect-angles.sh`, `prefetch.sh`, …).

- [ ] **Step 2: Rewrite them**

```bash
grep -rl "skills/woo-review/" skills/woo-stack-review/ | xargs sed -i '' 's#skills/woo-review/#skills/woo-stack-review/#g'
```
(On GNU sed drop the `''` after `-i`.)

- [ ] **Step 3: Verify none remain**

Run: `grep -rn "skills/woo-review/" skills/woo-stack-review/ || echo CLEAN`
Expected: `CLEAN`.

- [ ] **Step 4: Syntax-check every script**

Run: `for s in skills/woo-stack-review/scripts/*.sh; do bash -n "$s" || echo "SYNTAX FAIL $s"; done; echo done`
Expected: `done` with no `SYNTAX FAIL` lines.

- [ ] **Step 5: Commit**

```bash
git add skills/woo-stack-review/
git commit -m "fix(review): repoint internal source paths to woo-stack-review"
```

### Task B3: Rewrite consumer state dir `.woo-review/` → `.woo-stack/`

**Files:**
- Modify: every file under `skills/woo-stack-review/` containing `.woo-review/` (scripts, SKILL.md, prompts)

- [ ] **Step 1: Inventory the references**

Run: `grep -rl "\.woo-review/" skills/woo-stack-review/`
Expected: `load-config.sh`, `memory-append.sh`, `metrics-fold.sh`, `prefetch.sh`, `detect-angles.sh`, `SKILL.md`, and others.

- [ ] **Step 2: Rewrite them**

```bash
grep -rl "\.woo-review/" skills/woo-stack-review/ | xargs sed -i '' 's#\.woo-review/#.woo-stack/#g'
```

- [ ] **Step 3: Catch bare `.woo-review` tokens (no trailing slash)**

Run: `grep -rn "\.woo-review\b" skills/woo-stack-review/ || echo CLEAN`
If any remain (e.g. `metrics-fold.sh` mkdir of the dir), rewrite:
```bash
grep -rl "\.woo-review\b" skills/woo-stack-review/ | xargs sed -i '' 's#\.woo-review\b#.woo-stack#g'
```
Expected after: re-running the grep prints `CLEAN`.

- [ ] **Step 4: Re-syntax-check scripts**

Run: `for s in skills/woo-stack-review/scripts/*.sh; do bash -n "$s" || echo "SYNTAX FAIL $s"; done; echo done`
Expected: `done`, no failures.

- [ ] **Step 5: Commit**

```bash
git add skills/woo-stack-review/
git commit -m "feat(review): unify consumer state dir .woo-review -> .woo-stack"
```

### Task B4: Update woo-stack-review SKILL.md identity + commands

**Files:**
- Modify: `skills/woo-stack-review/SKILL.md`

- [ ] **Step 1: Set frontmatter name and install line**

Set `name: woo-stack-review`. Replace the `install:` value with `npx skills add howarewoo/woo-stack` (the collection). Keep `requires.bins: [gh, jq, node]` and the `recommends.skills` list unchanged.

- [ ] **Step 2: Rewrite the command tokens**

Replace every `/woo-review` with `/woo-stack-review` and every `woo-review address` with `woo-stack-review address` in the Commands section and throughout the body. Leave the cross-PR-memory / config sections — only the `.woo-stack/...` paths there (already rewritten in B3) and the command tokens change.

- [ ] **Step 3: Verify**

Run: `grep -n "/woo-review\b\|name: woo-review" skills/woo-stack-review/SKILL.md || echo CLEAN`
Expected: `CLEAN`.

- [ ] **Step 4: Commit**

```bash
git add skills/woo-stack-review/SKILL.md
git commit -m "refactor(review): rename skill to woo-stack-review"
```

### Task B5: Drop the external woo-review lock entry + repoint dev symlinks

**Files:**
- Modify: `skills-lock.json`
- Modify: `.claude/skills/` (symlinks)

- [ ] **Step 1: Remove the woo-review entry from the lock**

Edit `skills-lock.json`, deleting the `"woo-review": { ... }` block (the one whose `source` is `howarewoo/woo-review`, `skillPath` `skills/woo-review/SKILL.md`). Keep all `obra/superpowers` and `grill-me` entries.

- [ ] **Step 2: Validate the lock is still well-formed JSON**

Run: `jq -e '.skills | has("woo-review") | not' skills-lock.json`
Expected: `true` (woo-review key gone, file parses).

- [ ] **Step 3: Repoint the dev symlink so the repo dogfoods the first-party skill**

```bash
rm .claude/skills/woo-review
ln -s ../../skills/woo-stack-review .claude/skills/woo-stack-review
ln -s ../../skills/woo-stack-bootstrap .claude/skills/woo-stack-bootstrap
```

- [ ] **Step 4: Verify symlinks resolve**

Run: `readlink -e .claude/skills/woo-stack-review .claude/skills/woo-stack-bootstrap`
Expected: two absolute paths under `skills/`, both existing.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "chore: dogfood first-party woo-stack-review, drop external woo-review lock entry"
```

> **PR B boundary:** open a PR with B1–B5. The review skill now lives first-party and reads/writes `.woo-stack/`.

---

## PR C — Add the `woo-stack-build` skill

### Task C1: Author the HTML spec template

**Files:**
- Create: `skills/woo-stack-build/references/spec-template.html`

- [ ] **Step 1: Create the self-contained template**

Create `skills/woo-stack-build/references/spec-template.html` with a complete, styled, single-file HTML skeleton the build skill populates per feature. Use placeholder tokens in double braces that build fills in:

```html
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{{TITLE}} — Design Spec</title>
<style>
  :root { --bg:#0f1115; --panel:#171a21; --ink:#e6e9ef; --muted:#9aa4b2; --accent:#6ea8fe; --line:#2a2f3a;
    --sans:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;
    --mono:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace; }
  *{box-sizing:border-box} body{margin:0;background:var(--bg);color:var(--ink);font-family:var(--sans);line-height:1.55}
  .wrap{max-width:920px;margin:0 auto;padding:48px 24px 96px}
  h1{font-size:30px;letter-spacing:-.02em;margin:0 0 6px}
  h2{font-size:21px;border-left:3px solid var(--accent);padding-left:10px;margin:40px 0 12px}
  .meta{color:var(--muted);font-size:13px;border-bottom:1px solid var(--line);padding-bottom:20px;margin-bottom:28px}
  code{font-family:var(--mono);background:#20242d;padding:1px 6px;border-radius:5px;font-size:13px}
  table{border-collapse:collapse;width:100%;margin:12px 0;font-size:14px}
  th,td{text-align:left;padding:9px 12px;border-bottom:1px solid var(--line);vertical-align:top}
  th{color:var(--muted);text-transform:uppercase;font-size:12px;letter-spacing:.04em}
  .panel{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:16px 18px;margin:14px 0}
</style>
</head>
<body><div class="wrap">
  <h1>{{TITLE}}</h1>
  <div class="meta">Status: {{STATUS}} · Date: {{DATE}} · Branch: {{BRANCH}}</div>
  <h2>1. Problem</h2><div class="panel">{{PROBLEM}}</div>
  <h2>2. Goal</h2><div class="panel">{{GOAL}}</div>
  <h2>3. Non-goals</h2><div class="panel">{{NON_GOALS}}</div>
  <h2>4. Approach</h2><div class="panel">{{APPROACH}}</div>
  <h2>5. Components & data flow</h2><div class="panel">{{COMPONENTS}}</div>
  <h2>6. Error handling</h2><div class="panel">{{ERRORS}}</div>
  <h2>7. Testing</h2><div class="panel">{{TESTING}}</div>
  <h2>8. Open questions</h2><div class="panel">{{OPEN_QUESTIONS}}</div>
</div></body>
</html>
```

- [ ] **Step 2: Verify it is valid standalone HTML**

Run: `grep -c "{{" skills/woo-stack-build/references/spec-template.html`
Expected: a count ≥ 9 (the placeholder tokens are present for build to fill).

- [ ] **Step 3: Commit**

```bash
git add skills/woo-stack-build/references/spec-template.html
git commit -m "feat(build): add HTML spec template"
```

### Task C2: Author the build SKILL.md

**Files:**
- Create: `skills/woo-stack-build/SKILL.md`

- [ ] **Step 1: Write the SKILL.md**

Create `skills/woo-stack-build/SKILL.md` with this exact content:

````markdown
---
name: woo-stack-build
description: Use when building a feature with the full woo-stack development loop — brainstorm a design, harden it, plan it, and implement it. Chains superpowers (brainstorming, writing-plans, executing-plans) and grill-me in a fixed, gated order; writes HTML specs and markdown plans under .woo-stack/.
---

# woo-stack-build

## Overview

Drives one feature from idea to implementation through a fixed, gated chain. Thin
glue: it sequences proven sub-skills and **inherits their gates** — it adds none of
its own. The value is the order and the handoffs.

```
brainstorming → write spec (HTML) → grill-me → writing-plans → executing-plans → ask: open PR?
```

## Dependency preflight

This skill chains external skills. At the start, check that each is installed:

- `superpowers:brainstorming`, `superpowers:writing-plans`, `superpowers:executing-plans`
- `grill-me`

For any that are missing: name exactly what's missing and **offer to install it inline**
(`npx skills add obra/superpowers`, `npx skills add mattpocock/skills` for grill-me) and
continue. If the user declines, fall back to following the skill's principle manually and
**say so explicitly** — the run is degraded, not equivalent.

## Procedure

1. **Brainstorm.** Invoke `superpowers:brainstorming` to explore the problem and converge
   on a design. Let it run its own approval gate.
2. **Write the spec as HTML.** When the design is approved, do **not** write the default
   markdown to `docs/superpowers/specs/`. Instead author a self-contained HTML spec to
   `.woo-stack/specs/YYYY-MM-DD-<slug>.html`, populating
   [references/spec-template.html](references/spec-template.html). HTML is for
   visualization — richer than markdown.
3. **Harden it.** Invoke `grill-me` against the HTML spec. Amend the spec in place until
   grilling stops producing new questions.
4. **Plan.** Invoke `superpowers:writing-plans`, saving the plan as **markdown** to
   `.woo-stack/plans/YYYY-MM-DD-<slug>.md` (plans are working checklists, not visualization
   artifacts).
5. **Decompose to PR-sized increments.** Steer work toward well-scoped PRs of **preferably
   ≤500 lines of code** — a soft target, not a gate. When the spec implies more than one
   reviewable PR, structure the plan as a sequence of independently shippable increments and
   run **one increment per build cycle**. Flag any slice that can't reasonably stay under the
   target and propose a further split before executing. Genuinely atomic changes may exceed
   the target.
6. **Execute.** Invoke `superpowers:executing-plans` (or `superpowers:subagent-driven-development`)
   to work the plan with TDD and frequent commits.
7. **Offer the PR.** When the increment lands on the branch, **ask** whether to open a PR. If
   yes, open it (hands off to `woo-stack-review`). If no, stop on the branch.

## Hard constraints

- **Inherit gates, add none.** Do not insert extra approval stops between phases.
- **HTML specs, markdown plans, under `.woo-stack/`.** Never write specs to the superpowers
  default location or format.
- **Never merge.** build ends by offering a PR, nothing further.
- **One increment per cycle.** Do not let a single build cycle balloon past a reviewable PR.
````

- [ ] **Step 2: Verify frontmatter and cross-link**

Run: `head -4 skills/woo-stack-build/SKILL.md | grep -q "name: woo-stack-build" && test -f skills/woo-stack-build/references/spec-template.html && echo OK`
Expected: `OK`.

- [ ] **Step 3: Verify the template link resolves**

Run: `cd skills/woo-stack-build && grep -o 'references/[a-z-]*\.html' SKILL.md | while read f; do test -f "$f" && echo "OK $f" || echo "MISSING $f"; done; cd -`
Expected: `OK references/spec-template.html`.

- [ ] **Step 4: Add the build symlink for dogfooding**

```bash
ln -s ../../skills/woo-stack-build .claude/skills/woo-stack-build
readlink -e .claude/skills/woo-stack-build
```
Expected: an existing absolute path.

- [ ] **Step 5: Commit**

```bash
git add skills/woo-stack-build/SKILL.md .claude/skills/woo-stack-build
git commit -m "feat(build): add woo-stack-build orchestration skill"
```

> **PR C boundary:** open a PR with C1–C2.

---

## PR D — Add the `woo-stack-address-comments` skill

### Task D1: Author the thin address-comments SKILL.md

**Files:**
- Create: `skills/woo-stack-address-comments/SKILL.md`

- [ ] **Step 1: Write the SKILL.md**

Create `skills/woo-stack-address-comments/SKILL.md` with this exact content:

````markdown
---
name: woo-stack-address-comments
description: Use when addressing the unresolved review threads on a pull request — fix or push back on each finding, reply, resolve, and push. Delegates to the woo-stack-review address verb; never merges.
---

# woo-stack-address-comments

## Overview

Addresses the unresolved review threads on a PR autonomously: for each thread, verify the
concern against the code, then **FIX** / **ACCEPT** (push back, with reasoning) / **CLARIFY**,
reply without performative language, resolve, and push. Ends by offering a re-review.
**Never merges.**

This is a thin entry point. The engine is the `address` verb of the `woo-stack-review` skill
— there is no separate implementation here.

## Dependency preflight

This skill delegates to `woo-stack-review` (its sibling in the woo-stack collection). If it
is not installed, name it and **offer to install the collection inline**
(`npx skills add howarewoo/woo-stack`), then continue. There is no manual fallback — the
address engine lives in that skill.

## Procedure

1. **Preflight** `woo-stack-review` as above.
2. **Invoke** `woo-stack-review address <PR#>` (or the current branch's open PR when no number
   is given). It fetches unresolved threads into `/tmp/pr-review/address-threads.json`, reads
   `.woo-stack/memory.md` if present, and processes every thread per its own rubric.
3. **Offer re-review.** When all threads are handled and pushed, offer to run
   `woo-stack-review` again. Stop there — do not merge.

## Hard constraints

- **No merge.** Branch protection and the merge decision stay with the user.
- **No duplicate engine.** All thread-handling logic lives in `woo-stack-review`; this skill
  only routes to it.
- **No performative replies.** Reply with the technical reasoning or the fix itself.
````

- [ ] **Step 2: Verify frontmatter**

Run: `grep -q "name: woo-stack-address-comments" skills/woo-stack-address-comments/SKILL.md && echo OK`
Expected: `OK`.

- [ ] **Step 3: Verify the delegation target exists**

Run: `test -f skills/woo-stack-review/SKILL.md && grep -qi "address" skills/woo-stack-review/SKILL.md && echo OK`
Expected: `OK` (the address verb it delegates to is present).

- [ ] **Step 4: Add the symlink for dogfooding**

```bash
ln -s ../../skills/woo-stack-address-comments .claude/skills/woo-stack-address-comments
readlink -e .claude/skills/woo-stack-address-comments
```
Expected: an existing absolute path.

- [ ] **Step 5: Commit**

```bash
git add skills/woo-stack-address-comments/SKILL.md .claude/skills/woo-stack-address-comments
git commit -m "feat(address): add thin woo-stack-address-comments skill"
```

> **PR D boundary:** open a PR with D1.

---

## PR E — Documentation reframe

### Task E1: Trim development.md to pointer + branching model

**Files:**
- Modify: `skills/woo-stack-bootstrap/references/development.md`

- [ ] **Step 1: Replace the loop prose with a pointer**

Replace the `## The loop` section and Steps 1–11 with a short pointer block. Keep the
`## Branching model` table and `## When to deviate` verbatim. The new top of the file:

```markdown
# Development Guide

End-to-end workflow for shipping a change into a project bootstrapped from this spec.

## The loop

The loop is **automated by the woo-stack skill collection** — these are the source of truth
for each phase:

| Phase | Skill |
|---|---|
| Brainstorm → spec (HTML) → grill → plan → execute | `woo-stack-build` |
| Review | `woo-stack-review` |
| Address review feedback | `woo-stack-address-comments` |

Each command is discrete and ends by offering the next step. Merge stays with the human.

Artifacts live under `.woo-stack/` in the project: HTML specs in `.woo-stack/specs/`,
markdown plans in `.woo-stack/plans/`, review config/memory in `.woo-stack/config.json`
and `.woo-stack/memory.md` (`.woo-stack/metrics.json` is gitignored).
```

Leave the existing `## Branching model` and `## When to deviate` sections below this, unchanged.

- [ ] **Step 2: Verify no orphaned step references**

Run: `grep -n "Step [0-9]\|brainstorming\]\(http" skills/woo-stack-bootstrap/references/development.md || echo CLEAN`
Expected: `CLEAN` (no numbered-step prose; branching model has no such references).

- [ ] **Step 3: Verify intra-doc links still resolve**

Run: `cd skills/woo-stack-bootstrap/references && grep -o 'patterns\.md[^)]*' development.md | head; test -f patterns.md && echo OK; cd -`
Expected: `OK`.

- [ ] **Step 4: Commit**

```bash
git add skills/woo-stack-bootstrap/references/development.md
git commit -m "docs(bootstrap): trim development.md; skills own the loop"
```

### Task E2: Reframe README.md to the collection

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Rewrite the intro, Install, Use, and table sections**

- Intro line → "**An installable collection of opinionated skills for building software — bootstrap, build, review, address review feedback.**"
- Keep the install command `npx skills add howarewoo/woo-stack`, but change the explanation: it installs the woo-stack **collection** (`woo-stack-bootstrap`, `woo-stack-build`, `woo-stack-review`, `woo-stack-address-comments`).
- Replace the single-command Use block with a four-command table:

```markdown
## Commands

| Command | What it does |
|---|---|
| `/woo-stack-bootstrap <goal>` | Scaffold a new web/mobile/API monorepo at latest versions. |
| `/woo-stack-build <goal>` | Feature loop: brainstorm → HTML spec → grill → plan → execute. |
| `/woo-stack-review [PR#]` | Parallel review swarm + skeptical validation; posts a batched GitHub review. |
| `/woo-stack-address-comments [PR#]` | Address unresolved review threads autonomously. No merge. |

Artifacts land under `.woo-stack/` (HTML specs, markdown plans, review config/memory).
```

- Update the "What it defines" table paths to `skills/woo-stack-bootstrap/references/...`.
- Add a note: **woo-review is now first-party here; the standalone `howarewoo/woo-review` repo is deprecated.**

- [ ] **Step 2: Verify all README relative links resolve**

Run: `grep -o '](skills/[^)]*)' README.md | sed 's/](//;s/)//' | while read f; do test -e "$f" && echo "OK $f" || echo "MISSING $f"; done`
Expected: every line starts with `OK`.

- [ ] **Step 3: Commit**

```bash
git add README.md
git commit -m "docs: reframe README to the woo-stack skill collection"
```

### Task E3: Update AGENTS.md (layout, modes, quick-reference)

**Files:**
- Modify: `AGENTS.md`

- [ ] **Step 1: Update the repo-layout block**

Replace the `skills/woo-stack/` subtree in the layout block with the four-skill layout from this plan's File Structure section.

- [ ] **Step 2: Update the two modes**

- Mode A (editing the skill) → "editing **a** skill in the collection."
- Mode B (bootstrapping) → broaden to "running a collection command" and list the four commands and where each is defined.

- [ ] **Step 3: Update the Skills section + quick-reference table**

- Skills section: woo-review is no longer a consumed external dev skill; it is first-party at `skills/woo-stack-review/`. superpowers + grill-me remain consumed via `.agents/skills/` + `skills-lock.json`.
- Quick-reference table: add rows mapping each task to the new file paths (`skills/woo-stack-build/SKILL.md`, etc.); update the bootstrap rows to `skills/woo-stack-bootstrap/...`.
- "What NOT to do": update the "do not move/rename `skills/woo-stack/SKILL.md`" rule to reference the four SKILL.md paths.

- [ ] **Step 4: Verify AGENTS.md links resolve**

Run: `grep -o '](skills/[^)]*)' AGENTS.md | sed 's/](//;s/)//' | while read f; do test -e "$f" && echo "OK $f" || echo "MISSING $f"; done`
Expected: every line starts with `OK`.

- [ ] **Step 5: Commit**

```bash
git add AGENTS.md
git commit -m "docs(agents): reframe layout, modes, and quick-reference for the collection"
```

### Task E4: Gitignore metrics + finalize

**Files:**
- Modify: `.gitignore` (create if absent)

- [ ] **Step 1: Add the ignore entry**

Append to `.gitignore`:

```gitignore
# woo-stack: local-only review metrics (config.json and memory.md stay tracked)
.woo-stack/metrics.json
```

- [ ] **Step 2: Verify the rule matches**

Run: `git check-ignore .woo-stack/metrics.json`
Expected: prints `.woo-stack/metrics.json` (the rule matches).

- [ ] **Step 3: Repo-wide stale-reference sweep**

Run: `grep -rn "woo-review\|skills/woo-stack/SKILL" README.md AGENTS.md skills/ --include=*.md | grep -v "deprecated\|first-party\|howarewoo/woo-review repo" || echo CLEAN`
Expected: `CLEAN`, or only the intentional deprecation-note mentions.

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "chore: gitignore .woo-stack/metrics.json"
```

> **PR E boundary:** open a PR with E1–E4. Docs now describe the collection; the loop lives in the skills.

---

## Final verification (run before the last PR merges)

- [ ] **All scripts parse:** `for s in skills/woo-stack-review/scripts/*.sh; do bash -n "$s" || echo "FAIL $s"; done; echo done` → `done`, no failures.
- [ ] **No internal stale paths:** `grep -rn "skills/woo-review/" skills/ || echo CLEAN` → `CLEAN`.
- [ ] **No consumer stale paths:** `grep -rn "\.woo-review" skills/ || echo CLEAN` → `CLEAN`.
- [ ] **Lock is valid + woo-review gone:** `jq -e '.skills | has("woo-review") | not' skills-lock.json` → `true`.
- [ ] **Four SKILLs present:** `ls skills/*/SKILL.md | wc -l` → at least `4`.
- [ ] **Dogfood symlinks resolve:** `readlink -e .claude/skills/woo-stack-{bootstrap,build,review,address-comments}` → four existing paths.
- [ ] **Every markdown skill cross-link resolves:** run the link-check loops from E2/E3 across `README.md`, `AGENTS.md`, and each new `SKILL.md`; all `OK`.

---

## Self-review notes

- **Spec coverage:** four skills (B/C/D + A rename), HTML specs + `.woo-stack/` paths (C1/C2), markdown plans (C2), dependency preflight (C2/D1 inline — `_shared` dropped per self-contained-install constraint), ported woo-review with both renames (B2/B3), `.woo-review`→`.woo-stack` unify (B3), metrics gitignore (E4), no-merge (C2/D1), PR-sizing (C2), naming hyphen-not-colon (all SKILLs/README), development.md trim (E1), README/AGENTS/skills-lock reframe (E2/E3/B5). All spec sections map to a task.
- **Open items resolved:** shared-engine → delegation (D1); multi-skill install → single collection install `npx skills add howarewoo/woo-stack`, each SKILL self-contained (README/B4); .agents dev copy → `git mv` to first-party + repoint symlinks (B1/B5); HTML authoring mechanics → template + explicit override step in build (C1/C2).
- **No placeholders:** new SKILL.md files and the trimmed development.md are given in full; edits to existing files (README/AGENTS) name exact sections and replacement text.
