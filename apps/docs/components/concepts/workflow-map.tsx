import { Connectors, Diagram, Group, Label, Node } from "../diagram";

export function WorkflowMap({ id = "workflow-map" }: { id?: string } = {}) {
  return (
    <Diagram
      id={id}
      title="Route by work shape"
      height={534}
      description="Choose the workflow for the requested outcome, not a mandatory chain. A bounded change goes directly to Execute for targeted edits, relevant checks, and a draft PR when requested. A goal or roadmap goes to Plan for requirements and a reviewable plan; it edits no code and files issues only when requested. Dependent tasks go to Orchestrate for an execution proposal that the user must approve before coordination of isolated task workers. Debug is an optional read-only investigation; Execute can also diagnose inline and requires root-cause evidence before repair. Simplify is optional behavior-preserving code reduction."
      caption="These are alternative entry points, not Plan → Execute → Orchestrate prerequisites. One authorized bounded outcome can go straight to Execute. Debug and Simplify remain optional."
    >
      <Group y={362} height={150} title="Optional workflows, not prerequisites" />
      <Connectors id={id}>
        <path d="M 300 92 V 132 H 148 V 226" />
        <path d="M 380 92 V 226" />
        <path d="M 460 92 V 132 H 612 V 226" />
      </Connectors>
      <Label x={148} y={191}>bounded change</Label>
      <Label x={380} y={191}>goal or roadmap</Label>
      <Label x={612} y={191}>dependent tasks</Label>
      <Node x={230} y={26} width={300} title="Requested outcome"
        lines={["Choose the matching workflow"]} accent />
      <Node x={48} y={226} height={100} title="Execute"
        lines={["Targeted edits + checks", "Draft PR when requested", "No planning prerequisite"]} />
      <Node x={280} y={226} height={100} title="Plan"
        lines={["Explore requirements", "Return a reviewable plan", "No code edits"]} />
      <Node x={512} y={226} height={100} title="Orchestrate"
        lines={["Propose task groups", "User approves first", "Coordinate isolated workers"]} />
      <Node x={70} y={414} width={280} height={82} title="Debug"
        lines={["Read-only investigation", "Execute can also diagnose inline"]} />
      <Node x={410} y={414} width={280} height={82} title="Simplify"
        lines={["Reduce code and complexity", "Preserve behavior and public APIs"]} />
    </Diagram>
  );
}

export default WorkflowMap;
