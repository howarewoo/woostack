import { Connectors, Diagram, Group, Label, Node } from "../diagram";

export function WorkflowMap({ id = "workflow-map" }: { id?: string } = {}) {
  return (
    <Diagram
      id={id}
      title="Choose by the result you need"
      height={534}
      description="A bounded change goes to Execute for edits and checks, with a draft PR when requested. An unsettled goal goes to Whiteboard for requirements or a plan without code edits. Several executable tasks go to Orchestrate, which proposes groups and checks approval or delegated authority before coordinating isolated workers. Debug investigates without editing; Simplify reduces working code while preserving behavior. These workflows are independent entry points."
      caption="Planning is optional for a clear task. Choose Debug for a read-only investigation or Simplify when working code is too complex."
    >
      <Group y={362} height={150} title="Other tasks" />
      <Connectors id={id}>
        <path d="M 300 92 V 132 H 148 V 226" />
        <path d="M 380 92 V 226" />
        <path d="M 460 92 V 132 H 612 V 226" />
      </Connectors>
      <Label x={148} y={191}>
        bounded change
      </Label>
      <Label x={380} y={191}>
        unsettled goal
      </Label>
      <Label x={612} y={191}>
        several tasks
      </Label>
      <Node
        x={230}
        y={26}
        width={300}
        title="Requested outcome"
        lines={["Choose the matching workflow"]}
        accent
      />
      <Node
        x={48}
        y={226}
        height={100}
        title="Execute"
        lines={["Implement one outcome", "Run relevant checks", "Draft PR when requested"]}
      />
      <Node
        x={280}
        y={226}
        height={100}
        title="Whiteboard"
        lines={["Explore requirements", "Return a reviewable plan", "No code edits"]}
      />
      <Node
        x={512}
        y={226}
        height={100}
        title="Orchestrate"
        lines={["Propose task groups", "Validate authority first", "Coordinate isolated workers"]}
      />
      <Node
        x={70}
        y={414}
        width={280}
        height={82}
        title="Debug"
        lines={["Read-only investigation", "Execute can also diagnose inline"]}
      />
      <Node
        x={410}
        y={414}
        width={280}
        height={82}
        title="Simplify"
        lines={["Reduce code and complexity", "Preserve required behavior"]}
      />
    </Diagram>
  );
}

export default WorkflowMap;
