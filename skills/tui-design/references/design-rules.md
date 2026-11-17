# Terminal design rules

Apply the sections relevant to the requested change. These are adaptable defaults: choose density
and key behavior for the task and existing product, then verify them in the supported terminal.

## Grouping and hierarchy

- Make unfocused controls recognizable through a named options region, consistent control syntax,
  or an action column. The cursor identifies the current target; it must not be the only clue
  that the other rows are actionable.
- Treat a label and description as one navigable item. Put supporting text immediately below
  the label with subordinate indentation; align wrapped continuation lines at that indent.
  Keep spacing within an item smaller than spacing between items or groups.
- Default to one blank row between multiline menu items. Separate unrelated information from
  controls with a blank row and a heading or separator. Never place unrelated status flush beneath
  an action as though it describes that action. These spacing values are heuristics, not standards.
- Keep item metadata with its item, using explicit fields such as `Status: running`. Put global
  status and logs in named regions. Headings, separators, and descriptions are not action stops;
  read-only viewers may receive focus to scroll or copy, with that mode clearly identified.
- Dense single-line tables can use adjacent rows when columns and row focus establish ownership.
  Put optional detail in a preview or details view before squeezing away meaningful separation.
  Use alignment and whitespace before boxes; give borders a purpose such as distinguishing panes.

## Focus, choices, and state

- Reserve a fixed-width focus gutter so labels do not move when the cursor appears. Use `>` for
  focus, `[ ]` / `[x]` for multiple choices, and explicit text such as `(current)` for a saved value.
  Choose one meaning per marker. An inactive pane must not look as though it receives input.
- Keep a multiline item's boundary clear with indentation and, where useful, whole-item emphasis.
  Avoid using dim text, reverse video, red/green, or an icon alone to encode essential state.
- Distinguish pending edits from saved values. Show unsaved changes and what save/cancel does.
  Explain unavailable controls beside the control or in its details; prevent their activation.
- Preserve focus and checked items by identity across filtering and refresh. Do not let status
  changes, reordering, or incoming logs move the active target unexpectedly. Restore focus to the
  originating control after a dialog, or a sensible neighbor if that control disappeared.

## Labels and feedback

- Describe actions with their result and object (`Edit connection`, `Start backup`); use familiar
  nouns for destinations (`Connections`, `Backups`). Write status as a fact (`Connection: offline`).
  Keep terms consistent across controls, help, and results. Avoid `Manage`, `OK`, or `Select` when
  a more informative outcome is known.
- Remove helper text that repeats the label. Keep information that changes a decision, including
  destructive consequences. Use persistent field labels; a placeholder cannot carry the only label.
- Explain errors with the failed operation, known cause, and recovery. Distinguish an empty
  collection from no filter matches or unavailable data. Loading and success messages must reflect
  real state; do not invent progress. Keep long-running work interruptible.
- Name the target and consequence for destructive actions and provide proportionate confirmation
  or undo. Do not add confirmations to ordinary movement or harmless navigation.

## Keyboard behavior

- Prefer Tab / Shift+Tab between regions or form controls, arrows within lists, Enter to open or
  activate, and Space for checkboxes. Preserve established conventions when suitable. Expert keys
  and mouse support supplement a discoverable keyboard path.
- Separate cursor movement, choosing values, and executing actions. Cheap previews or appropriate
  radio-choice changes may follow focus; traversing a menu must not execute commands, save edits,
  or trigger costly work. Do not turn every line into a Tab stop.
- Show a compact contextual legend with outcomes, such as `Enter Open details`, and expanded help.
  Derive hints from enabled bindings when possible. Identify filter/edit modes and let printable
  shortcuts such as `q`, `j`, `k`, `/`, and `?` become text in input fields.
- Give Escape a consistent local back/cancel meaning and explain whether edits or filters persist.
  Keep exit/interrupt discoverable. Choose keys the supported terminals can deliver reliably and
  respect terminal/system shortcuts. Restore terminal state on exit and handled failure.

## Size, rendering, and restrained styling

- Budget header, content, and help/status rows. Keep focus visible, show overflow position, and
  provide scrolling or paging. Collapse secondary panes or show fewer items before hiding
  essential labels or exit controls. Below a usable minimum, explain the size requirement and
  preserve an exit path.
- Measure terminal-cell width with Unicode/ANSI-aware helpers rather than string length. Do not
  split grapheme clusters. Preserve distinguishing identifiers when truncating and expose full
  values in details. Check wide/combining characters and use reliable alternatives for key symbols.
- Build hierarchy with wording, alignment, spacing, markers, and supported emphasis. Reuse semantic
  color roles across states, honor `NO_COLOR` and explicit user overrides, and check light/dark
  themes. Avoid essential dependence on custom fonts, emoji, gradients, or faint colors.
- Use animation only for meaningful activity or state feedback. Prevent flicker and layout shifts;
  let users pause log following without new output moving their reading position.
- For unsupported or noninteractive terminals, provide a plain path or an actionable explanation.
  Screen-reader support depends on the terminal and toolkit; verify the target environment rather
  than treating monochrome output as proof of accessibility.
