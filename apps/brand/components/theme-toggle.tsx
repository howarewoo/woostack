"use client";

import { Button } from "@infrastructure/ui-web";
import { Moon, Sun } from "lucide-react";
import { useTheme } from "next-themes";
import { useSyncExternalStore } from "react";

const emptySubscribe = () => () => {};
const getSnapshot = () => true;
const getServerSnapshot = () => false;

/**
 * Returns true once the component has mounted on the client.
 * Uses useSyncExternalStore so the React Compiler can optimise the component
 * (avoids the setState-in-useEffect pattern that the compiler cannot handle).
 */
function useIsMounted() {
  return useSyncExternalStore(emptySubscribe, getSnapshot, getServerSnapshot);
}

/**
 * ThemeToggle toggles between light and dark mode using the next-themes hook.
 * The mounted guard prevents a hydration mismatch: before the client has
 * resolved which theme is active we render a same-size placeholder, so the
 * server HTML and the first client render are identical.
 */
export function ThemeToggle() {
  const mounted = useIsMounted();
  const { resolvedTheme, setTheme } = useTheme();

  if (!mounted) {
    return <div className="size-9" />;
  }

  return (
    <Button
      variant="outline"
      size="icon"
      aria-label="Toggle theme"
      onClick={() => setTheme(resolvedTheme === "dark" ? "light" : "dark")}
    >
      {resolvedTheme === "dark" ? <Sun className="size-4" /> : <Moon className="size-4" />}
    </Button>
  );
}
