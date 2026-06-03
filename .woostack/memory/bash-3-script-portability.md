---
name: bash-3-script-portability
type: convention
scope: skills/**/*.sh
hook: Repo shell scripts must stay compatible with macOS Bash 3 and avoid Linux-only utilities.
updated: 2026-06-03
source: .woostack/plans/2026-06-03-bounded-review-swarms.md
---
Repo shell scripts must stay compatible with macOS Bash 3: avoid `mapfile`, nameref locals, and Linux-only helpers like `flock`; prefer portable read loops and `mkdir` locks.
