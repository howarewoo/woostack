---
name: status-html-board
type: spec
status: approved
date: 2026-07-03
branch: feature/status-html-board
links:
---

# HTML board render for woostack-status — Design Spec

> Visualize on demand: render this file with [spec-template.html](../../skills/woostack-build/references/spec-template.html) for a rich view. Markdown is the source of truth; the HTML is a presentation target only.

> `status:` is the build-loop phase enum: `draft → hardened → approved → planning → ready → executing → in-review → done` (plus the terminal `abandoned`). The build loop authors each transition and `/woostack-status` reads it; the enum and join contracts are defined once in [conventions.md](../../skills/woostack-status/references/conventions.md).

> **Plan:** [[plans/2026-07-03-status-html-board]]

## 1. Problem

`/woostack-status` renders the feature board only as a fixed-width terminal table
(`skills/woostack-status/scripts/status.sh`). On real projects the table is hard to read:
long spec names and NEXT actions wrap, the increments cell truncates awkwardly, phase and
drift flags carry no visual weight, and there is no way to scan plan progress at a glance.
The skill collection already has an HTML presentation convention
(`woostack-visualize` writes self-contained HTML to `.woostack/visuals/`;
`woostack-build` ships `spec-template.html`), but the board — the artifact read most often —
has no rich render.

## 2. Goal

Every `/woostack-status` run additionally writes a self-contained HTML board to
`.woostack/visuals/status-board.html` and opens it in the default browser, rendered
deterministically by the bundled script (no agent in the loop), while the terminal table,
flags, narration, and CI behavior stay exactly as they are.

## 3. Non-goals

- No change to board *derivation* — phases, joins, flags, next actions, and the
  `spec : plan : PRs = 1 : 1 : N` contract are untouched.
- No agent-rendered or per-run-styled HTML — that remains `woostack-visualize`'s job.
- No tracked snapshot: the HTML lives only in the gitignored `.woostack/visuals/`; the
  "never commit a status file" rule stands.
- No interactivity beyond native HTML (`<details>` collapse); no JS frameworks, no CDN
  assets, no network access from the page.
- No HTML rendering of the deferral scan (SKILL.md step 4) — that is agent-side grep, not
  script data; it stays terminal-only.
- No new public command; `/woostack-status` keeps its name and routing.

## 4. Approach

Script-native rendering, chosen over delegating to `woostack-visualize` (agent-rendered:
slow, token-costly, non-deterministic) and over a `--json` + agent-fills-template hybrid
(two formats to maintain, still agent-in-the-loop):

- Ship `skills/woostack-status/scripts/board-template.html` — one self-contained template
  (inline CSS only, no CDN, offline-viewable, light/dark via `prefers-color-scheme`) with
  HTML-comment placeholders: `<!--WOO_ROWS-->`, `<!--WOO_FLAGS-->`, `<!--WOO_FOOTER-->`,
  `<!--WOO_GENERATED-->`.
- Extend `status.sh`: the existing per-spec loop accumulates an HTML row string alongside
  the current text row; after the terminal print, a `render_html()` function substitutes the
  placeholders (awk, no new dependencies) and writes
  `$WOO_DIR/visuals/status-board.html`, overwriting each run (the board is computed fresh
  each run; snapshot semantics preserved).
- Open the file with `open` (darwin) or `xdg-open` (linux). Suppress opening — but still
  write the file — when `--no-open` is passed or `WOO_STATUS_NO_OPEN=1`; suppress
  automatically when `CI` or `GITHUB_ACTIONS` is set or no opener exists.
- Flags: `--no-open` added; `--all` and `--fetch` unchanged (`--all` continues to gate the
  *terminal* expansion only — the HTML always carries done/abandoned in a collapsed section).

## 5. Components & data flow

- `scripts/board-template.html` (new, bundled asset): page shell, styles, placeholders.
  Content per row: spec name, phase as a color-coded badge (one color per enum value plus
  `unknown`), plan progress as a bar + `N/M` label, increments cell with per-PR
  state chips, owner, age, next action. Flags render as a warning-styled block; footer
  carries done/abandoned counts and the gh/fetch degradation notes; done/abandoned rows
  live in a collapsed `<details>` (no `--all` needed in HTML). A generated-at timestamp
  and project root path render in the header.
- `scripts/status.sh` (modified):
  - arg parse gains `--no-open`;
  - per-spec loop appends to `html_rows` (and `html_hidden_rows` for done/abandoned)
    mirroring the fields already computed for the text row — one derivation, two renders;
  - `html_escape()` applied to every interpolated field (`& < > "` — names, branches,
    owners, next actions come from frontmatter/gh and are untrusted);
  - `render_html()` reads the template from `$HERE/board-template.html`, substitutes
    placeholders, writes `$WOO_DIR/visuals/status-board.html` (`mkdir -p` first);
  - `maybe_open()` applies the suppression rules above.
- `skills/woostack-status/SKILL.md` (modified): Commands section documents `--no-open`;
  Procedure step 1 notes the HTML board is written and opened alongside the terminal table;
  Hard constraint "No committed status file" reworded to "never write `STATUS.md` or any
  *tracked* snapshot; the gitignored `.woostack/visuals/status-board.html` render is the
  sanctioned exception."
- `site/content/docs/concepts.mdx` (modified, one line): the authored claim "`status.sh`
  reads the specs, plans, and PR state and prints the feature board" gains "and writes a
  gitignored HTML render of it" — the docs-site sync rule and the lockstep-edit-sites
  wisdom both require the authored page to move with the behavior.
- No change to `references/conventions.md`, `lib.sh`, or any other skill.

Data flow: frontmatter/plans/gh → existing derivation loop → (a) terminal table (unchanged)
and (b) escaped HTML rows → template substitution → `.woostack/visuals/status-board.html` →
opener.

## 6. Error handling

Per the skill's standing "degrade, never hard-fail" constraint:

- `mkdir -p`/write of `visuals/` fails → print a one-line notice, skip HTML, exit 0;
  terminal board already printed.
- Template file missing from the bundle (broken install) → same: notice, skip HTML, exit 0.
- No opener (`open`/`xdg-open` absent) or opener fails → file still written; notice with
  the file path so the user can open it manually; exit 0.
- `CI`/`GITHUB_ACTIONS` set → write file, never attempt to open (headless).
- bash 3.2 (macOS default) compatibility: guard any new empty-array expansion with
  `${arr[@]+"${arr[@]}"}`; no bash-4-only features.
- Field values containing `& < > "` or backslashes/awk metacharacters render literally
  (escaped), never as markup or substitution artifacts.

## 7. Acceptance criteria

Each AC is a testable behavior → ≥1 plan task.

> **Angle pre-flight.** Security → AC3 (HTML injection via frontmatter). Edge/error → AC4,
> AC5. Observability → the degradation notices in §6. API and database — N/A, none
> implicated.

- **AC1 — HTML board is written on every run**
  - happy: running `status.sh` against a fixture `.woostack` (with `WOO_STATUS_NO_OPEN=1`)
    writes `visuals/status-board.html` containing one row per in-flight spec/fix with the
    same phase, plan `N/M`, and next action as the terminal table, plus done/abandoned rows
    inside a `<details>` section.
  - error: `visuals/` uncreatable (e.g. a file squats on the path) → terminal board prints,
    a notice names the failure, exit code 0, no HTML file.
  - edge: zero specs/fixes → current early-exit message unchanged; no HTML written.
- **AC2 — terminal output is unchanged (assertion-level)**
  - happy: every existing `test-status.sh` assertion passes untouched; for the same fixture
    the table header, each row's phase/plan/next cells, and the flags block are unchanged —
    the only addition is one footer line naming the written HTML path (assertion-style
    checks matching the existing harness; no golden files).
  - error: N/A — covered by AC1 error.
  - edge: `--all` still expands done/abandoned in the terminal only; HTML content is
    identical with and without `--all`.
- **AC3 — interpolated fields are HTML-escaped**
  - happy: a fixture spec named `a<b>&"c"` renders literally in the page; no unescaped
    `<` from any interpolated field outside the template's own markup.
  - error: N/A — escaping is unconditional.
  - edge: awk/backslash metacharacters (`\`, `&`) in a NEXT action survive substitution
    literally.
- **AC4 — opening is correctly suppressed**
  - happy: default local run invokes the platform opener with the file path exactly once
    (asserted via a stub opener on `PATH`).
  - error: opener missing/failing → notice with file path, exit 0.
  - edge: each of `--no-open`, `WOO_STATUS_NO_OPEN=1`, `CI=1`, `GITHUB_ACTIONS=true`
    suppresses the opener while the file is still written.
- **AC5 — degraded gh renders in HTML too**
  - happy: with `WOOSTACK_GH` pointing at a missing binary, the HTML board renders rows
    without PR/owner data and the footer carries the gh notice, matching the terminal.
  - error: N/A — this is the error path.
  - edge: `--fetch` note appears in the HTML footer only when `--fetch` was not passed,
    mirroring the terminal.

## 8. Testing

Existing harness: `skills/woostack-status/scripts/tests/` (bash tests, auto-discovered).
Add `test-html-board.sh` driving `status.sh` against the existing fixture pattern with
`WOO_DIR` overridden and `WOO_STATUS_NO_OPEN=1`; a stub `open`/`xdg-open` on `PATH`
asserts opener behavior (AC4). Assertions are grep-based on the written HTML (AC1, AC3,
AC5) and `assert_contains`/`assert_not_contains` on stdout for AC2, matching the existing
harness style (no golden files). No browser, no network, CI-safe (suppression rules make
the test hermetic).

## 9. Open questions

None — resolved during ideation: script-native rendering (not visualize/hybrid); default
open with `--no-open` + env/CI suppression; HTML always includes collapsed done/abandoned;
deferrals stay terminal-only.
