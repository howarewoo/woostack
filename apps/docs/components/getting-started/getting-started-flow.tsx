import { Connectors, Diagram, Group, Label, Node } from "../diagram";

export function GettingStartedFlow({ id = "getting-started-flow" }: { id?: string } = {}) {
  return (
    <Diagram
      id={id}
      title="Getting started workflow"
      height={570}
      description="First, run pnpx skills add howarewoo/woostack in the terminal to install skill instructions for your assistant. Then ask the coding assistant to run /woostack-init to author the README, AGENTS.md, and project boundaries. Next, request /woostack-plan for a read-only plan with zero file edits. The plan stays in chat until you explicitly request implementation and delivery. Assistant slash requests are not terminal commands."
      caption="Install in the terminal; use Init and Plan inside your coding assistant. The plan stays in chat. Implementation and delivery need a separate explicit request."
    >
      <Group y={20} height={154} title="Terminal" />
      <Group y={226} height={322} title="Coding assistant" />
      <Connectors id={id}>
        <path d="M 380 154 V 286" />
        <path d="M 380 368 V 444" />
      </Connectors>
      <Label x={380} y={209}>skills available to the assistant</Label>
      <Label x={380} y={414}>project guidance ready</Label>
      <Node x={210} y={72} width={340} height={82} title="1. Install skills"
        lines={["pnpx skills add howarewoo/woostack", "Downloads assistant instructions"]} />
      <Node x={210} y={286} width={340} height={82} title="2. Adopt guidance"
        lines={["/woostack-init", "README + AGENTS.md + project boundaries"]} />
      <Node x={210} y={444} width={340} height={82} title="3. Request your first plan"
        lines={["/woostack-plan", "Read-only plan in chat; no file edits"]} accent />
    </Diagram>
  );
}

export default GettingStartedFlow;
