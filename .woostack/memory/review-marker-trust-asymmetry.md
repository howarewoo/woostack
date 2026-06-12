---
name: review-marker-trust-asymmetry
type: gotcha
scope: skills/woostack-review/scripts/**
tags: prefetch, incremental, marker, watermark, trust, forge, local, ci, skills-repo
hook: the incremental SHA watermark is WRITTEN in CI and local runs alike, but its read-side trust gate was bot-author-only (CI-shaped) — so a local re-review never trusted the marker it wrote; widen to bot OR (local-run AND author==self), gated on not-in-CI to keep forge-safety.
updated: 2026-06-11
source: .woostack/fixes/2026-06-11-review-marker-self-trust.md
---
`_header.md` embeds `<!-- woostack-review:sha=<HEAD_SHA> -->` in **every** posted
review body — CI *and* local. But the read side in `prefetch.sh` trusted a marker
only when its author matched `BOT_NAME_PATTERN` (`claude|openai|gemini|opencode`).
A local review is authored by the human's own `gh` login, so it failed the bot
filter → `LAST_SHA=""` → `Marker: none` → full re-review every time (issue #273).

**The asymmetry:** a value written in *both* CI and local contexts whose trust gate
is shaped for *only one* context (here CI's anti-forge bot gate) is silently unusable
in the other. Before trusting a marker/token, ask "who can author this, and in which
context?" — match the gate to every context that writes it.

**Fix shape** — widen trust to **bot-authored OR (local-run AND author==self)**, and
gate the self-trust clause on **not-in-CI** (`GITHUB_ACTIONS != "true"`):
- The bot gate exists because in CI any PR collaborator could post a review with a
  forged `sha=` marker pointing *past* their own malicious commits, narrowing the
  next incremental window to skip them. That forge threat is CI-only — locally the
  user reviews as themselves with their own token, so trusting a marker authored *as
  themselves* introduces no new forger.
- CI stays provably unchanged: when `GITHUB_ACTIONS=true`, the local flag is `0`, the
  self-clause is dead, and `AUTH_LOGIN` (`gh api user`) is not even fetched.
- A *different* local reviewer (login mismatch) or any CI third-party still falls back
  to a full pass; `--full` / `incremental: off` escape hatches are untouched.

Mechanics: the marker-trust filter was extracted into a single-authority
`resolve-marker.sh` (reviews JSON on stdin; args `bot-pattern me local`) so the unit
test and the production filter cannot drift — the same idiom as `resolve-root.sh` /
`resolve-model.sh`. Match login comparison case-insensitively (lowercase both sides;
GitHub logins are case-insensitive) and keep the legacy `woo-?stack` read alias.
See [[review-skip-markdown-only-pr]] for the sibling prefetch false-negative class.
