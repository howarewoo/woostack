import { HomeLayout } from "fumadocs-ui/layouts/home";
import { baseOptions } from "@/lib/layout.shared";
import type { Metadata } from "next";

const description =
  "Skills for AI coding assistants to refine a goal, plan the work, and make reviewable changes.";

export const metadata: Metadata = {
  title: "WooStack | Skills and guidance for coding agents",
  description,
  openGraph: {
    title: "Skills and guidance for coding agents",
    description,
    siteName: "WooStack",
    images: [{ url: "/opengraph-image", width: 1200, height: 630, alt: "WooStack logo" }],
  },
  twitter: { card: "summary_large_image" },
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
