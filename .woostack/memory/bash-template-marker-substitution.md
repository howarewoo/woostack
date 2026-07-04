---
name: bash-template-marker-substitution
type: pattern
scope: skills/**/scripts/**
tags: templating, awk, gsub, escaping, html, injection, bash-3.2
hook: Populate a bundled text/HTML template from bash with awk index()+printf ENVIRON on whole marker lines — never gsub, never sed, never inline expansion.
updated: 2026-07-03
source: [[plans/2026-07-03-status-html-board]]
---

When a bundled script must populate a text/HTML template with derived multi-line content
(woostack-status fills `board-template.html` markers like `<!--WOO_ROWS-->`), the safe shape is:

- Put each marker **on its own line** in the template.
- Pass each block to awk **via the environment** (`VAR="$content" awk '... ENVIRON["VAR"] ...'`),
  not as an awk `-v` var (`-v` mangles backslash escapes) and not interpolated into the awk
  program text (quote/injection hazard).
- Replace with `index($0, "<marker>") { printf "%s", ENVIRON["VAR"]; next }` — **never `gsub`**:
  gsub's replacement string treats `&` and `\` specially, so any field containing them (branch
  names, PR titles, next-action text) corrupts the output. `index()`+`printf` is literal-safe.
- Escape every interpolated field first with a bash-3.2-safe `${var//}` chain
  (`& < > "` → entities) so untrusted frontmatter/gh values cannot inject markup; leave raw only
  values constrained to a script-owned enum (e.g. a phase gated by `VALID_PHASES`).
- Known scaling boundary: environment size (`E2BIG`) caps very large blocks — keep the
  degrade-with-notice path (`|| { note; return 1; }`) so an oversized board renders a notice,
  never a crash.

An empty ENVIRON value simply deletes the marker line — pre-initializing accumulators to `""`
under `set -u` is required and sufficient.
