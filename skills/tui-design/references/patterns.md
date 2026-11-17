# TUI patterns

Use these as adaptable examples, not mandatory chrome or a universal keymap. The blank-row and gutter dimensions are this skill's practical defaults, not measurements mandated by a standard.

## 1. Actions with supporting descriptions

Ambiguous terminal output:

```text
> Connection
Offline
  Profile
Default
  Logs
Last sync failed
```

The same alignment mixes action labels, values, and global status. It is unclear whether Enter edits, reconnects, opens details, or selects a setting.

A clearer terminal frame:

```text
Connection settings

Actions
> Edit connection
    Change the server address and credentials.

  Choose profile
    Current profile: Personal

  View connection logs
    Inspect recent connection attempts.

Connection status
  State: offline
  Last attempt: failed; server did not respond

Up/Down Move   Enter Edit connection
Esc Back      ? Help
```

Only the three action blocks belong to this menu's navigation sequence. The two-column gutter is reserved even on unfocused items. Descriptions remain within their owning block and never receive an independent cursor. The legend changes to `Enter Choose profile` or `Enter View logs` with focus. Global status is outside the actions region.

## 2. Focus and chosen values

For a single-choice picker with explicit confirmation:

```text
Choose profile

  ( ) Work
> (o) Personal   (current)
  ( ) Travel

Up/Down Move   Space Choose   Enter Apply
Esc Cancel
```

Here `>` means focus, `(o)` means the pending choice, and `(current)` means the saved value. After choosing Work, `(o)` moves to Work while `(current)` stays on Personal until Apply. Escape discards the pending choice. In an immediate-apply picker, simplify the state model and label the activation `Use profile`; do not invent a staging step the product does not need.

For multiple choices, use `[ ]` / `[x]`. Arrow movement must preserve checked items. Never reuse a checkmark to mean both "has focus" and "enabled".

## 3. Dense lists and limited height

A compact list can keep adjacent single-line rows when the structure is explicit:

```text
Jobs  2 of 143
  Name               Status
  Daily backup       Complete
> Photo index        Running
  Weekly report      Queued

Up/Down Move   Enter Open details
PgUp/PgDn Page   q Quit   ? Help
```

The header is not a job or a focus stop. Status belongs to its row; Enter opens the job named on that row. `2 of 143` shows the focus position. In browsing mode `q` quits; in a filter field it types the letter q. Show the actual mode's bindings.

At reduced height, remove optional inline descriptions or use a separate details screen while preserving identifying labels, focus, and help. At reduced width, collapse secondary columns or panes and expose the missing values in details. If names become indistinguishable after truncation, preserve a unique suffix/identifier or provide an immediate full-name view. Explain and offer exit below the minimum supported size.
