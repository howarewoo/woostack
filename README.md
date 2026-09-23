# woostack

woostack is a collection of skills that teach AI coding assistants how to plan work and
change code. You make the product decisions. The assistant checks the repository and GitHub
before reporting what changed or what is ready for review.

Use one PR for a small change or a well-understood fix. For larger work, woostack saves a
specification and step-by-step plan so you can resume later. Changes still need verification and
independent review, whether the assistant works alone or delegates parts to other agents.

Start with the [getting-started guide](site/content/docs/getting-started.mdx), or use the
[command index](skills/using-woostack/SKILL.md#command-routing) to choose a workflow.


## Getting started

### 1. Install the skills

Run this in your terminal to install the collection for your coding assistant:

```bash
pnpx skills add howarewoo/woostack
```


The public commands are listed in [AGENTS.md](AGENTS.md#what-this-repo-is), including the directly
callable Ideate and Harden planning phases.

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
Init does not create a parallel project agent catalog. It also attempts read-only Linear setup when
the host provides the official Linear integration. Missing provider access does not block local setup.
Init does not create remote issues or projects. See [Init](skills/woostack-init/SKILL.md) for details.

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


### 5. Choose where to keep plans

Build and larger Fix workflows save specifications, plans, and resume state in
`.woostack/tmp/runs/<run-id>/`. These local files are the primary records. You can configure
Linear, Plane, or GitHub to keep remote copies. Bounded Execute work does not contact these
planning providers unless an exact issue association or requested provider operation is selected.
The optional exact GitHub issue association is a read-only exception through host-authenticated
`gh`; it does not create a planning-provider mirror.
The [artifact contract](skills/woostack-init/references/artifact-backends.md) explains storage,
synchronization, and recovery. Saved plans and remote copies record your decisions; they do not
authorize new work or prove that code was delivered.

If you use Hermes to coordinate an OMP session, follow the
[Hermes guide](site/content/docs/hermes.mdx). Install woostack in OMP or another supported coding
assistant, not in Hermes. Hermes can relay decisions and review evidence; implementation stays
in the coding assistant.

## Choose a development workflow

| What you need | Command | What happens |
| --- | --- | --- |
| A new application | [/woostack-bootstrap](skills/woostack-bootstrap/SKILL.md) | Checks the target directory, asks you to approve the design, then creates the project. |
| Elicit a complete specification | [/woostack-ideate](skills/woostack-ideate/SKILL.md) | Takes a goal or existing specification, asks only for missing user-owned decisions, and returns complete plain content. |
| Reconcile a specification or candidate issue plan | [/woostack-harden](skills/woostack-harden/SKILL.md) | Checks supplied content against bounded repository/evidence identity and returns complete reconciled content after explicit corrections. |
| Publish an approved issue plan | [/woostack-plan](skills/woostack-plan/SKILL.md) | Turns an approved specification into reviewable increments under its provider contract without implementing them. |
| A feature that needs several PRs | [/woostack-build](skills/woostack-build/SKILL.md) | Composes the public phases, saves a specification and plan, then retains the artifacts for you to select one bounded task for Execute. |
| A bug fix | [/woostack-fix](skills/woostack-fix/SKILL.md) | Proves the cause and asks you to approve the correction before delivering a small fix or planning larger work. |
| A bounded enhancement, refactor, test-only task, or authorized understood correction | [/woostack-execute](skills/woostack-execute/SKILL.md) | Accepts one complete bounded task, verifies it, and delivers one PR without planning-provider calls. |
| Execute an approved GitHub issue graph | [/woostack-orchestrate](skills/woostack-orchestrate/SKILL.md) | Takes one exact parent issue, explicit Project, or explicit issue list, runs ready tasks in isolated Execute workers, and verifies submitted draft PRs without merging. |

Fix does not contact a planning provider during diagnosis. Configuring a provider does not make
every fix a project. Selecting a project, provider work item, or saved run explicitly uses the
project-backed route.

See the [workflow maps](site/content/docs/concepts/workflows.mdx) for the full sequences.

## Review and check your work

| What you need | Tool |
| --- | --- |
| Review a pull request | [Pullfrog](https://pullfrog.com/) |
| Investigate and address every unresolved review thread | [/woostack-address-comments](skills/woostack-address-comments/SKILL.md) |
| Explore a running web app and reproduce browser bugs | [/woostack-qa](skills/woostack-qa/SKILL.md) |
| Investigate and fix a production error | [/woostack-fix](skills/woostack-fix/SKILL.md) |
| Compare skill behavior against an approved set of evaluation cases | [/woostack-eval](skills/woostack-eval/SKILL.md) |
| Find concrete improvements to instructions from this conversation | [/woostack-reflect](skills/woostack-reflect/SKILL.md) |

Pullfrog handles pull-request review. Address-comments can resolve the resulting GitHub threads;
QA and Eval remain report-only and do not fix source or post findings.

Reports help you decide what to do next. They do not expand the agreed scope or replace
Git/GitHub evidence. Agents never merge PRs; merging is a human decision.

## Contributing

Open a PR to improve a skill, correct guidance, or document a known problem. Read
[CONTRIBUTING.md](CONTRIBUTING.md) for the editing workflow and [AGENTS.md](AGENTS.md) for repository rules.

## Spec version

`2.0.0`

## License

[MIT](LICENSE) &copy; Adam Woo
