import { defineConfig } from "astro/config";

export default defineConfig({
  site: process.env.ATELIER_MARKETING_ORIGIN ?? "http://localhost:4321",
  output: "static",
  build: { format: "directory" },
});
