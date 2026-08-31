import type { NextConfig } from "next";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import {
  createNextSecurityHeaders,
  getAtelierEnvironment,
  resolveProductOriginVariables,
} from "../../../infra/web/release-environment.mjs";

const appDir = dirname(fileURLToPath(import.meta.url));
const workspaceRoot = resolve(appDir, "../../..");
const atelierEnvironment = getAtelierEnvironment();
const productOriginEnvironment = resolveProductOriginVariables(process.env);

const nextConfig: NextConfig = {
  poweredByHeader: false,
  env: {
    ...productOriginEnvironment,
    NEXT_PUBLIC_APP_ENV:
      atelierEnvironment === "production"
        ? "production"
        : atelierEnvironment === "development"
          ? "dev"
          : "local",
  },
  typedRoutes: true,
  devIndicators: false,
  transpilePackages: ["@stygian/atelier-design-system", "@stygian/atelier-lexicons", "@stygian/atelier-web-ui", "@stygian/markdown-editor"],
  turbopack: {
    root: workspaceRoot,
  },
  async headers() {
    return [{ source: "/(.*)", headers: createNextSecurityHeaders() }];
  },
};

export default nextConfig;
