import { Connectors, Diagram, Group, Label, Node } from "../diagram";

export function ContextEconomy({ id = "context-economy" }: { id?: string } = {}) {
  return (
    <Diagram
      id={id}
      title="Keep the working context focused"
      height={452}
      description="Three mechanisms limit what enters the agent's working context. Scoped instructions supply only applicable rules. Scripts do heavy computation in the shell and return compact text output. Subagents perform bounded tasks in separate contexts and return summaries. These inputs keep the main context focused on user goals, active decisions, and verified evidence rather than unrelated instructions or heavy intermediate work."
      caption="Arrows show what enters the main context. Heavy computation and delegated work stay outside it; the agent receives applicable rules, compact results, and summaries."
    >
      <Group y={20} height={156} title="Keep heavy or unrelated material outside the main context" />
      <Connectors id={id}>
        <path d="M 148 154 V 238 H 300 V 336" />
        <path d="M 380 154 V 336" />
        <path d="M 612 154 V 238 H 460 V 336" />
      </Connectors>
      <Label x={148} y={211}>applicable rules</Label>
      <Label x={380} y={211}>compact output</Label>
      <Label x={612} y={211}>task summary</Label>
      <Node x={48} y={72} height={82} title="Scoped instructions"
        lines={["Load relevant rules", "for the active workflow"]} />
      <Node x={280} y={72} height={82} title="Scripts compute"
        lines={["Heavy calculation", "runs in the shell"]} />
      <Node x={512} y={72} height={82} title="Subagents isolate"
        lines={["Bounded tasks", "in separate contexts"]} />
      <Node x={210} y={336} width={340} height={82} title="Agent working context"
        lines={["User goals + active decisions", "Verified evidence"]} accent />
    </Diagram>
  );
}

export default ContextEconomy;
