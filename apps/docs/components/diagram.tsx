import type { ReactNode } from "react";

type DiagramProps = {
  id: string;
  title: string;
  description: string;
  caption: string;
  height: number;
  children: ReactNode;
};

// Callers supply a page-unique id for SVG markers and accessible names.
// Static SVG keeps diagrams visible without hydration or a diagram runtime.
export function Diagram({ id, title, description, caption, height, children }: DiagramProps) {
  return (
    <figure className="not-prose my-8 min-w-0 rounded-xl border border-fd-border bg-fd-card">
      <div className="px-5 pt-5 sm:px-6">
        <h3 id={`${id}-heading`} className="text-lg font-semibold text-fd-foreground">
          {title}
        </h3>
        <p className="mt-1 text-xs text-fd-muted-foreground">
          Follow the arrows. On narrow screens, scroll horizontally to see the full diagram.
        </p>
      </div>
      <div
        role="region"
        aria-labelledby={`${id}-heading`}
        tabIndex={0}
        className="overflow-x-auto rounded-lg focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-fd-primary"
      >
        <svg
          viewBox={`0 0 760 ${height}`}
          className="block h-auto w-full min-w-[640px] text-fd-muted-foreground"
          role="img"
          aria-labelledby={`${id}-title`}
          aria-describedby={`${id}-description`}
        >
          <title id={`${id}-title`}>{title}</title>
          <desc id={`${id}-description`}>{description}</desc>
          <defs>
            <marker
              id={`${id}-arrow`}
              viewBox="0 0 10 10"
              refX="9"
              refY="5"
              markerWidth="7"
              markerHeight="7"
              orient="auto-start-reverse"
            >
              <path d="M 0 0 L 10 5 L 0 10 Z" fill="currentColor" />
            </marker>
          </defs>
          {children}
        </svg>
      </div>
      <figcaption className="border-t border-fd-border px-5 py-4 text-sm leading-relaxed text-fd-muted-foreground sm:px-6">
        {caption}
        <details className="mt-3">
          <summary className="cursor-pointer text-fd-foreground">Read text description</summary>
          <p className="mt-2">{description}</p>
        </details>
      </figcaption>
    </figure>
  );
}

export function Node({
  x, y, width = 200, height = 66, title, lines = [], accent = false,
}: {
  x: number;
  y: number;
  width?: number;
  height?: number;
  title: string;
  lines?: string[];
  accent?: boolean;
}) {
  return (
    <g transform={`translate(${x} ${y})`}>
      <rect
        width={width}
        height={height}
        rx="6"
        strokeWidth="1.5"
        className={accent ? "fill-fd-accent stroke-fd-primary" : "fill-fd-card stroke-fd-muted-foreground/60"}
      />
      <text x={width / 2} y="26" textAnchor="middle" fontSize="15" fontWeight="600" className="fill-fd-foreground">
        {title}
      </text>
      {lines.map((line, index) => (
        <text key={line} x={width / 2} y={47 + index * 18} textAnchor="middle" fontSize="13" className="fill-fd-muted-foreground">
          {line}
        </text>
      ))}
    </g>
  );
}

export function Group({
  x = 24, y, width = 712, height, title,
}: {
  x?: number;
  y: number;
  width?: number;
  height: number;
  title: string;
}) {
  return (
    <g>
      <rect x={x} y={y} width={width} height={height} rx="10" strokeDasharray="6 5" className="fill-fd-muted/30 stroke-fd-muted-foreground/50" />
      <text x={x + 18} y={y + 27} fontSize="13" fontWeight="600" className="fill-fd-muted-foreground">{title}</text>
    </g>
  );
}

export function Label({ x, y, children }: { x: number; y: number; children: ReactNode }) {
  return <text x={x} y={y} textAnchor="middle" fontSize="13" stroke="var(--color-fd-card)" strokeWidth="5" paintOrder="stroke" className="fill-fd-muted-foreground">{children}</text>;
}

export function Connectors({ id, children }: { id: string; children: ReactNode }) {
  return (
    <g fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round" markerEnd={`url(#${id}-arrow)`}>
      {children}
    </g>
  );
}
