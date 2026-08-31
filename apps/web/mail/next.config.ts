import type { NextConfig } from "next";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const appDir = dirname(fileURLToPath(import.meta.url));
const workspaceRoot = resolve(appDir, "../../..");

const nextConfig: NextConfig = {
  typedRoutes: true,
  devIndicators: false,
  transpilePackages: ["@stygian/atelier-design-system", "@stygian/atelier-lexicons", "@stygian/markdown-editor"],
  turbopack: {
    root: workspaceRoot,
  },
};

export default nextConfig;
