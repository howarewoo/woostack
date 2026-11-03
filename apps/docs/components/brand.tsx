export function WMark({ className }: { className?: string }) {
  return (
    <svg viewBox="0 0 32 32" aria-hidden="true" className={className} fill="currentColor">
      <path
        d="M1 3h7l4 17 4-13h5l4 13 3-17h7l-7 27h-6l-4-12-4 12H8z"
        transform="translate(-1 0) scale(.94 1)"
      />
    </svg>
  );
}

export function Brand() {
  return (
    <span className="site-brand">
      <WMark />
      <span>WOOSTACK</span>
    </span>
  );
}
