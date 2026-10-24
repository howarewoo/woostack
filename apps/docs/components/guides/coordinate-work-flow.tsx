/**
 * CoordinateWorkFlow diagram for the Coordinate several tasks guide.
 *
 * Visualizes the 3-stage orchestration process: select & propose, authorize execution,
 * and verify deliveries.
 * Responsive semantic HTML with Fumadocs theme utilities.
 */
export function CoordinateWorkFlow() {
  return (
    <figure className="not-prose my-6 rounded-xl border border-fd-border bg-fd-card p-4 sm:p-6">
      <div className="flex flex-col gap-4">
        <div>
          <h3 className="text-sm font-semibold text-fd-foreground">Orchestration workflow</h3>
          <p className="text-xs text-fd-muted-foreground mt-0.5">
            Three ordered stages: plan proposal, user authorization, and delivery verification.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {/* Stage 1 */}
          <div className="flex flex-col justify-between rounded-lg border border-fd-border bg-fd-card/60 p-4">
            <div>
              <span className="text-xs font-semibold text-fd-muted-foreground">Stage 1</span>
              <h4 className="mt-1 text-sm font-semibold text-fd-foreground">
                Select &amp; propose
              </h4>
              <p className="mt-1 text-xs text-fd-muted-foreground">
                Supply tasks or tracker URL; Orchestrate reads evidence.
              </p>
              <pre className="mt-2 overflow-x-auto rounded border border-fd-border bg-fd-accent/50 p-2 font-mono text-xs text-fd-foreground">
                <code>/woostack-orchestrate ...</code>
              </pre>
            </div>
            <p className="mt-3 text-xs text-fd-muted-foreground">
              Proposes task-to-PR grouping, dependencies, and landing order.
            </p>
          </div>

          {/* Stage 2 */}
          <div className="flex flex-col justify-between rounded-lg border border-fd-border bg-fd-card/60 p-4">
            <div>
              <span className="text-xs font-semibold text-fd-muted-foreground">Stage 2</span>
              <h4 className="mt-1 text-sm font-semibold text-fd-foreground">Authorize execution</h4>
              <p className="mt-1 text-xs text-fd-muted-foreground">
                Review proposed groups, boundaries, and parallel paths.
              </p>
              <div className="mt-2 rounded border border-fd-border bg-fd-accent/50 px-2.5 py-1.5 text-xs font-medium text-fd-foreground">
                User approves proposal first
              </div>
            </div>
            <p className="mt-3 text-xs text-fd-muted-foreground">
              No branches, edits, or worker dispatches occur before approval.
            </p>
          </div>

          {/* Stage 3 */}
          <div className="flex flex-col justify-between rounded-lg border border-fd-border bg-fd-card/60 p-4">
            <div>
              <span className="text-xs font-semibold text-fd-muted-foreground">Stage 3</span>
              <h4 className="mt-1 text-sm font-semibold text-fd-foreground">
                Deliver &amp; verify
              </h4>
              <p className="mt-1 text-xs text-fd-muted-foreground">
                Task owners implement in isolated worktrees.
              </p>
              <div className="mt-2 rounded border border-fd-border bg-fd-accent/50 px-2.5 py-1.5 text-xs font-medium text-fd-foreground">
                Draft PRs (stacked for dependents)
              </div>
            </div>
            <p className="mt-3 text-xs text-fd-muted-foreground">
              Delivers draft PRs for human review and merge.
            </p>
          </div>
        </div>

        <div className="rounded-lg border border-fd-border/70 bg-fd-muted/40 px-3 py-2 text-center text-xs text-fd-muted-foreground">
          Gates: Draft PR discloses progress • Consumer release needs verified prerequisite content
          • Merging stays with human
        </div>
      </div>
    </figure>
  );
}

export default CoordinateWorkFlow;
