---
name: woostack-init
type: spec
status: draft
date: 2026-06-02
branch: feat/woostack-init
increment: A of 4
links: memory-contract
---

# woostack-init — Design Spec

> Increment A of 4. Visualize on demand: render this file with `spec-template.html` if a rich view is wanted.

## 1. Problem

woostack skills write into a per-repo `.woostack/` workspace, but nothing creates or owns it. It is born ad-hoc: `memory-append.sh` does `mkdir -p .woostack` on first write, woostack-build drops specs and plans into `.woostack/specs|plans`, and `.woostack/config.json` is hand-authored. There is no canonical setup step, no schema, and no validation.

The memory store is a single flat `.woostack/memory.md` bullet list that `prefetch.sh` copies whole (100 KB cap) into every review worker. That dump-everything model does not scale: on a large codebase the team's accumulated gotchas/decisions become a wall of text fed to every angle regardless of which files a PR touches. There is no way to say "this rule governs `packages/api/**`" and load it only when that code is in play.

This increment lays the foundation: a skill that scaffolds and validates `.woostack/`, plus the contract for a scope-routed memory store that later increments migrate the skills onto.

## 2. Goal

Ship a new first-party skill `woostack-init` that scaffolds and repairs the `.woostack/` workspace in any repo (brownfield via `/woostack-init`; greenfield via woostack-bootstrap calling it), and that **owns the canonical memory contract** plus its tooling.

- **Scaffold the full workspace**: `memory/` + derived index, flat `memory.md` global shard, `config.json` skeleton, `specs/` + `plans/` dirs, `.gitignore`.
- **Define the scope-routed memory format** in `references/memory.md`: line-oriented frontmatter, a derived `MEMORY.md` index, and the index-first → scope-match → one-hop-link recall procedure that makes recall scale to large codebases.
- **Ship two pure-bash scripts**: `build-index.sh` (regenerate the index) and `doctor.sh` (lint the store).
- **Preserve the existing flat store** as an additive superset: today's `.woostack/memory.md` stays valid and untouched as the always-loaded "global scope" shard.

## 3. Non-goals

Strictly out of scope for increment A (reserved for later increments, must not be built here):

- **B — review migration.** No changes to `prefetch.sh`, `memory-append.sh`, the review pipeline, or its SKILL.md. Review keeps reading the flat `memory.md` exactly as it does today. Scope-routing adoption in the review swarm is increment B.
- **C — build/bootstrap/address wiring.** No distill step in woostack-build, no bootstrap→init call, no memory-read in address-comments. (A may add the AGENTS.md skill table row + manual cross-links so the new skill is discoverable, but no behavioral wiring into the other skills.)
- **D — Obsidian layer.** No `.obsidian/` config scaffolding, no `obsidian eval` graph traversal. The `doctor` unresolved-link check is the portable stand-in.
- No new runtime dependency. Scripts are bash + coreutils only — no node, python, or YAML library. (Matches the existing review scripts, which run in bare consumer CI.)
- No migration of flat `memory.md` bullets into per-fact files. Coexistence, not conversion.

## 4. Approach

### Additive superset, not replacement

The flat `.woostack/memory.md` remains valid and is treated as the **global-scope shard**: always loaded, bullet format, written by the existing `memory-append.sh`. The new `.woostack/memory/` dir adds **scoped per-fact notes**. Any combination is valid — only-flat (today's repos), only-dir, or both. Nothing breaks; consumers adopt scoping lazily.

### Scope-routed recall is the scaling mechanism

Each note declares a `scope:` glob list mapping it to the code it governs. Recall is **agent behavior documented in the contract**, not a script:

1. Always load `memory/MEMORY.md` (one cheap line per note) + the flat `memory.md` global shard.
2. Compute the working-set of paths (skill-specific: review = changed files, build = planned files, address = touched files).
3. **Scope-match:** load the body of any note whose `scope` glob hits any working-set path.
4. **One-hop link expand:** load notes directly `[[linked]]` from step-3 notes. Bounded to one hop.
5. Stop. Unmatched notes are never loaded. (500 notes in a repo → ~8 loaded.)

Routing needs only glob-matching — no graph engine, no Obsidian. A note with no `scope` (or `scope: *`) is global, which is exactly what the flat file's bullets implicitly are.

### The index is derived

`MEMORY.md` is regenerated from note frontmatter by `build-index.sh`, sorted deterministically. It is never hand-edited. Because it is derived rather than hand-appended, concurrent writers (e.g. a parallel review swarm) each drop their own note file and the index is rebuilt — removing the contended-append merge problem (the issue #53 failure class).

### Ownership by an init skill

Rather than a loose shared directory, the contract and scripts live under the owning skill `skills/woostack-init/`. It is discoverable (`/woostack-init`), has a clear lifecycle verb, and is the single home other skills reference. woostack becomes a **five-skill** collection.

### Specs are markdown vault nodes

Specs are authored as **markdown** under `.woostack/specs/` with `type: spec` frontmatter — so they are Obsidian graph nodes that can `[[link]]` to memory notes and vice versa, while being excluded from recall routing by type. Rich visualization is **on demand**: `spec-template.html` is retained as a render target a user can ask for, not the default authoring format. (This spec file dogfoods that decision.)

## 5. Components & data flow

### 5.1 Repo layout (shipped by this skill)

```
skills/woostack-init/
├── SKILL.md                  the /woostack-init verb
├── references/
│   └── memory.md             THE contract — schema + recall procedure (canonical)
├── scripts/
│   ├── build-index.sh        regenerate MEMORY.md from note frontmatter
│   └── doctor.sh             lint the store
└── templates/
    ├── config.json           skeleton: { "review": {} }
    ├── gitignore             tracked-vs-ignored rules for .woostack/
    └── example-note.md       one worked scoped note
```

### 5.2 Runtime workspace (what /woostack-init scaffolds in a consumer repo)

```
.woostack/
├── memory.md        flat global shard — seeded empty if absent, NEVER clobbered
├── memory/
│   ├── MEMORY.md    derived index (build-index writes it)
│   └── .gitkeep
├── specs/           woostack-build markdown specs (type: spec)
├── plans/           woostack-build markdown plans
├── config.json      { "review": {} } skeleton; sibling tool namespaces documented
└── .gitignore       ignores transient (e.g. metrics.json); keeps memory/specs/plans tracked
```

### 5.3 Note frontmatter (line-oriented, bash-parseable)

```
---
name: orpc-error-mapping
type: pattern
scope: packages/api/**, packages/api/orpc/**
tags: orpc, errors
links: tanstack-query-retries
updated: 2026-06-02
source:
---
oRPC ORPCError maps to TanStack retry policy: throw typed,
let [[tanstack-query-retries]] decide. Terse body.
```

- One `key: value` per line; lists are comma-separated (NOT YAML block lists) so `grep '^scope:' | cut` parses them in bash.
- **required**: `name`, `type`, and a non-empty body. Everything else optional.
- `type` enum: `decision | pattern | gotcha | convention | hotspot`. (`spec | plan` are reserved for specs/plans and are excluded from recall routing.)
- `scope` omitted or `*` → global (always loaded). Otherwise a comma list of globs.
- `source` → provenance path (used by the increment-C distill step; empty in A).
- Body links other notes with `[[name]]`.

### 5.4 Derived index line format

```
- [orpc-error-mapping](orpc-error-mapping.md) `pattern` scope=`packages/api/**` — oRPC error → TanStack retry policy
```

Sorted by `type` then `name` → stable diffs.

### 5.5 `/woostack-init` control flow

1. Resolve target dir (arg or cwd). Detect existing `.woostack/` contents.
2. For each scaffold item: create if missing. If it **exists**, prompt _keep / overwrite_ — unless `--force` (overwrite all) or `--no-clobber` (skip all existing silently). Greenfield has no existing files, so no prompts fire.
3. Run `build-index.sh` then `doctor.sh`.
4. Report: created vs skipped items, and any doctor warnings/errors.

### 5.6 `build-index.sh`

Walk `.woostack/memory/*.md` (skip `MEMORY.md`). For each: extract `name`, `type`, first `scope` glob, and a hook (first non-empty body line, truncated). Emit sorted index lines to `MEMORY.md`. Idempotent — same input, byte-identical output.

### 5.7 `doctor.sh` (lint)

| Check | Severity | Exit |
|---|---|---|
| `scope` glob matches zero files in repo | warn (stale) | 0 |
| `[[link]]` with no matching note file | warn (unresolved) | 0 |
| duplicate `name` | error | 1 |
| missing required field (`name`/`type`/body) | error | 1 |
| unknown `type` value | error | 1 |
| malformed frontmatter (not line-oriented / no `---` fences) | error | 1 |

Warnings are informational (exit 0); errors fail the run (exit 1) so the check is gate-able in CI later.

## 6. Error handling

- **Never clobber memory.** Existing `memory.md`, notes, and `config.json` are preserved unless the user explicitly answers overwrite (or passes `--force`). This is the cardinal rule — accumulated team knowledge must survive a re-run.
- **Conflict prompt vs non-interactive.** Default is interactive prompt-on-conflict. `--force` / `--no-clobber` give deterministic non-interactive behavior for bootstrap and CI. The skill states which mode it used in its report.
- **Scripts use `set -euo pipefail`** and fail loudly. `build-index` writing a malformed line is prevented by validating each field before emit; on a parse failure it errors rather than writing a half-built index.
- **doctor is advisory in A.** It is not yet wired into any gate (that is B/CI). It reports; the user decides. No silent suppression — every stale scope and unresolved link is printed.
- **Missing shared assets degrade gracefully.** If a later skill cannot find `skills/woostack-init/scripts/*` (single-skill install), it falls back to the documented manual procedure and says so — it does not fail silently.

## 7. Testing

This repo has no app test runner. Verification is script-level (bash) + manual skill walkthroughs, consistent with the existing review scripts.

**Script tests (bats-style or plain bash asserts, run locally)**

- `build-index`: empty dir → empty index; N notes → N sorted lines; re-run → byte-identical output (idempotent); a note missing `scope` → indexed as global.
- `doctor`: clean store → exit 0, no warnings; stale scope → warn + exit 0; unresolved `[[link]]` → warn + exit 0; duplicate name / bad type / missing field / malformed frontmatter → error + exit 1.
- Frontmatter parse: comma lists split correctly; values with spaces survive; CRLF tolerated.

**Skill walkthrough (manual)**

- Greenfield: `/woostack-init` in an empty repo → full tree created, no prompts, doctor clean.
- Brownfield: run in a repo that already has flat `memory.md` + `config.json` → existing files preserved (prompt shown), missing dirs added, index built.
- `--force` and `--no-clobber` behave as specified with no prompts.

**Self-check**

- Every cross-link in `references/memory.md` and AGENTS.md resolves.
- The shipped `example-note.md` passes `doctor` and indexes correctly.

## 8. Open questions

- **Spec format flip ownership.** Making specs markdown edits woostack-build's SKILL.md + template (`spec-template.html` → `.md` default, HTML kept as render target). Does that ride in increment A's PR or land as its own fast-follow? (Cross-skill edit vs single-concern PR.)
- **Hook source for the index.** First non-empty body line, truncated — or an explicit optional `hook:` frontmatter field? Leaning first-body-line; revisit if hooks read poorly.
- **`.gitignore` granularity.** Confirm which `.woostack/` artifacts are transient (per-clone `metrics.json` is; memory/specs/plans are tracked). Finalize the template during planning.
- **Single-skill install bundling.** `shared`-style assets under one skill may not ship when only another skill is installed. Accepted for now (collection install is the supported path); documented as a degradation, not a blocker.
