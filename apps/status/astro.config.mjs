import { defineConfig } from "astro/config";

import { resolveAtelierOrigin } from "../../infra/web/release-environment.mjs";

export default defineConfig({
  site: resolveAtelierOrigin("ATELIER_STATUS_ORIGIN", "http://localhost:4323"),
  output: "static",
});
