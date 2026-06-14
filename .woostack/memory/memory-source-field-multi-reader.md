---
name: memory-source-field-multi-reader
type: gotcha
scope: skills/woostack-doctor/scripts/checks/memory*.sh,skills/woostack-init/references/memory.md
tags: memory, source, provenance, wikilink, doctor, back-compat, obsidian
hook: A memory note's frontmatter source: is parsed by TWO doctor checks (provenance + unresolved-link) — change its form and both must move, and the prefix set is specs|plans|fixes.
updated: 2026-06-14
source: [[fixes/2026-06-14-memory-source-wikilinks]]
---

A memory note's `source:` is the **one** frontmatter wikilink (provenance), and `memory.sh`
parses it in **two** places that must change together:

- **provenance check** — file-exists staleness; the path `case` must list all three authored
  artifact dirs `.woostack/specs|plans|fixes/*` (fixes was silently uncovered before).
- **unresolved-link check** — greps the **whole file** (frontmatter included), so a
  folder-qualified `specs|plans|fixes/<basename>` wikilink source must resolve against
  `$WOO_ROOT/.woostack/`, not `$MEM_DIR`, or it false-fires `unresolved`.

Other gotchas: Obsidian **does** index wikilinks in frontmatter values (that is why the graph
edge works); `recall.sh` one-hop expand is safe to leave (its `[ -f "$MEM_DIR/…" ]` guard
skips artifact links). Readers accept both the wikilink and the legacy `.woostack/…` path. And
because that same check greps the whole body, never write a literal double-bracket example in
a note body — it is read as a link. Same multi-reader trap as the plan join — see
[[source-line-is-multi-reader-contract]].
