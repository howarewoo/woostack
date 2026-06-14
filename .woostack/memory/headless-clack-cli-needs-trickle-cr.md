---
name: headless-clack-cli-needs-trickle-cr
type: gotcha
scope: site/**, skills/woostack-bootstrap/**
tags: scaffolding, clack, create-fumadocs-app, headless, tty
hook: Drive an interactive clack `create-*` CLI headlessly by trickle-feeding CR (`\r`) into its stdin pipe with delays — not piped `\n`, not expect text-matching.
updated: 2026-06-12
source: [[plans/2026-06-12-fumadocs-docs-site]]
---
`create-fumadocs-app` (and other `@clack/prompts`-based `create-*` CLIs) resist headless
runs. What fails and why:

- **Piped `\n`** — newline is read as a toggle/redraw, never as submit; the option just
  flips and EOF cancels the prompt.
- **`< /dev/null`** — EOF at the first prompt → immediate cancel, no scaffold.
- **`yes "" | …`** — floods toggles and wedges (saw 100% CPU, no output).
- **`expect` text-matching** (`-re {Use \`/src\`}`) — under a PTY clack redraws
  char-by-char with ANSI cursor moves, so the prompt text never appears as a contiguous
  substring; the pattern never matches, nothing is sent.

What works: **trickle-feed carriage returns into the stdin pipe with delays**, after an
initial sleep to clear the npx spinner — e.g.
`( sleep 6; for i in $(seq 8); do printf '\r'; sleep 2.5; done ) | npx -y create-fumadocs-app@latest site --template '+next+fuma-docs-mdx' --pm pnpm --install --no-git`.
A *piped* (non-TTY) clack renders each prompt in one clean write, and `\r` (Enter, char 13 —
**not** `\n`) submits; spacing the writes lets each prompt render before the next CR lands,
defeating the all-bytes-at-once race. Pass every deterministic choice as a flag
(`--template --pm --install --no-git`) so only unflagged prompts (src dir, linter, search,
og, ai) remain for the CR stream to accept-default.
