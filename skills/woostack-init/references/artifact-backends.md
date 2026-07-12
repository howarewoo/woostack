# Artifact backend configuration

`artifacts.specPlan` accepts `markdown` (the default) or the reserved `linear` selector.
Markdown reads tracked `.woostack/specs/*.md` and `.woostack/plans/*.md` files. The
`linear` selector currently validates configuration only; later stacked increments add
Linear project and issue persistence before workflows consume it.

A Linear configuration accepts only these keys:

- `linear.workspace`
- `linear.team`
- optional `linear.repository` (`owner/repository`); when omitted, the resolver derives it
  from a GitHub `origin`
- every `linear.projectStatuses` mapping: `draft`, `hardened`, `approved`, `planning`,
  `ready`, `executing`, `inReview`, `done`, and `abandoned`
- every `linear.issueStates` mapping: `planned`, `executing`, `inReview`, `done`, and
  `blocked`

Every value must be a non-empty string. Unknown keys fail closed. The `linear` namespace
must not contain credentials at any depth: keep API keys, tokens, authorization headers,
passwords, private or access keys, client secrets, credential files, and provider
authentication in the host's native secret store.
