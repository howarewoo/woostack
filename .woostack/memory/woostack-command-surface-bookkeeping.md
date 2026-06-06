---
name: woostack-command-surface-bookkeeping
type: convention
scope: AGENTS.md, README.md, CONTRIBUTING.md, skills/using-woostack/**
tags: skills, docs, counts, surface
hook: Adding/removing a public command means updating the count + lists in five places, which drift independently.
updated: 2026-06-05
source: .woostack/plans/2026-06-05-woostack-plan.md
recall_count: 17
last_recalled: 2026-06-06
---
The public-command count and skill lists are duplicated across several files and
drift independently (the `woostack-harden` internal-sub-skill mention in README
was stale by one when `woostack-execute` landed). When the surface changes, update
every site in lockstep:

- **AGENTS.md** (= `.claude/CLAUDE.md` symlink): the "N skills" count, the bulleted
  public list, the "N-skill command surface" phrase, the "do not rename M `SKILL.md`
  files (N public + 2 internal)" hard constraint, the Quick file map entry, and the
  Mode B trigger list.
- **README.md**: the install-paragraph "N skills" count + list, the build-loop prose,
  and (for a command) its own `### /woostack-…` section + any affected step numbers.
- **skills/using-woostack/SKILL.md**: the Command Routing row.
- **CONTRIBUTING.md**: the public-surface list in the intro paragraph **and** the
  "Change the …" pointer-table row (two sub-sites in one file).
- **skills/woostack-bootstrap/references/development.md**: the loop-summary row (often
  already generic — verify, frequently a no-op; inspection commands like `woostack-status`
  are not loop phases, so this stays a no-op for them).

Internal sub-skills (ideate, harden) count toward `SKILL.md` files but NOT the public
surface. As of woostack-debug the surface is **twelve public commands + two internal
sub-skills = fourteen `SKILL.md` files** (`woostack-debug` is a public command; it is also an
internal hook invoked by execute/review, but still counts once as a public command). See
[[woostack-feature-state-invariant]].
