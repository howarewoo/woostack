import { HomeLayout } from "fumadocs-ui/layouts/home";
import { baseOptions } from "@/lib/layout.shared";
import type { Metadata } from "next";

export const metadata: Metadata = {
  title: "WooStack | Skills and guidance for coding agents",
};

export default function Layout({ children }: LayoutProps<"/">) {
  return (
    <HomeLayout
      {...baseOptions()}
      className="home-shell"
      links={[
        { text: "Documentation", url: "/docs" },
        { text: "Workflow", url: "/#workflow", active: "none" },
        { text: "GitHub", url: "https://github.com/howarewoo/woostack", external: true },
      ]}
      githubUrl={undefined}
    >
      {children}
    </HomeLayout>
  );
}
