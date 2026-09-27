# woostack

woostack is a collection of skills that teach AI coding assistants how to plan work and
change code. You make the product decisions. The assistant checks the repository and GitHub
before reporting what changed or what is ready for review.

Use one PR for a small change or a well-understood fix. For larger work, Plan can inspect
the repository and return a coherent plan without writing to GitHub, or publish requested
issues with verified dependencies. Verify changes; delegate or request independent review when
required, requested, or warranted by risk.

Start with the [getting-started guide](site/content/docs/getting-started.mdx), or use the
[command index](skills/using-woostack/SKILL.md#command-routing) to choose a workflow.


## Getting started

### 1. Install the skills

Run this in your terminal to install the collection for your coding assistant:

```bash
pnpx skills add howarewoo/woostack
```


The public commands are listed in the
[command index](skills/using-woostack/SKILL.md#command-routing), including standalone
Ideate, Harden, and Plan.

For frontend work, you can also install [impeccable](https://github.com/pbakaus/impeccable).
woostack recommends it for design reviews:

```bash
pnpx skills add pbakaus/impeccable
```

Claude Code users can alternatively run `/plugin marketplace add pbakaus/impeccable`.

### 2. Set up your project

Open your coding assistant in the project root and enter:

```text
/woostack-init
```

Init creates `.woostack/` configuration and diagnostic folders, worktree support, and the local
OMP session-naming extension. OMP delegation uses agents already exposed by the active session;
Init does not create a parallel project agent catalog. It may use authorized native GitHub
capabilities or host-authenticated `gh` for narrow read-only discovery when an explicit GitHub
operation needs it. Missing GitHub configuration or capability does not block local setup. Init
does not create remote issues or projects. See [Init](skills/woostack-init/SKILL.md) for details.

### 3. Tell your assistant to use woostack

Add this block to your repository's agent instructions file (`AGENTS.md` or `CLAUDE.md`):

```markdown
This project follows woostack. At the start of work, use `using-woostack` to load the
project rules and route `/woostack-*` requests to the matching woostack skill.
```

The [using-woostack](skills/using-woostack/SKILL.md) skill reads your project rules and chooses the
matching installed workflow.

### 4. Configure project defaults

Store non-secret settings in `.woostack/config.json`. Keep credentials in your host's secret store.
Configuration supplies defaults; it does not give the assistant permission to change remote records
or override your decisions.

For pull-request review, use [Pullfrog](https://pullfrog.com/). This repository includes the
Pullfrog workflow at [`.github/workflows/pullfrog.yml`](.github/workflows/pullfrog.yml).

For the full policy surface, see the authored
[configuration reference](site/content/docs/configuration/index.mdx).


Plan handles a goal or incomplete issue directly. It inspects relevant source, asks about
material unresolved choices, and publishes issues only when requested. Ideate remains available
for requirements exploration, Harden for read-only review, and Debug for diagnosis; none is a
mandatory Plan handoff. An explicit GitHub Project is optional. Existing
`.woostack/tmp/runs/<run-id>/` records remain historical user data and are never migrated or
mutated; retained drafts are evidence, not publication or implementation authority.

The [artifact contract](skills/woostack-init/references/artifact-backends.md) explains direct
GitHub publication, recovery, and retained historical record handling. Saved plans and remote
records record decisions; they do not authorize new work or prove that code was delivered.

If you use Hermes to coordinate an OMP session, follow the
[Hermes guide](site/content/docs/hermes.mdx). Install woostack in a compatible coding
assistant, not in Hermes. Hermes can relay decisions and review evidence; implementation stays
in the coding assistant.

## Choose a development workflow

To plan in a normal ChatGPT chat, start with the
[ChatGPT-to-Codex guide](site/content/docs/chatgpt-to-codex.mdx). In a coding host, Plan can
return a plan without publication, or file issues on request using authorized GitHub access.
Native links are verified when requested and available; missing relationships are reported,
not invented. Execution is a separate request to Orchestrate for multiple tasks or Execute
for one bounded task.

| What you need | Command | What happens |
| --- | --- | --- |
| A new application | [/woostack-bootstrap](skills/woostack-bootstrap/SKILL.md) | Checks the target directory, asks you to approve the design, then creates the project. |
| Explore requirements | [/woostack-ideate](skills/woostack-ideate/SKILL.md) | Asks about unresolved product decisions and returns a readable specification. |
| Review a specification or plan | [/woostack-harden](skills/woostack-harden/SKILL.md) | Checks selected content against relevant repository evidence without writes. |
| Plan work or file issues | [/woostack-plan](skills/woostack-plan/SKILL.md) | Plans directly from a goal or issue; publishes and reads back issues only when requested. |
| A bounded task that fits one PR | [/woostack-execute](skills/woostack-execute/SKILL.md) | Implements a complete approved task, including an enhancement, refactor, test-only task, or authorized understood correction, and delivers one PR. |
| Coordinate multiple approved tasks | [/woostack-orchestrate](skills/woostack-orchestrate/SKILL.md) | Resolves tasks and dependencies from prose, issues, or an explicitly selected Project; coordinates inline or native-host workers in isolated workspaces and verifies draft PRs without merging. |

Plan stops before implementation. A separate Execute or Orchestrate request starts delivery.

See the [workflow maps](site/content/docs/concepts/workflows.mdx) for the full sequences.

## Review and check your work

| What you need | Tool |
| --- | --- |
| Investigate and address every unresolved review thread | [/woostack-address-comments](skills/woostack-address-comments/SKILL.md) |
| Explore a running web app and reproduce browser bugs | [/woostack-qa](skills/woostack-qa/SKILL.md) |
| Prove a root cause without implementing a correction | [/woostack-debug](skills/woostack-debug/SKILL.md) |
| Plan a proved defect as issues | [/woostack-plan](skills/woostack-plan/SKILL.md) |
| Find concrete improvements to instructions from this conversation | [/woostack-reflect](skills/woostack-reflect/SKILL.md) |

Pullfrog handles pull-request review. Address-comments can resolve the resulting GitHub threads;
QA remains report-only and does not fix source or post findings.

Reports help you decide what to do next. They do not expand the agreed scope or replace
Git/GitHub evidence. Agents never merge PRs; merging is a human decision.

## Contributing

Open a PR to improve a skill, correct guidance, or document a known problem. Read
[CONTRIBUTING.md](CONTRIBUTING.md) for the editing workflow and [AGENTS.md](AGENTS.md) for repository rules.

## Spec version

`2.0.0`

## License

[MIT](LICENSE) &copy; Adam Woo
