import { PERSPECTIVE_STYLE } from "./shared-styles";

/** Slight forward tilt for the phone bezel mockup. */
const PHONE_TRANSFORM_STYLE = { transform: "rotateX(2deg)" } as const;

/** The canonical time shown in Apple marketing screenshots. */
const IOS_MARKETING_TIME = "9:41" as const;

/** Phone bezel mockup showing a sign-in screen. */
export function PhoneFrame() {
  return (
    <div className="flex justify-center" style={PERSPECTIVE_STYLE}>
      <div
        className="w-full max-w-[260px] rounded-[2.5rem] border-[3px] border-foreground/10 bg-foreground/5 p-2"
        style={PHONE_TRANSFORM_STYLE}
      >
        {/* Screen — iPhone 15/16 aspect ratio (9:19.5) */}
        <div className="flex flex-col overflow-hidden rounded-[2rem] bg-background aspect-[9/19.5]">
          {/* Dynamic Island */}
          <div className="flex justify-center pt-2.5" aria-hidden="true">
            <div className="h-5 w-24 rounded-full bg-foreground/10" />
          </div>

          {/* Status bar */}
          <div className="flex items-center justify-between px-6 pb-2 pt-1">
            {/* iOS default marketing screenshot time */}
            <span className="text-[9px] font-medium text-foreground">{IOS_MARKETING_TIME}</span>
            <div className="flex items-center gap-1" aria-hidden="true">
              <div className="flex items-end gap-0.5">
                <div className="h-1.5 w-0.5 rounded-sm bg-foreground/40" />
                <div className="h-2 w-0.5 rounded-sm bg-foreground/40" />
                <div className="h-2.5 w-0.5 rounded-sm bg-foreground/40" />
                <div className="h-3 w-0.5 rounded-sm bg-foreground/40" />
              </div>
              <div className="ml-0.5 h-2 w-4 rounded-sm border border-foreground/40">
                <div className="m-px h-1 w-2.5 rounded-sm bg-foreground/40" />
              </div>
            </div>
          </div>

          {/* App header */}
          <div className="border-b border-border/60 px-4 pb-2">
            <div className="text-[11px] font-semibold text-foreground">Monorepo Template</div>
          </div>

          {/* Sign-in form */}
          <div className="flex-1 p-4">
            <div className="mb-3 text-center">
              <div className="text-[13px] font-bold text-foreground">Sign In</div>
              <div className="mt-0.5 text-[7px] text-muted-foreground">Enter your credentials</div>
            </div>

            {/* Email field */}
            <div className="mb-2">
              <div className="mb-0.5 text-[7px] font-medium text-foreground">Email</div>
              <div className="rounded-md border border-border/60 bg-muted/30 px-2 py-1.5">
                <span className="text-[8px] text-muted-foreground/50">you@example.com</span>
              </div>
            </div>

            {/* Password field */}
            <div className="mb-3">
              <div className="mb-0.5 text-[7px] font-medium text-foreground">Password</div>
              <div className="rounded-md border border-border/60 bg-muted/30 px-2 py-1.5">
                <span className="text-[8px] text-muted-foreground/50">Your password</span>
              </div>
            </div>

            {/* Sign In button */}
            <div className="rounded-md bg-primary px-3 py-1.5 text-center">
              <span className="text-[9px] font-medium text-primary-foreground">Sign In</span>
            </div>

            {/* Divider */}
            <div className="my-3 flex items-center gap-2">
              <div className="h-px flex-1 bg-border/40" />
              <span className="text-[7px] text-muted-foreground">Or continue with</span>
              <div className="h-px flex-1 bg-border/40" />
            </div>

            {/* OAuth buttons */}
            <div className="grid grid-cols-3 gap-1.5">
              {(["Google", "Apple", "GitHub"] as const).map((provider) => (
                <div
                  key={provider}
                  className="rounded-md border border-border/60 py-1.5 text-center"
                >
                  <span className="text-[8px] font-medium text-muted-foreground">{provider}</span>
                </div>
              ))}
            </div>

            {/* Sign up link */}
            <div className="mt-3 text-center">
              <span className="text-[7px] text-muted-foreground">
                Don&apos;t have an account?{" "}
                <span className="text-foreground underline">Sign Up</span>
              </span>
            </div>
          </div>

          {/* Home indicator */}
          <div className="mt-auto flex justify-center pb-2 pt-3" aria-hidden="true">
            <div className="h-1 w-24 rounded-full bg-foreground/15" />
          </div>
        </div>
      </div>
    </div>
  );
}
