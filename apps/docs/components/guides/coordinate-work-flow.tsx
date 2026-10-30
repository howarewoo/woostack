import { Connectors, Diagram, Group, Label, Node } from "../diagram";

export function CoordinateWorkFlow({ id = "coordinate-work-flow" }: { id?: string } = {}) {
  return (
    <Diagram
      id={id}
      title="Orchestration workflow"
      height={724}
      description="Supply approved executable tasks or a tracker to Orchestrate. It reads evidence and proposes task-to-PR groups, dependencies, boundaries, and landing order. The user reviews the proposal. Revision-only feedback returns to the proposal and pauses again; approval authorizes execution. No worktrees, source edits, or worker dispatches occur before approval. Ready independent groups can run in parallel, each with one owner and an isolated worktree. Dependent work waits for verified applicable prerequisite content and contract evidence, not merely a published PR. Requested delivery produces draft PRs, stacked for dependent work as applicable. Verify delivery identity and acceptance separately. Only humans merge."
      caption="Approval gates execution. Verified prerequisite content gates dependent work. Draft publication is not completion: acceptance and delivery identity are checked separately, and only humans merge."
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
      <Label x={380} y={157}>review proposal</Label>
      <Label x={100} y={157}>revise</Label>
      <Label x={380} y={304}>approved</Label>
      <Node x={220} y={26} width={320} height={82} title="Select + propose"
        lines={["/woostack-orchestrate", "PR groups + dependencies + landing order"]} />
      <Node x={220} y={190} width={320} height={82} title="User approval"
        lines={["Review scope and parallel paths", "Revision-only feedback pauses again"]} accent />
      <Node x={50} y={380} width={280} height={98} title="Task owner A"
        lines={["Own worktree", "Implement + verify", "One active writer"]} />
      <Node x={430} y={380} width={280} height={98} title="Task owner B"
        lines={["Own worktree", "Implement + verify", "One active writer"]} />
      <Node x={220} y={568} width={320} height={82} title="Deliver + verify"
        lines={["Draft PRs; stack dependents as applicable", "Verify acceptance and delivery identity"]} />
      <Label x={380} y={708}>Human review and merge</Label>
    </Diagram>
  );
}

export default CoordinateWorkFlow;
