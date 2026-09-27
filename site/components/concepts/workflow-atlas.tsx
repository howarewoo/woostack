import Link from 'next/link';

import styles from './workflow-atlas.module.css';

type StepKind = 'work' | 'gate' | 'handoff' | 'terminal';

type WorkflowStep = Readonly<{
  label: string;
  detail?: string;
  kind: StepKind;
}>;

type WorkflowId = 'execute' | 'bootstrap';

type Workflow = Readonly<{
  id: WorkflowId;
  title: string;
  useWhen: string;
  href: string;
  gateCount: number;
  steps: readonly WorkflowStep[];
}>;

const workflows: readonly Workflow[] = [
  {
    id: 'execute',
    title: 'Execute',
    useWhen: 'Use for one bounded enhancement, refactor, test-only task, or authorized correction.',
    href: '/docs/skills/woostack-execute',
    gateCount: 0,
    steps: [
      { label: 'Admit task scope', kind: 'work' },
      { label: 'Isolate worktree', kind: 'work' },
      { label: 'Implement', kind: 'work' },
      { label: 'Verify and smoke-test', kind: 'work' },
      { label: 'Commit and submit', kind: 'work' },
      { label: 'Verify PR and retain workspace', kind: 'work' },
      { label: 'One draft PR awaiting human review', kind: 'terminal' },
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
          </section>
        ))}
      </div>

      <figcaption id="workflow-atlas-caption">Two woostack workflows from first action to outcome.</figcaption>
    </figure>
  );
}

export default WorkflowAtlas;
