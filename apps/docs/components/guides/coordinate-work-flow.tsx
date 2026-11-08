import { Connectors, Diagram, Group, Label, Node } from "../diagram";

export function CoordinateWorkFlow({ id = "coordinate-work-flow" }: { id?: string } = {}) {
  return (
    <Diagram
      id={id}
      title="From proposal to isolated task owners"
      height={724}
      description="Orchestrate proposes task groups, prerequisites, and landing order. The user approves execution, or a named coordinator validates it against explicitly delegated authority. Revision-only feedback returns to the proposal and pauses. Before authorization there are no edits, worktree allocations, or worker dispatches. Ready groups run in separate worktrees with one active writer each. Dependent work waits for verified prerequisite content and contract evidence. Requested delivery includes draft PRs and native stacks for dependent PRs. Acceptance and PR identity are verified separately; only humans merge."
      caption="Independent groups can run together after authorization. Dependent work waits for verified prerequisites, which may be ready before a PR is published."
    >
      <Group y={326} height={174} title="Independent groups" />
      <Connectors id={id}>
        <path d="M 380 108 V 190" />
        <path d="M 220 231 H 100 V 67 H 220" />
        <path d="M 320 272 V 310 H 190 V 380" />
        <path d="M 440 272 V 310 H 570 V 380" />
        <path d="M 190 478 V 528 H 320 V 568" />
        <path d="M 570 478 V 528 H 440 V 568" />
        <path d="M 380 650 V 680" />
      </Connectors>
      <Label x={380} y={157}>
        review proposal
      </Label>
      <Label x={100} y={157}>
        revise
      </Label>
      <Label x={380} y={304}>
        authorized
      </Label>
      <Node
        x={220}
        y={26}
        width={320}
        height={82}
        title="Select + propose"
        lines={["/woostack-orchestrate", "PR groups + dependencies + landing order"]}
      />
      <Node
        x={220}
        y={190}
        width={320}
        height={82}
        title="Authorize execution"
        lines={["User approval or bounded delegation", "Revision-only feedback pauses again"]}
        accent
      />
      <Node
        x={50}
        y={380}
        width={280}
        height={98}
        title="Task owner A"
        lines={["Own worktree", "Implement + verify", "One active writer"]}
      />
      <Node
        x={430}
        y={380}
        width={280}
        height={98}
        title="Task owner B"
        lines={["Own worktree", "Implement + verify", "One active writer"]}
      />
      <Node
        x={220}
        y={568}
        width={320}
        height={82}
        title="Deliver + verify"
        lines={["Draft PRs; native stacks for dependents", "Check acceptance and PR identity"]}
      />
      <Label x={380} y={708}>
        Human review and merge
      </Label>
    </Diagram>
  );
}

export default CoordinateWorkFlow;
