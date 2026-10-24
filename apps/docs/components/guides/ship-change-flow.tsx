/**
 * ShipChangeFlow diagram for the Deliver one change how-to guide.
 *
 * Visualizes the 3-step delivery process: request, implementation & verification,
 * and draft pull request review.
 * Responsive semantic HTML with Fumadocs theme utilities.
 */
export function ShipChangeFlow() {
  return (
    <figure className="not-prose my-6 rounded-xl border border-fd-border bg-fd-card p-4 sm:p-6">
      <div className="flex flex-col gap-4">
        <div>
          <h3 className="text-sm font-semibold text-fd-foreground">Delivering one change</h3>
          <p className="text-xs text-fd-muted-foreground mt-0.5">
            Three ordered stages from explicit request to draft pull request review.
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
          {/* Stage 1 */}
          <div className="flex flex-col justify-between rounded-lg border border-fd-border bg-fd-card/60 p-4">
            <div>
              <span className="text-xs font-semibold text-fd-muted-foreground">Stage 1</span>
              <h4 className="mt-1 text-sm font-semibold text-fd-foreground">Request delivery</h4>
              <p className="mt-1 text-xs text-fd-muted-foreground">
                Explicit request authorizing implementation and draft PR delivery.
              </p>
              <pre className="mt-2 overflow-x-auto rounded border border-fd-border bg-fd-accent/50 p-2 font-mono text-xs text-fd-foreground">
                <code>/woostack-execute ...</code>
              </pre>
            </div>
            <p className="mt-3 text-xs text-fd-muted-foreground">
              Admits Git workspace facts before the first edit.
            </p>
          </div>

          {/* Stage 2 */}
          <div className="flex flex-col justify-between rounded-lg border border-fd-border bg-fd-card/60 p-4">
            <div>
              <span className="text-xs font-semibold text-fd-muted-foreground">Stage 2</span>
              <h4 className="mt-1 text-sm font-semibold text-fd-foreground">
                Implement &amp; verify
              </h4>
              <p className="mt-1 text-xs text-fd-muted-foreground">
                Makes targeted edits and runs relevant test suites.
              </p>
              <div className="mt-2 rounded border border-fd-border bg-fd-accent/50 px-2.5 py-1.5 text-xs font-medium text-fd-foreground">
                Scoped diff + relevant tests
              </div>
            </div>
            <p className="mt-3 text-xs text-fd-muted-foreground">
              Confirms diff matches outcome and leaves unrelated code untouched.
            </p>
          </div>

          {/* Stage 3 */}
          <div className="flex flex-col justify-between rounded-lg border border-fd-border bg-fd-card/60 p-4">
            <div>
              <span className="text-xs font-semibold text-fd-muted-foreground">Stage 3</span>
              <h4 className="mt-1 text-sm font-semibold text-fd-foreground">Review draft PR</h4>
              <p className="mt-1 text-xs text-fd-muted-foreground">
                Inspects draft pull request on GitHub before merging.
              </p>
              <div className="mt-2 rounded border border-fd-border bg-fd-accent/50 px-2.5 py-1.5 text-xs font-medium text-fd-foreground">
                Only humans merge
              </div>
            </div>
            <p className="mt-3 text-xs text-fd-muted-foreground">
              Verifies head commit, approved base, and draft status.
            </p>
          </div>
        </div>

        <div className="rounded-lg border border-fd-border/70 bg-fd-muted/40 px-3 py-2 text-center text-xs text-fd-muted-foreground">
          Guardrails: Planning is optional • Draft PR discloses progress • Merging stays with human
        </div>
      </div>
    </figure>
  );
}

export default ShipChangeFlow;
