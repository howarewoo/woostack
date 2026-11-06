import { Connectors, Diagram, Node } from "../diagram";

export function TeamOrganization() {
  const id = "team-organization";
  return (
    <Diagram
      id={id}
      title="Agent team organization"
      height={330}
      description="The chief of staff coordinates department chiefs. The R&D CTO leads the senior engineer, junior engineer, and an optional product designer. Marketing and other department chiefs are illustrative future roles. The CTO can assign specified work directly to the junior; the senior reviews the junior's delivery."
      caption="Organization and coordination, not a mandatory sequence of handoffs. Only R&D has a setup guide today."
    >
      <Connectors id={id}>
        <path d="M 380 76 V 105 H 150 V 135" />
        <path d="M 380 76 V 105 H 390 V 135" />
        <path d="M 380 76 V 105 H 630 V 135" />
        <path d="M 150 201 V 225 H 100 V 250" />
        <path d="M 150 201 V 225 H 300 V 250" />
        <path d="M 150 201 V 225 H 520 V 250" />
      </Connectors>
      <Node x={280} y={10} title="Chief of staff" accent />
      <Node x={50} y={135} title="R&D CTO" />
      <Node x={290} y={135} title="Marketing chief" lines={["Illustrative"]} />
      <Node x={530} y={135} title="Other chiefs" lines={["Illustrative"]} />
      <Node x={10} y={250} width={180} title="Senior engineer" />
      <Node x={210} y={250} width={180} title="Junior engineer" />
      <Node x={410} y={250} width={220} title="Product designer" lines={["Optional"]} />
    </Diagram>
  );
}
