import { Connectors, Diagram, Label, Node } from "../diagram";

export function TeamOrganization() {
  const id = "team-organization";
  return (
    <Diagram
      id={id}
      title="Agent team pipeline"
      height={300}
      description="Work moves from Steward to Engineer to Reviewer to Gatekeeper to Sentinel. Steward files and sizes issues and hands small, settled ones to Engineer. Engineer has workers implement them and hands ready pull requests to Reviewer. Reviewer posts a comment review at the exact head commit, sends findings back to Engineer, and hands clean pull requests to Gatekeeper. Gatekeeper merges low-risk pull requests your policy allows. Sentinel watches production deploys and hands bounded fixes back to Engineer. Steward, Gatekeeper, and Sentinel raise owner decision gates as Needs you items for scope, high-risk merges, and incidents outside policy."
      caption="Solid arrows are handoffs. Dashed lines are owner decision gates: Needs you items with a recommended choice. Findings from Reviewer and fixes from Sentinel are the only backward handoffs."
    >
      <g
        fill="none"
        stroke="currentColor"
        strokeWidth="1.5"
        strokeDasharray="5 4"
        strokeLinejoin="round"
      >
        <path d="M 78 108 H 682" />
        <path d="M 380 108 V 78" markerEnd={`url(#${id}-arrow)`} />
        <path d="M 78 108 V 148" markerEnd={`url(#${id}-arrow)`} />
        <path d="M 531 108 V 148" markerEnd={`url(#${id}-arrow)`} />
        <path d="M 682 108 V 148" markerEnd={`url(#${id}-arrow)`} />
      </g>
      <Connectors id={id}>
        <path d="M 140 183 H 165" />
        <path d="M 291 183 H 316" />
        <path d="M 442 183 H 467" />
        <path d="M 593 183 H 618" />
        <path d="M 380 216 V 240 H 247 V 218" />
        <path d="M 682 216 V 272 H 211 V 218" />
      </Connectors>
      <Label x={380} y={98}>
        Needs you
      </Label>
      <Label x={78} y={133}>
        Scope
      </Label>
      <Label x={531} y={133}>
        High-risk merge
      </Label>
      <Label x={682} y={133}>
        Incident
      </Label>
      <Label x={314} y={244}>
        Findings
      </Label>
      <Label x={531} y={276}>
        Fix handoff
      </Label>
      <Node x={280} y={10} title="Owner" lines={["Requests and decisions"]} accent />
      <Node x={16} y={150} width={124} title="Steward" lines={["Intake and sizing"]} />
      <Node x={167} y={150} width={124} title="Engineer" lines={["Workers and PRs"]} />
      <Node x={318} y={150} width={124} title="Reviewer" lines={["Code review"]} />
      <Node x={469} y={150} width={124} title="Gatekeeper" lines={["Risk and merge"]} />
      <Node x={620} y={150} width={124} title="Sentinel" lines={["Deploy watch"]} />
    </Diagram>
  );
}
