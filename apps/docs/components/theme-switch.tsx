"use client";

import { useSyncExternalStore } from "react";
import { flushSync } from "react-dom";
import { useTheme } from "fumadocs-ui/provider/base";
import { Airplay, Moon, Sun } from "lucide-react";

const choices = [
  ["light", "Light", Sun],
  ["dark", "Dark", Moon],
  ["system", "System", Airplay],
] as const;
const subscribe = () => () => {};

export function ThemeSwitch() {
  const { theme, setTheme } = useTheme();
  const mounted = useSyncExternalStore(
    subscribe,
    () => true,
    () => false,
  );
  const changeTheme = (value: string) => {
    if (document.startViewTransition) {
      document.startViewTransition(() => flushSync(() => setTheme(value)));
    } else {
      setTheme(value);
    }
  };
  return (
    <div
      role="group"
      aria-label="Theme"
      className="inline-flex items-center rounded-full border p-1 overflow-hidden *:rounded-full"
      data-theme-toggle=""
    >
      {choices.map(([value, label, Icon]) => (
        <button
          key={value}
          type="button"
          aria-label={label}
          aria-pressed={mounted ? theme === value : undefined}
          className={`size-6.5 p-1.5 ${mounted && theme === value ? "bg-fd-accent text-fd-accent-foreground" : "text-fd-muted-foreground"}`}
          onClick={() => changeTheme(value)}
        >
          <Icon aria-hidden="true" className="size-full" fill="currentColor" />
        </button>
      ))}
    </div>
  );
}
