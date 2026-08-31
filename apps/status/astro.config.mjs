import { defineConfig } from "astro/config";

export default defineConfig({
  site: process.env.ATELIER_STATUS_ORIGIN ?? "http://localhost:4323",
  output: "static",
});
