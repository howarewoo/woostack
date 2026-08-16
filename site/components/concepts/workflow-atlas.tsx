import Link from 'next/link';

import styles from './workflow-atlas.module.css';

type StepKind = 'work' | 'gate' | 'handoff' | 'terminal';

type WorkflowStep = Readonly<{
  label: string;
  detail?: string;
  kind: StepKind;
}>;

type WorkflowBranch = Readonly<{
  label: string;
  steps: readonly WorkflowStep[];
}>;

type WorkflowId = 'change' | 'fix' | 'build' | 'bootstrap';

type Workflow = Readonly<{
  id: WorkflowId;
  title: string;
  useWhen: string;
  href: string;
  gateCount: number;
  steps: readonly WorkflowStep[];
  branches?: readonly WorkflowBranch[];
}>;

const workflows: readonly Workflow[] = [
  {
    id: 'change',
    title: 'Change',
    useWhen: 'Use for a bounded non-bug enhancement or refactor.',
    href: '/docs/skills/woostack-change',
    gateCount: 0,
    steps: [
      { label: 'Classify scope', kind: 'work' },
      { label: 'Isolate worktree', kind: 'work' },
      { label: 'Implement', kind: 'work' },
      { label: 'Verify and smoke-test', kind: 'work' },
      { label: 'Two-lens inline review', kind: 'work' },
      { label: 'Commit and submit', kind: 'work' },
      { label: 'Verify PR and tear down', kind: 'work' },
      { label: 'One reviewed PR', kind: 'terminal' },
    ],
  },
  {
    id: 'fix',
    title: 'Fix',
    useWhen: 'Use when a bug or regression needs root-cause diagnosis before implementation.',
    href: '/docs/skills/woostack-fix',
    gateCount: 1,
    steps: [
      { label: 'Diagnose root cause', kind: 'work' },
      { label: 'Write combined fix plan', kind: 'work' },
      { label: 'Harden and commit', kind: 'work' },
      { label: 'Approve-to-execute', kind: 'gate' },
    ],
    branches: [
      { label: 'Go', steps: [{ label: 'TDD execute → one reviewed PR', kind: 'terminal' }] },
      { label: 'Hand off', steps: [{ label: 'Approved plan PR with no code', kind: 'terminal' }] },
      { label: 'Revise', steps: [{ label: 'Update and re-present committed plan', kind: 'terminal' }] },
      { label: 'Abandon', steps: [{ label: 'Close/remove temporary artifacts', kind: 'terminal' }] },
    ],
  },
  {
    id: 'build',
    title: 'Build',
    useWhen: 'Use for a feature that needs an approved design, spec, and execution plan.',
    href: '/docs/skills/woostack-build',
    gateCount: 3,
    steps: [
      { label: 'Ideate', kind: 'work' },
      { label: 'Design approval', kind: 'gate' },
      { label: 'Capture and harden spec', kind: 'work' },
      { label: 'Written-spec approval', kind: 'gate' },
      { label: 'Plan, decompose, and harden', kind: 'work' },
      {
        label: 'Prepare backend handoff',
        detail: 'Markdown: spec + plan base PR. Linear: project/issues plus frozen base.',
        kind: 'handoff',
      },
      { label: 'Execution handoff', kind: 'gate' },
    ],
    branches: [
      { label: 'Go', steps: [{ label: 'Reviewed PR stack', kind: 'terminal' }] },
      { label: 'Hand off', steps: [{ label: 'Ready artifacts with no implementation PR', kind: 'terminal' }] },
    ],
  },
  {
    id: 'bootstrap',
    title: 'Bootstrap',
    useWhen: 'Use when starting a new web, mobile, or API project from scratch.',
    href: '/docs/skills/woostack-bootstrap',
    gateCount: 1,
    steps: [
      { label: 'Gather requirements', kind: 'work' },
      { label: 'Live industry research', kind: 'work' },
      { label: 'Compare stack options', kind: 'work' },
      { label: 'Explicit stack choice', kind: 'gate' },
      { label: 'Load reference contracts', kind: 'work' },
      { label: 'Scaffold and clean boilerplate', kind: 'work' },
      { label: 'Verify pipelines and boot surfaces', kind: 'work' },
      { label: 'Bootable project', kind: 'terminal' },
    ],
  },
];

const kindLabels: Readonly<Record<StepKind, string>> = {
  work: 'Work',
  gate: 'Gate',
  handoff: 'Handoff',
  terminal: 'Outcome',
};

export function WorkflowAtlas() {
  return (
    <figure className={styles.atlas} aria-labelledby="workflow-atlas-caption">
      <div className={styles.legend} aria-label="Workflow step legend">
        {(Object.keys(kindLabels) as StepKind[]).map((kind) => (
          <span className={styles.legendItem} data-kind={kind} key={kind}>
            <span className={styles.marker} aria-hidden="true" />
            {kindLabels[kind]}
          </span>
        ))}
      </div>

      <div className={styles.workflows}>
        {workflows.map((workflow) => (
          <section className={styles.workflow} aria-labelledby={`workflow-${workflow.id}`} key={workflow.id}>
            <header className={styles.heading}>
              <div>
                <h3 id={`workflow-${workflow.id}`}>
                  <Link className={styles.skillLink} href={workflow.href}>{workflow.title}</Link>
                </h3>
                <p className={styles.useWhen}>{workflow.useWhen}</p>
              </div>
              <p>{workflow.gateCount === 0 ? 'No approval gate' : `${workflow.gateCount} approval ${workflow.gateCount === 1 ? 'gate' : 'gates'}`}</p>
            </header>

            <ol className={styles.rail} role="list">
              {workflow.steps.map((step) => (
                <li className={styles.step} data-kind={step.kind} key={step.label}>
                  <div className={styles.node}>
                    <span className={styles.kind}>{kindLabels[step.kind]}</span>
                    <span className={styles.label}>{step.label}</span>
                    {step.detail ? <span className={styles.detail}>{step.detail}</span> : null}
                  </div>
                </li>
              ))}
            </ol>

            {workflow.branches ? (
              <div className={styles.branchGroup} data-workflow={workflow.id} aria-labelledby={`${workflow.id}-branches`}>
                <h4 id={`${workflow.id}-branches`}>Branches after {workflow.steps.at(-1)?.label}</h4>
                <ol className={styles.branches} role="list">
                  {workflow.branches.map((branch) => (
                    <li key={branch.label}>
                      <strong>{branch.label}</strong>
                      <ol role="list">
                        {branch.steps.map((step) => (
                          <li data-kind={step.kind} key={step.label}>
                            <span className={styles.outcomeLabel}>{kindLabels[step.kind]}:</span> {step.label}
                          </li>
                        ))}
                      </ol>
                    </li>
                  ))}
                </ol>
              </div>
            ) : null}
          </section>
        ))}
      </div>

      <figcaption id="workflow-atlas-caption">Four woostack workflows from first action to outcome.</figcaption>
    </figure>
  );
}

export default WorkflowAtlas;
