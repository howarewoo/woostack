---
name: woostack-init
type: spec
status: approved
date: 2026-06-02
branch: feat/woostack-init
increment: A of 4
---

# woostack-init — Design Spec

> **Plan:** [[plans/2026-06-02-woostack-init]]

> Increment A of 4. Hardened via grill-me 2026-06-02. Visualize on demand: render this file with `spec-template.html` if a rich view is wanted.

## 1. Problem

woostack skills write into a per-repo `.woostack/` workspace, but nothing creates or owns it. It is born ad-hoc: `memory-append.sh` does `mkdir -p .woostack` on first write, woostack-build drops specs and plans into `.woostack/specs|plans`, and `.woostack/config.json` is hand-authored. There is no canonical setup step, no schema, and no validation.

The memory store is a single flat `.woostack/memory.md` bullet list that `prefetch.sh` copies whole (100 KB cap) into every review worker. That dump-everything model does not scale: on a large codebase the team's accumulated gotchas/decisions become a wall of text fed to every angle regardless of which files a PR touches. There is no way to say "this rule governs `packages/api/**`" and load it only when that code is in play.

This increment lays the foundation: a skill that scaffolds and validates `.woostack/`, plus the contract for a scope-routed memory store that later increments migrate the skills onto.

## 2. Goal

Ship a new first-party skill `woostack-init` that scaffolds and repairs the `.woostack/` workspace in any repo (brownfield via `/woostack-init`; greenfield via woostack-bootstrap calling it), and that **owns the canonical memory contract** plus its tooling.

- **Scaffold the full workspace**: `memory/` + derived index, flat `memory.md` global shard, `config.json` skeleton, `specs/` + `plans/` dirs, `.gitignore`.
- **Define the scope-routed memory format** in `references/memory.md` (the `[[memory-contract]]` note): line-oriented frontmatter, a derived `MEMORY.md` index, pinned glob→match semantics, and the index-first → scope-match → one-hop-link recall procedure that makes recall scale to large codebases.
- **Ship three pure-bash scripts**: `build-index.sh` (regenerate the index), `scope-match.sh` (the glob→path matching primitive), and `doctor.sh` (lint the store, consuming `scope-match`).
- **Preserve the existing flat store** as an additive superset: today's `.woostack/memory.md` stays valid and untouched as the always-loaded "global scope" shard.

## 3. Non-goals

Strictly out of scope for increment A (reserved for later increments, must not be built here):

- **B — review migration + recall orchestration.** No changes to `prefetch.sh`, `memory-append.sh`, the review pipeline, or its SKILL.md. Review keeps reading the flat `memory.md` exactly as it does today. The **`recall.sh` orchestration** (compute the working-set of paths, drive `scope-match`, load matched note bodies, do the one-hop link expansion) lands in B alongside the first real consumer — A ships only the `scope-match` primitive it reuses.
- **C — build/bootstrap/address wiring.** No distill step in woostack-build, no bootstrap→init call, no memory-read in address-comments. (A may add the AGENTS.md skill table row + manual cross-links so the new skill is discoverable, but no behavioral wiring into the other skills.)
- **D — Obsidian layer.** No `.obsidian/` config scaffolding, no `obsidian eval` graph traversal. The `doctor` unresolved-link check is the portable stand-in.
- No new runtime dependency. Scripts are bash + coreutils only — no node, python, or YAML library. (Matches the existing review scripts, which run in bare consumer CI.)
- No migration of flat `memory.md` bullets into per-fact files. Coexistence, not conversion.

## 4. Approach

### Additive superset, not replacement

The flat `.woostack/memory.md` remains valid and is treated as the **global-scope shard**: always loaded, bullet format, written by the existing `memory-append.sh`. The new `.woostack/memory/` dir adds **scoped per-fact notes**. Any combination is valid — only-flat (today's repos), only-dir, or both. Nothing breaks; consumers adopt scoping lazily. The new tooling owns the dir only; the flat file stays opaque free-form bullets, untouched by `build-index`/`doctor`, and is simply concatenated at recall as the always-on global shard.

### Scope-routed recall is the scaling mechanism

Each note declares a `scope:` glob list mapping it to the code it governs. The **glob→match semantics are pinned in A** (§5.8) and implemented as the `scope-match.sh` primitive, which `doctor` consumes immediately for stale-scope detection. The full recall procedure is:

1. Always load `memory/MEMORY.md` (one cheap line per note) + the flat `memory.md` global shard.
2. Compute the working-set of paths (skill-specific: review = changed files, build = planned files, address = touched files).
3. **Scope-match:** load the body of any note whose `scope` glob hits any working-set path (via `scope-match`).
4. **One-hop link expand:** load notes directly linked by body `[[wikilinks]]` from step-3 notes. Bounded to one hop.
5. Stop. Unmatched notes are never loaded. (500 notes in a repo → ~8 loaded.)

Steps 2–4 are orchestrated by `recall.sh`, which lands in **increment B** with its first consumer; A ships the `scope-match` primitive (step 3's core) plus this documented procedure. Routing needs only glob-matching — no graph engine, no Obsidian. A note with no `scope` (or `scope: *`) is global, which is exactly what the flat file's bullets implicitly are.

### The index is derived

`MEMORY.md` is regenerated from note frontmatter by `build-index.sh`, sorted deterministically. It is never hand-edited. Because it is derived rather than hand-appended, concurrent writers (e.g. a parallel review swarm) each drop their own note file and the index is rebuilt — removing the contended-append merge problem (the issue #53 failure class).

### Ownership by an init skill

Rather than a loose shared directory, the contract and scripts live under the owning skill `skills/woostack-init/`. It is discoverable (`/woostack-init`), has a clear lifecycle verb, and is the single home other skills reference. woostack becomes a **five-skill** collection.

### Specs are markdown vault nodes

Specs are authored as **markdown** under `.woostack/specs/` with `type: spec` frontmatter — so they are Obsidian graph nodes that can `[[link]]` to memory notes and vice versa, while being excluded from recall routing by type. Rich visualization is **on demand**: `spec-template.html` is retained as a render target a user can ask for, not the default authoring format. (This spec file dogfoods that decision — including body-only `[[wikilinks]]`.)

## 5. Components & data flow

### 5.1 Repo layout (shipped by this skill)

```
skills/woostack-init/
├── SKILL.md                  the /woostack-init verb
├── references/
│   └── memory.md             THE contract — schema, glob semantics, recall procedure (canonical)
├── scripts/
│   ├── build-index.sh        regenerate MEMORY.md from note frontmatter
│   ├── scope-match.sh        glob→path matching primitive (glob→ERE→grep)
│   └── doctor.sh             lint the store (consumes scope-match)
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
├── config.json      { "review": {} } skeleton
└── .gitignore       ignores metrics.json + *.local.* ; tracks memory/specs/plans/config
```

- **config.json ownership:** init scaffolds the file and documents *only* the top-level **namespacing convention** — each tool gets a sibling key (`review`, and a future `memory`/etc. as needed). Each tool owns its own namespace's schema; init's reference cross-links woostack-review's SKILL.md for the `review` keys rather than restating them. Memory needs no config in A.
- **.gitignore:** ignores `metrics.json` (review's explicitly per-clone rolling aggregate) and a `*.local.*` pattern (per-developer overrides, e.g. `config.local.json`, reserved but not yet designed). Everything else — `memory.md`, `memory/`, `specs/`, `plans/`, `config.json` — is shared team knowledge and is tracked.

### 5.3 Note frontmatter (line-oriented, bash-parseable)

```
---
name: orpc-error-mapping
type: pattern
scope: packages/api/**, packages/api/orpc/**
tags: orpc, errors
hook: oRPC error → TanStack retry policy
updated: 2026-06-02
source:
---
oRPC ORPCError maps to TanStack retry policy: throw typed,
let [[tanstack-query-retries]] decide. Terse body.
```

- One `key: value` per line; lists are comma-separated (NOT YAML block lists) so `grep '^scope:' | cut` parses them in bash.
- **required**: `name`, `type`, and a non-empty body. Everything else optional.
- `type` enum: `decision | pattern | gotcha | convention | hotspot`. (`spec | plan` are reserved for specs/plans and are excluded from recall routing.)
- `scope` omitted or `*` → global (always loaded). Otherwise a comma list of globs (§5.8 semantics).
- `hook` → optional one-line index summary. If absent, the index falls back to the first non-empty body line, truncated.
- `source` → provenance path (used by the increment-C distill step; empty in A).
- **Links live in the body only**, as `[[name]]` wikilinks. There is no `links:` frontmatter field — body wikilinks are the single source of truth: Obsidian-native (its graph reads them) and bash-greppable (`grep -oE '\[\[[^]]+\]\]'`). `doctor`'s unresolved check and recall's one-hop expand both parse the body.

### 5.4 Derived index line format

```
- [orpc-error-mapping](orpc-error-mapping.md) `pattern` scope=`packages/api/**` — oRPC error → TanStack retry policy
```

Sorted by `type` then `name` → stable diffs. The trailing hook is the `hook:` field, else the first body line (truncated).

### 5.5 `/woostack-init` control flow

1. Resolve target dir (arg or cwd). Detect existing `.woostack/` contents.
2. For each scaffold item: create if missing. If it **exists**, prompt _keep / overwrite_ — unless `--force` (overwrite all) or `--no-clobber` (skip all existing silently). Greenfield has no existing files, so no prompts fire.
3. Run `build-index.sh` then `doctor.sh`.
4. Report: created vs skipped items, and any doctor warnings/errors.

(Recall is not exercised here — it is a read path owned by the consuming skills in B/C.)

### 5.6 `build-index.sh`

Walk `.woostack/memory/*.md` (skip `MEMORY.md`). For each: extract `name`, `type`, first `scope` glob, and the hook (`hook:` field if present, else first non-empty body line, truncated ~80 chars). Emit sorted index lines to `MEMORY.md`. Indexes the dir only — never reads or rewrites the flat `memory.md`. Idempotent — same input, byte-identical output.

### 5.7 `scope-match.sh` (the matching primitive)

Given a glob (or comma list) and a newline list of repo-relative paths, emit the matching paths (or a boolean). Converts each glob to an ERE and uses `grep -qE`, mirroring `detect-angles.sh`'s proven changed-path matching. This is the shared core that `doctor` uses in A and `recall.sh` reuses in B.

### 5.8 Glob→match semantics (pinned in A)

| Glob token | Means | ERE |
|---|---|---|
| `*` | one path segment (no `/`) | `[^/]*` |
| `**` | any depth, including `/` | `.*` |
| exact text | literal | escaped (`.` → `\.`) |
| `a, b` | comma list | match if **any** alternative matches |

Matched against repo-relative paths, anchored full-path. `scope` omitted or `*` → global (matches everything → always loaded).

### 5.9 `doctor.sh` (lint)

| Check | Mechanism | Severity | Exit |
|---|---|---|---|
| `scope` glob matches zero files in repo | `scope-match` vs `git ls-files` | warn (stale) | 0 |
| body `[[link]]` with no matching note file | name→file existence | warn (unresolved) | 0 |
| duplicate `name` | — | error | 1 |
| missing required field (`name`/`type`/body) | — | error | 1 |
| unknown `type` value | — | error | 1 |
| malformed frontmatter (not line-oriented / no `---` fences) | — | error | 1 |

Lints the `memory/` dir only — the flat `memory.md` is free-form and untouched. Warnings are informational (exit 0); errors fail the run (exit 1) so the check is gate-able in CI later.

## 6. Error handling

- **Never clobber memory.** Existing `memory.md`, notes, and `config.json` are preserved unless the user explicitly answers overwrite (or passes `--force`). This is the cardinal rule — accumulated team knowledge must survive a re-run.
- **Conflict prompt vs non-interactive.** Default is interactive prompt-on-conflict. `--force` / `--no-clobber` give deterministic non-interactive behavior for bootstrap and CI. The skill states which mode it used in its report.
- **Scripts use `set -euo pipefail`** and fail loudly. `build-index` validates each field before emit; on a parse failure it errors rather than writing a half-built index.
- **doctor is advisory in A.** It is not yet wired into any gate (that is B/CI). It reports; the user decides. No silent suppression — every stale scope and unresolved link is printed.
- **Missing shared assets degrade gracefully.** If a later skill cannot find `skills/woostack-init/scripts/*` (single-skill install), it falls back to the documented manual procedure and says so — it does not fail silently.

## 7. Testing

This repo has no app test runner. Verification is script-level (bash) + manual skill walkthroughs, consistent with the existing review scripts.

**Script tests (bats-style or plain bash asserts, run locally)**

- `build-index`: empty dir → empty index; N notes → N sorted lines; re-run → byte-identical output (idempotent); a note missing `scope` → indexed as global; `hook:` field used when present, else first body line.
- `scope-match`: `*` does not cross `/`; `**` does; comma lists match on any alternative; exact paths match literally; dots are escaped; no-scope/`*` matches everything.
- `doctor`: clean store → exit 0, no warnings; stale scope → warn + exit 0; unresolved body `[[link]]` → warn + exit 0; duplicate name / bad type / missing field / malformed frontmatter → error + exit 1; flat `memory.md` is never read.
- Frontmatter parse: comma lists split correctly; values with spaces survive; CRLF tolerated.

**Skill walkthrough (manual)**

- Greenfield: `/woostack-init` in an empty repo → full tree created, no prompts, doctor clean.
- Brownfield: run in a repo that already has flat `memory.md` + `config.json` → existing files preserved (prompt shown), missing dirs added, index built.
- `--force` and `--no-clobber` behave as specified with no prompts.

**Self-check**

- Every cross-link in `references/memory.md` and AGENTS.md resolves.
- The shipped `example-note.md` passes `doctor` and indexes correctly.

## 8. Open questions

All grill-me branches resolved (2026-06-02):

- **Recall mechanism** → semantics pinned + `scope-match` primitive ship in A; `recall.sh` orchestration deferred to increment B with its first consumer.
- **doctor/recall collision** → `scope-match` primitive ships in A (doctor's real consumer); no duplication.
- **Index hook** → optional `hook:` field, else first body line.
- **.gitignore** → ignore `metrics.json` + `*.local.*`; track the rest.
- **Flat-file tooling** → `build-index`/`doctor` own the dir only; `memory.md` stays opaque and untouched.
- **config.json ownership** → init owns the namespacing convention; each tool owns its namespace keys (cross-link, don't duplicate).
- **Links** → body `[[wikilinks]]` only; no `links:` frontmatter field.

Remaining (accepted, not blocking): **single-skill install bundling** — `shared`-style assets under one skill may not ship when only another skill is installed. Accepted; collection install is the supported path; documented as a degradation, not a blocker.
