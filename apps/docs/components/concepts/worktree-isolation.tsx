import { Connectors, Diagram, Group, Label, Node } from "../diagram";

export function WorktreeIsolation({ id = "worktree-isolation" }: { id?: string } = {}) {
  return (
    <Diagram
      id={id}
      title="Worktree isolation boundary"
      height={574}
      description="Each task worktree has one active writer, a dedicated directory and working files, its own HEAD and staging index, and its selected branch. Separate working files keep task edits out of the primary checkout. Worktrees still share the repository's Git object database and the host runtime: ports, web servers, databases, background services, secret store, and credentials. They are not runtime sandboxes. Concurrent writers need separate worktrees."
      caption="Solid arrows show each writer's checkout. Dashed arrows show shared resources, not execution order. One active writer per workspace; separate worktrees do not isolate services or credentials."
    >
      <Group x={24} y={20} width={344} height={286} title="Task A worktree" />
      <Group x={392} y={20} width={344} height={286} title="Task B worktree" />
      <Group y={394} height={158} title="Shared across worktrees" />
      <Connectors id={id}>
        <path d="M 196 138 V 202" />
        <path d="M 564 138 V 202" />
        <path d="M 196 284 V 344 H 380 V 370 H 196 V 448" strokeDasharray="5 4" />
        <path d="M 564 284 V 344 H 380 V 370 H 564 V 448" strokeDasharray="5 4" />
      </Connectors>
      <Label x={196} y={177}>owns edits</Label>
      <Label x={564} y={177}>owns edits</Label>
      <Node x={64} y={72} width={264} title="One active writer" lines={["Task A"]} accent />
      <Node x={432} y={72} width={264} title="One active writer" lines={["Task B"]} accent />
      <Node x={64} y={202} width={264} height={82} title="Checkout A"
        lines={["Directory + files + branch + HEAD", "Staging index + unstaged changes"]} />
      <Node x={432} y={202} width={264} height={82} title="Checkout B"
        lines={["Directory + files + branch + HEAD", "Staging index + unstaged changes"]} />
      <Node x={64} y={448} width={264} height={82} title="Git object database"
        lines={["Shared repository history", ".git/objects"]} />
      <Node x={432} y={448} width={264} height={82} title="Host runtime"
        lines={["Ports + servers + databases", "Daemons + secrets + credentials"]} />
    </Diagram>
  );
}

export default WorktreeIsolation;
