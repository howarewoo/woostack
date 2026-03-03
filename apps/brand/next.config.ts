import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactCompiler: true,
  transpilePackages: ["@infrastructure/ui", "@infrastructure/ui-web"],
};

export default nextConfig;
