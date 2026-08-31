import { defineConfig } from "astro/config";

import { resolveAtelierOrigin } from "../../infra/web/release-environment.mjs";

export default defineConfig({
  site: resolveAtelierOrigin("ATELIER_MARKETING_ORIGIN", "http://localhost:4321"),
  output: "static",
  build: { format: "directory" },
});
