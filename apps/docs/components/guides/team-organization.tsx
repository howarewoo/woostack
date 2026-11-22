import { Connectors, Diagram, Label, Node } from "../diagram";

export function TeamOrganization() {
  const id = "team-organization";
  return (
    <Diagram
      id={id}
      title="Agent team pipeline"
      height={290}
      description="Work moves from Steward to Engineer to Gatekeeper to Sentinel. Steward files and sizes issues and hands small, settled ones to Engineer. Engineer has workers implement them and hands green, approved pull requests to Gatekeeper. Gatekeeper merges low-risk pull requests your policy allows. Sentinel watches production deploys and hands bounded fixes back to Engineer. Steward, Gatekeeper, and Sentinel raise owner decision gates as Needs you items for scope, high-risk merges, and incidents outside policy."
      caption="Solid arrows are handoffs. Dashed lines are owner decision gates: Needs you items with a recommended choice. The fix handoff from Sentinel is the only loop."
    >
      <g
        fill="none"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeDasharray="5 4"
        strokeLinejoin="round"
      >
        <path d="M 85 108 H 665" />
        <path d="M 380 108 V 78" markerEnd={`url(#${id}-arrow)`} />
        <path d="M 85 108 V 148" markerEnd={`url(#${id}-arrow)`} />
        <path d="M 472 108 V 148" markerEnd={`url(#${id}-arrow)`} />
        <path d="M 665 108 V 148" markerEnd={`url(#${id}-arrow)`} />
      </g>
      <Connectors id={id}>
        <path d="M 160 183 H 201" />
        <path d="M 353 183 H 395" />
        <path d="M 547 183 H 588" />
        <path d="M 665 216 V 258 H 278 V 218" />
      </Connectors>
      <Label x={380} y={98}>
        Needs you
      </Label>
      <Label x={85} y={133}>
        Scope
      </Label>
      <Label x={472} y={133}>
        High-risk merge
      </Label>
      <Label x={665} y={133}>
        Incident
      </Label>
      <Label x={472} y={262}>
        Fix handoff
      </Label>
      <Node x={280} y={10} title="Owner" lines={["Requests and decisions"]} accent />
      <Node x={10} y={150} width={150} title="Steward" lines={["Intake and sizing"]} />
      <Node x={203} y={150} width={150} title="Engineer" lines={["Workers and PRs"]} />
      <Node x={397} y={150} width={150} title="Gatekeeper" lines={["Risk and merge"]} />
      <Node x={590} y={150} width={150} title="Sentinel" lines={["Deploy watch"]} />
    </Diagram>
  );
}
