import { fileURLToPath } from "node:url";
import { initOpenNextCloudflareForDev } from "@opennextjs/cloudflare";
import { createMDX } from "fumadocs-mdx/next";

const withMDX = createMDX();
const workspaceRoot = fileURLToPath(new URL("../..", import.meta.url));

initOpenNextCloudflareForDev();

/** @type {import('next').NextConfig} */
const config = {
  reactStrictMode: true,
  turbopack: { root: workspaceRoot },
  outputFileTracingRoot: workspaceRoot,
  async redirects() {
    return [
      {
        source: "/docs/autonomous-agents",
        destination: "/docs/agent-teams",
        permanent: true,
      },
      {
        source: "/docs/guides/agent-teams",
        destination: "/docs/agent-teams/setup",
        permanent: true,
      },
      {
        source: "/docs/agent-teams/two-agent-team",
        destination: "/docs/agent-teams/setup",
        permanent: true,
      },
      {
        source: "/docs/hermes",
        destination: "/docs/agent-teams",
        permanent: true,
      },
      {
        source: "/docs/concepts/memory",
        destination: "/docs/concepts/context-management",
        permanent: true,
      },
      {
        source: "/docs/skills/woostack-ask",
        destination: "/docs/concepts/utilities",
        permanent: true,
      },
      {
        source: "/docs/skills/woostack-dream",
        destination: "/docs/concepts/context-management",
        permanent: true,
      },
    ];
  },
};

export default withMDX(config);
