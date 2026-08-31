import type { NextConfig } from "next";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { createNextSecurityHeaders, resolveProductOriginVariables } from "../../../infra/web/release-environment.mjs";

const appDir = dirname(fileURLToPath(import.meta.url));
const productOriginEnvironment = resolveProductOriginVariables(process.env);

const nextConfig: NextConfig = {
  poweredByHeader: false,
  env: productOriginEnvironment,
  typedRoutes: true,
  transpilePackages: ["@stygian/atelier-web-ui", "@stygian/atelier-design-system", "@stygian/markdown-editor"],
  turbopack: { root: resolve(appDir, "../../..") },
  async headers() {
    return [{ source: "/(.*)", headers: createNextSecurityHeaders() }];
  },
};

export default nextConfig;
