import { Connectors, Diagram, Group, Label, Node } from "../diagram";

export function ShipChangeFlow({ id = "ship-change-flow" }: { id?: string } = {}) {
  return (
    <Diagram
      id={id}
      title="Delivering one change"
      height={574}
      description="The user explicitly requests implementation and draft PR delivery through Execute. Before the first edit, Execute checks Git workspace facts. It makes targeted edits, runs relevant checks, and reviews the scoped diff while preserving unrelated code. It publishes the requested draft PR and verifies its URL, current head, approved base, and draft status. The user reviews the evidence and decides whether to merge. Planning is optional; a draft PR may disclose incomplete or unavailable acceptance and is not itself proof of completion. Only humans merge."
      caption="Planning is optional. A draft PR exposes progress and verification evidence; it is not proof that acceptance passed. Review and merge stay with the human."
    >
      <Group y={20} height={176} title="User request and workspace admission" />
      <Group y={260} height={176} title="Implementation and requested delivery" />
      <Connectors id={id}>
        <path d="M 330 121 H 430" />
        <path d="M 570 170 V 228 H 190 V 314" />
        <path d="M 330 363 H 430" />
        <path d="M 570 412 V 458 H 380 V 488" />
      </Connectors>
      <Label x={380} y={223}>workspace admitted before editing</Label>
      <Label x={380} y={348}>publish</Label>
      <Node x={50} y={72} width={280} height={98} title="Request delivery"
        lines={["/woostack-execute", "Authorize implementation", "and draft PR publication"]} />
      <Node x={430} y={72} width={280} height={98} title="Check workspace"
        lines={["Git branch + base + ownership", "Establish facts", "before the first edit"]} />
      <Node x={50} y={314} width={280} height={98} title="Implement + verify"
        lines={["Targeted edits + relevant tests", "Review the scoped diff", "Preserve unrelated work"]} accent />
      <Node x={430} y={314} width={280} height={98} title="Draft PR"
        lines={["Report evidence and limitations", "Verify URL + head + base", "Confirm draft status"]} />
      <Node x={230} y={488} width={300} title="Human review"
        lines={["Only a human decides to merge"]} accent />
    </Diagram>
  );
}

export default ShipChangeFlow;
