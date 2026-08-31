import type { NextConfig } from "next";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const appDir = dirname(fileURLToPath(import.meta.url));

const nextConfig: NextConfig = {
  typedRoutes: true,
  transpilePackages: ["@stygian/atelier-web-ui", "@stygian/atelier-design-system", "@stygian/markdown-editor"],
  turbopack: { root: resolve(appDir, "../../..") },
};

export default nextConfig;
