# Research basis

Terminal and interaction sources checked 2026-11-16. Read the relevant source when implementing toolkit behavior and verify APIs against the project's installed version. The workflow and its guidance are bundled for offline use.

## Terminal-specific guidance

| Source | Supported practice |
| --- | --- |
| [Ratatui List](https://docs.rs/ratatui/latest/ratatui/widgets/struct.List.html) | Reserve highlight-symbol space to prevent content shifts. `HighlightSpacing::Always` is explicitly recommended. Multiline list items and repeated highlight markers are supported. Framework "selection" may mean the cursor; model product choices separately. |
| [Textual OptionList](https://textual.textualize.io/widgets/option_list/) | Options, separators, disabled options, and highlighted options have distinct representations. Highlight and selection events are separate. Arrows navigate; Enter selects; paging and first/last navigation are available. |
| [Textual Footer](https://textual.textualize.io/widgets/footer/) | Contextual help can display the available bindings of the focused widget. Derive displayed commands from the same bindings that handle input. |
| [Textual input](https://textual.textualize.io/guide/input/) | Focus determines which widget receives input; focus management and bindings are explicit. A read-only log viewer can have input focus. |
| [Ratatui layout](https://ratatui.rs/concepts/layout/) | Layout is expressed in terminal cells and constraints. Fixed, minimum, maximum, proportional, and flexible sizes behave differently; plan for insufficient space. |
| [Charm ANSI utilities](https://pkg.go.dev/github.com/charmbracelet/x/ansi) | Width, wrapping, and truncation helpers account for ANSI sequences and terminal-cell widths, including grapheme clusters. Use equivalent helpers in the chosen framework. |
| [Charm Bubbles List](https://pkg.go.dev/github.com/charmbracelet/bubbles/list) | Bindings differ between normal browsing and filtering. Ordinary Quit is not handled during filtering. Scope printable shortcuts to the current mode. |
| [NO_COLOR convention](https://no-color.org/) | A nonempty variable suppresses default ANSI color; explicit user configuration can override it. It does not mean disabling all ANSI controls, bold, underline, or italic. |
| [Textual testing](https://textual.textualize.io/guide/testing/) and [Ratatui snapshots](https://ratatui.rs/recipes/testing/snapshots/) | Exercise keypresses and terminal sizes as well as inspecting rendered output. Rendering snapshots alone do not validate a running application's event loop or terminal lifecycle. |

## General interaction guidance adapted to terminals

| Source | Supported practice and boundary |
| --- | --- |
| [W3C APG keyboard interface](https://www.w3.org/WAI/ARIA/apg/practices/keyboard-interface/) | Visible focus, distinction between focus and selection, predictable order, and movement between/within components. These are web-widget conventions adapted to TUIs; ARIA attributes do not create terminal accessibility. |
| [W3C Info and Relationships](https://www.w3.org/WAI/WCAG22/Understanding/info-and-relationships.html) | Headings, indentation, grouping, and explicit text convey relationships. Preserve those relationships when presentation changes. This is web guidance, not a terminal-spacing specification. |
| [GOV.UK button guidance](https://design-system.service.gov.uk/components/button/) | Button labels describe the action performed. Apply that principle to terminal actions while retaining noun labels for destinations. |
| [Command Line Interface Guidelines](https://clig.dev/) | Human-oriented wording, discoverable help, restrained color, noninteractive behavior, progress, and escape routes. The guide explicitly excludes full-screen terminal programs; use its general terminal advice, not as a complete TUI specification. |

## Design synthesis

The fixed marker gutter has direct framework support. One blank row between multiline menu items, subordinate description indentation, named status regions, and the monochrome role-identification check are this skill's design recommendations synthesized for ambiguous terminal layouts. Adapt density to the task while preserving clear ownership and navigation. Do not present those defaults as universal standards or as proof of screen-reader accessibility.
