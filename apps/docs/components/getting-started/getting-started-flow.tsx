/**
 * GettingStartedFlow diagram for the Getting started tutorial.
 *
 * Illustrates the three tutorial steps, distinguishing terminal commands
 * from coding assistant slash requests.
 * Responsive semantic HTML with Fumadocs theme utilities.
 */
export function GettingStartedFlow() {
  return (
    <figure className="not-prose my-6 rounded-xl border border-fd-border bg-fd-card p-4 sm:p-6">
      <div className="flex flex-col gap-4">
        <div>
          <h3 className="text-sm font-semibold text-fd-foreground">Getting started workflow</h3>
          <p className="text-xs text-fd-muted-foreground mt-0.5">
            Three progressive steps: install skills in your terminal, create project guidance, and
            return a read-only plan.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {/* Step 1 */}
          <div className="flex flex-col justify-between rounded-lg border border-fd-border bg-fd-card/60 p-4">
            <div>
              <div className="flex items-center justify-between gap-2">
                <span className="text-xs font-semibold text-fd-muted-foreground">Step 1</span>
                <span className="rounded bg-fd-muted px-2 py-0.5 text-xs font-medium text-fd-foreground">
                  Terminal
                </span>
              </div>
              <h4 className="mt-2 text-sm font-semibold text-fd-foreground">Install skills</h4>
              <pre className="mt-2 overflow-x-auto rounded border border-fd-border bg-fd-accent/50 p-2 font-mono text-xs text-fd-foreground">
                <code>pnpx skills add howarewoo/woostack</code>
              </pre>
            </div>
            <p className="mt-3 text-xs text-fd-muted-foreground">
              Downloads skill instructions for your assistant.
            </p>
          </div>

          {/* Step 2 */}
          <div className="flex flex-col justify-between rounded-lg border border-fd-border bg-fd-card/60 p-4">
            <div>
              <div className="flex items-center justify-between gap-2">
                <span className="text-xs font-semibold text-fd-muted-foreground">Step 2</span>
                <span className="rounded bg-fd-muted px-2 py-0.5 text-xs font-medium text-fd-foreground">
                  Coding assistant
                </span>
              </div>
              <h4 className="mt-2 text-sm font-semibold text-fd-foreground">Adopt guidance</h4>
              <pre className="mt-2 overflow-x-auto rounded border border-fd-border bg-fd-accent/50 p-2 font-mono text-xs text-fd-foreground">
                <code>/woostack-init ...</code>
              </pre>
            </div>
            <p className="mt-3 text-xs text-fd-muted-foreground">
              Authors README, AGENTS.md, and project boundaries.
            </p>
          </div>

          {/* Step 3 */}
          <div className="flex flex-col justify-between rounded-lg border border-fd-border bg-fd-card/60 p-4">
            <div>
              <div className="flex items-center justify-between gap-2">
                <span className="text-xs font-semibold text-fd-muted-foreground">Step 3</span>
                <span className="rounded bg-fd-muted px-2 py-0.5 text-xs font-medium text-fd-foreground">
                  Coding assistant
                </span>
              </div>
              <h4 className="mt-2 text-sm font-semibold text-fd-foreground">First plan</h4>
              <pre className="mt-2 overflow-x-auto rounded border border-fd-border bg-fd-accent/50 p-2 font-mono text-xs text-fd-foreground">
                <code>/woostack-plan ...</code>
              </pre>
            </div>
            <p className="mt-3 text-xs text-fd-muted-foreground">
              Returns read-only plan; zero file edits.
            </p>
          </div>
        </div>

        <div className="rounded-lg border border-fd-border/70 bg-fd-muted/40 px-3 py-2 text-center text-xs text-fd-muted-foreground">
          Your plan stays in chat until you explicitly request implementation and delivery.
        </div>
      </div>
    </figure>
  );
}

export default GettingStartedFlow;
