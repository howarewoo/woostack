import type { BaseLayoutProps } from "fumadocs-ui/layouts/shared";
import { Brand } from "@/components/brand";
import { ThemeSwitch } from "@/components/theme-switch";
import { gitConfig } from "./shared";

export function baseOptions(): BaseLayoutProps {
  return {
    nav: {
      title: <Brand />,
    },
    themeSwitch: { component: <ThemeSwitch /> },
    githubUrl: `https://github.com/${gitConfig.user}/${gitConfig.repo}`,
  };
}
