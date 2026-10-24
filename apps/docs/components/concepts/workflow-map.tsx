/**
 * WorkflowMap diagram for the Workflow maps concept page.
 *
 * Visualizes routing by work shape, showing that bounded changes skip planning
 * and go directly to Execute, while Plan and Orchestrate handle broader goals
 * and multi-task dependencies.
 * Responsive semantic HTML with Fumadocs theme utilities.
 */
export function WorkflowMap() {
  return (
    <figure className="not-prose my-6 rounded-xl border border-fd-border bg-fd-card p-4 sm:p-6">
      <div className="flex flex-col gap-4">
        <div>
          <h3 className="text-sm font-semibold text-fd-foreground">Route by work shape</h3>
          <p className="text-xs text-fd-muted-foreground mt-0.5">
            One authorized outcome is enough to start: bounded work goes straight to Execute without
            planning.
          </p>
        </div>

        {/* Primary work-shape choices */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {/* Choice 1: Execute */}
          <div className="flex flex-col justify-between rounded-lg border border-fd-border bg-fd-card/60 p-4">
            <div>
              <div className="flex items-center justify-between gap-2">
                <span className="rounded bg-fd-primary/10 px-2 py-0.5 text-xs font-semibold text-fd-primary">
                  Bounded task
                </span>
              </div>
              <h4 className="mt-2 text-base font-semibold text-fd-foreground">Execute</h4>
              <p className="mt-1 text-xs text-fd-muted-foreground">
                Enhancement, refactor, test, or authorized bug fix.
              </p>
              <div className="mt-3 rounded border border-fd-border bg-fd-accent/50 px-2.5 py-1.5 text-xs font-medium text-fd-foreground">
                Skips planning stage
              </div>
            </div>
            <p className="mt-3 text-xs text-fd-muted-foreground">
              Admits workspace, makes targeted edits, runs relevant checks, and delivers a draft PR
              on request.
            </p>
          </div>

          {/* Choice 2: Plan */}
          <div className="flex flex-col justify-between rounded-lg border border-fd-border bg-fd-card/60 p-4">
            <div>
              <div className="flex items-center justify-between gap-2">
                <span className="rounded bg-fd-muted px-2 py-0.5 text-xs font-semibold text-fd-foreground">
                  Goal or roadmap
                </span>
              </div>
              <h4 className="mt-2 text-base font-semibold text-fd-foreground">Plan</h4>
              <p className="mt-1 text-xs text-fd-muted-foreground">
                Requirements exploration, new features, or issue filing.
              </p>
              <div className="mt-3 rounded border border-fd-border bg-fd-accent/50 px-2.5 py-1.5 text-xs font-medium text-fd-foreground">
                Edits zero code files
              </div>
            </div>
            <p className="mt-3 text-xs text-fd-muted-foreground">
              Inspects source, settles unresolved decisions, and returns a plan. Files GitHub issues
              only when requested.
            </p>
          </div>

          {/* Choice 3: Orchestrate */}
          <div className="flex flex-col justify-between rounded-lg border border-fd-border bg-fd-card/60 p-4">
            <div>
              <div className="flex items-center justify-between gap-2">
                <span className="rounded bg-fd-muted px-2 py-0.5 text-xs font-semibold text-fd-foreground">
                  Dependent tasks
                </span>
              </div>
              <h4 className="mt-2 text-base font-semibold text-fd-foreground">Orchestrate</h4>
              <p className="mt-1 text-xs text-fd-muted-foreground">
                Multiple approved tasks with real prerequisites.
              </p>
              <div className="mt-3 rounded border border-fd-border bg-fd-accent/50 px-2.5 py-1.5 text-xs font-medium text-fd-foreground">
                User approves plan first
              </div>
            </div>
            <p className="mt-3 text-xs text-fd-muted-foreground">
              Coordinates single-group runs or stacked PRs, delegating each group to an isolated
              task worker.
            </p>
          </div>
        </div>

        {/* Specialized investigation and simplification */}
        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4 border-t border-fd-border/70 pt-4">
          <div className="rounded-lg border border-fd-border bg-fd-card/40 p-3">
            <h5 className="text-xs font-semibold text-fd-foreground">Debug</h5>
            <p className="mt-1 text-xs text-fd-muted-foreground">
              Optional separate read-only investigation. Execute can diagnose inline; root-cause
              evidence is required before repair.
            </p>
          </div>
          <div className="rounded-lg border border-fd-border bg-fd-card/40 p-3">
            <h5 className="text-xs font-semibold text-fd-foreground">Simplify</h5>
            <p className="mt-1 text-xs text-fd-muted-foreground">
              Reduces code and maintenance complexity while strictly preserving existing behavior.
            </p>
          </div>
        </div>
      </div>
    </figure>
  );
}

export default WorkflowMap;
