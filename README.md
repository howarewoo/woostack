# woostack

woostack is a collection of skills that teach AI coding assistants how to plan work and
change code. You make the product decisions. The assistant checks the repository and GitHub
before reporting what changed or what is ready for review.

Use one PR for a small change or a well-understood fix. For larger work, settle the specification
and publish a verified GitHub parent with PR-sized native children before requesting execution.
Changes still need verification and independent review.

Start with the [getting-started guide](site/content/docs/getting-started.mdx), or use the
[command index](skills/using-woostack/SKILL.md#command-routing) to choose a workflow.


## Getting started

### 1. Install the skills

Run this in your terminal to install the collection for your coding assistant:

```bash
pnpx skills add howarewoo/woostack
```


The public commands are listed in [AGENTS.md](AGENTS.md#what-this-repo-is), including the directly
callable Ideate, Harden, and planning-only Prepare composition.

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


Prepare is the planning-only entrypoint for features and proved defects. It composes public Ideate,
Harden, Debug, and Plan from complete plain packets and ends at a verified GitHub parent/child
graph; it does not create local run state, a replacement work board, source branches, or
implementation. Plan is the sole GitHub issue publisher. An explicit GitHub Project remains a
direct Plan selector. Existing `.woostack/tmp/runs/<run-id>/` records from retired workflows
remain readable historical user data and are never migrated or mutated. A retained draft may be
supplied explicitly after identity and freshness revalidation, but it never authorizes publication
or code changes.

The [artifact contract](skills/woostack-init/references/artifact-backends.md) explains direct
GitHub publication, recovery, and retained historical record handling. Saved plans and remote
records record decisions; they do not authorize new work or prove that code was delivered.

If you use Hermes to coordinate an OMP session, follow the
[Hermes guide](site/content/docs/hermes.mdx). Install woostack in OMP or another supported coding
assistant, not in Hermes. Hermes can relay decisions and review evidence; implementation stays
in the coding assistant.

## Choose a development workflow

To plan in a normal ChatGPT chat, start with the complete
[ChatGPT-to-Codex prompt](site/content/docs/chatgpt-to-codex.mdx). It requires no installed chat
skills. The default GitHub app is read-only: publication needs actual authorized issue, native
sub-issue, and dependency tools; otherwise keep a planning-only draft or explicitly use Plan in a
coding host. After approved publication, the chat stops. Separately invoke
`/woostack-orchestrate --issue <verified canonical parent URL>` in Codex to execute the children.
No Project is required, and the parent gets no worker or PR. See the guide for dated product/usage
rules, capability gaps, native graph recovery, and join decisions.

| What you need | Command | What happens |
| --- | --- | --- |
| A new application | [/woostack-bootstrap](skills/woostack-bootstrap/SKILL.md) | Checks the target directory, asks you to approve the design, then creates the project. |
| Elicit a complete specification | [/woostack-ideate](skills/woostack-ideate/SKILL.md) | Takes a goal or existing specification, asks only for missing user-owned decisions, and returns complete plain content. |
| Reconcile a specification or candidate issue plan | [/woostack-harden](skills/woostack-harden/SKILL.md) | Checks supplied content against bounded repository/evidence identity and returns complete reconciled content after explicit corrections. |
| Prepare a feature or proved defect for issue planning | [/woostack-prepare](skills/woostack-prepare/SKILL.md) | Composes the relevant public phases and ends at one fully read-back GitHub parent/child graph without implementing or dispatching it. |
| Publish an approved GitHub issue plan | [/woostack-plan](skills/woostack-plan/SKILL.md) | Publishes one verified GitHub parent/child hierarchy or explicit Project graph with native prerequisite edges, without implementing it. |
| A bounded task that fits one PR | [/woostack-execute](skills/woostack-execute/SKILL.md) | Implements a complete approved task, including an enhancement, refactor, test-only task, or authorized understood correction, and delivers one PR. |
| Execute a GitHub issue graph | [/woostack-orchestrate](skills/woostack-orchestrate/SKILL.md) | Takes one exact parent issue, explicit Project, or explicit issue list, runs ready tasks in isolated Execute workers, and verifies submitted draft PRs without merging. |

Prepare stops at planning. Direct bounded implementation remains an explicit Execute request; a
separate `/woostack-orchestrate --issue <verified-parent-url>` is only a suggested next command.

See the [workflow maps](site/content/docs/concepts/workflows.mdx) for the full sequences.

## Review and check your work

| What you need | Tool |
| --- | --- |
| Investigate and address every unresolved review thread | [/woostack-address-comments](skills/woostack-address-comments/SKILL.md) |
| Explore a running web app and reproduce browser bugs | [/woostack-qa](skills/woostack-qa/SKILL.md) |
| Prove a root cause without implementing a correction | [/woostack-debug](skills/woostack-debug/SKILL.md) |
| Prepare a proved defect for issue planning | [/woostack-prepare](skills/woostack-prepare/SKILL.md) |
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
