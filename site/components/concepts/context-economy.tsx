/**
 * Context-economy hero for the Core concepts page.
 *
 * Three mechanisms feed one scarce resource: the agent's working context.
 * Scoped recall, shell scripts, and subagents each keep heavy work out of the
 * main context window. Pure inline SVG — no dependencies. Colors come from the
 * Fumadocs theme tokens (`--color-fd-*`) so it adapts to light and dark with no
 * JavaScript.
 */
export function ContextEconomy() {
  const sources = [
    { y: 24, title: 'Scoped recall', sub: 'load the few notes that match' },
    { y: 116, title: 'Scripts compute', sub: 'read the small output' },
    { y: 208, title: 'Subagents isolate', sub: 'return a compact result' },
  ];

  return (
    <figure className="my-6">
      <svg
        viewBox="0 0 760 300"
        role="img"
        aria-label="Three mechanisms — scoped recall, shell scripts, and subagents — keeping the agent's working context small."
        style={{ width: '100%', height: 'auto', fontFamily: 'ui-sans-serif, system-ui, sans-serif' }}
      >
        <defs>
          <marker
            id="ce-arrow"
            viewBox="0 0 10 10"
            refX="9"
            refY="5"
            markerWidth="7"
            markerHeight="7"
            orient="auto-start-reverse"
          >
            <path d="M0,0 L10,5 L0,10 z" fill="var(--color-fd-muted-foreground)" />
          </marker>
        </defs>

        {/* source nodes */}
        {sources.map((s) => (
          <g key={s.title}>
            <rect
              x="20"
              y={s.y}
              width="250"
              height="68"
              rx="10"
              fill="var(--color-fd-card)"
              stroke="var(--color-fd-border)"
              strokeWidth="1.5"
            />
            <text x="40" y={s.y + 30} fontSize="17" fontWeight="600" fill="var(--color-fd-foreground)">
              {s.title}
            </text>
            <text x="40" y={s.y + 50} fontSize="13" fill="var(--color-fd-muted-foreground)">
              {s.sub}
            </text>
            {/* connector into the core */}
            <path
              d={`M270,${s.y + 34} C370,${s.y + 34} 410,150 490,150`}
              fill="none"
              stroke="var(--color-fd-muted-foreground)"
              strokeWidth="1.5"
              markerEnd="url(#ce-arrow)"
            />
          </g>
        ))}

        {/* the scarce resource */}
        <rect
          x="492"
          y="104"
          width="248"
          height="92"
          rx="12"
          fill="var(--color-fd-primary)"
          stroke="var(--color-fd-primary)"
          strokeWidth="1.5"
        />
        <text
          x="616"
          y="142"
          fontSize="18"
          fontWeight="700"
          textAnchor="middle"
          fill="var(--color-fd-primary-foreground)"
        >
          Small working
        </text>
        <text
          x="616"
          y="166"
          fontSize="18"
          fontWeight="700"
          textAnchor="middle"
          fill="var(--color-fd-primary-foreground)"
        >
          context
        </text>
      </svg>
      <figcaption
        style={{ textAlign: 'center', fontSize: '0.85rem', color: 'var(--color-fd-muted-foreground)', marginTop: '0.5rem' }}
      >
        Context economy: three mechanisms, one scarce resource.
      </figcaption>
    </figure>
  );
}

export default ContextEconomy;
