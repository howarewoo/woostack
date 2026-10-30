import { Connectors, Diagram, Label, Node } from "../diagram";

export function HermesActors({ id = "hermes-actors" }: { id?: string } = {}) {
  return (
    <Diagram
      id={id}
      title="Hermes and OMP actor boundaries"
      height={628}
      description="The responsible user approves scope changes and new tasks, answers pending questions, and retains exclusive merge authority. Hermes coordinates the process, reviews diffs, checks contract compliance and blockers, and requests in-scope corrections. It relays questions to the user and returns the user's live answers verbatim to the persistent OMP coding session. OMP executes skills and tools, edits source, and runs tests under its active profile and tool schema, then returns progress, evidence, and questions. Hermes cannot edit source, run builds, commit, push, or merge."
      caption="Arrows show messages and evidence, not shared tool permissions. Hermes coordinates; OMP implements; the responsible user authorizes changes and alone may merge."
    >
      <Connectors id={id}>
        <path d="M 220 304 H 112 V 76 H 220" />
        <path d="M 540 76 H 648 V 304 H 540" />
        <path d="M 220 548 H 112 V 336 H 220" />
        <path d="M 540 336 H 648 V 548 H 540" />
      </Connectors>
      <Label x={112} y={178}>asks / scope</Label>
      <Label x={112} y={198}>decisions</Label>
      <Label x={648} y={178}>live answers</Label>
      <Label x={648} y={198}>and approvals</Label>
      <Label x={112} y={422}>progress / diffs</Label>
      <Label x={112} y={442}>evidence / asks</Label>
      <Label x={648} y={414}>verbatim answers</Label>
      <Label x={648} y={434}>in-scope corrections</Label>
      <Node x={220} y={26} width={320} height={100} title="Responsible user"
        lines={["Scope changes + new tasks", "Answers pending questions", "Exclusive merge authority"]} accent />
      <Node x={220} y={270} width={320} height={100} title="Hermes"
        lines={["Coordinate + review diffs", "Check contracts + blockers", "No source edits, builds, or Git writes"]} />
      <Node x={220} y={498} width={320} height={100} title="Persistent OMP session"
        lines={["Execute skills + tools", "Edit source + run tests", "Active profile and tool schema"]} />
    </Diagram>
  );
}

export default HermesActors;
