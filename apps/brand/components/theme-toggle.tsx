"use client";

import { Moon, Sun } from "lucide-react";
import { useTheme } from "next-themes";
import { useEffect, useState } from "react";

/**
 * ThemeToggle toggles between light and dark mode using the next-themes hook.
 * The mounted guard prevents a hydration mismatch: before the client has
 * resolved which theme is active we render a same-size placeholder, so the
 * server HTML and the first client render are identical.
 */
export function ThemeToggle() {
  const [mounted, setMounted] = useState(false);
  const { theme, setTheme } = useTheme();

  useEffect(() => setMounted(true), []);

  if (!mounted) {
    return <div className="size-9" />;
  }

  return (
    <button
      type="button"
      aria-label="Toggle theme"
      className="flex size-9 items-center justify-center rounded-md border border-border bg-background text-foreground hover:bg-accent"
      onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
    >
      {theme === "dark" ? (
        <Sun className="size-4" />
      ) : (
        <Moon className="size-4" />
      )}
    </button>
  );
}
