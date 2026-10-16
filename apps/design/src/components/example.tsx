import type { HTMLAttributes, ImgHTMLAttributes, AnchorHTMLAttributes } from "react";
import inventory from "@/inventory.json";

export function ExampleWrapper({ className = "", ...props }: HTMLAttributes<HTMLDivElement>) {
  return <div className={`grid items-start gap-6 ${className}`} {...props} />;
}

export function Example({
  title,
  children,
  className = "",
  containerClassName = "",
  ...props
}: HTMLAttributes<HTMLDivElement> & { containerClassName?: string }) {
  return (
    <section className={`min-w-0 space-y-4 rounded-lg border p-4 ${containerClassName}`} {...props}>
      {title && <h3 className="font-medium">{title}</h3>}
      <div className={`flex min-w-0 flex-col items-start gap-4 ${className}`}>{children}</div>
    </section>
  );
}

// Browser-native replacements for framework-only wrappers in upstream examples.
export function Image({
  fill: _fill,
  priority: _priority,
  unoptimized: _unoptimized,
  ...props
}: ImgHTMLAttributes<HTMLImageElement> & {
  fill?: boolean;
  priority?: boolean;
  unoptimized?: boolean;
}) {
  return <img {...props} />;
}

export function Link({ href, ...props }: AnchorHTMLAttributes<HTMLAnchorElement>) {
  return <a href={href?.startsWith("/docs") ? inventory.upstream.catalog : href} {...props} />;
}
