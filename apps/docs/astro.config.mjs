import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";

export default defineConfig({
  site: process.env.ATELIER_DOCS_ORIGIN ?? "http://localhost:4322",
  output: "static",
  integrations: [
    starlight({
      title: "Atelier Docs",
      description: "Product, protocol, and operations documentation for Atelier.",
      social: [{ icon: "github", label: "GitHub", href: "https://github.com/Stygian-Tech/atelier" }],
      editLink: { baseUrl: "https://github.com/Stygian-Tech/atelier/edit/dev/apps/docs/" },
      customCss: ["./src/styles/custom.css"],
      sidebar: [
        { slug: "index" },
        { label: "Concepts", autogenerate: { directory: "concepts" } },
        { label: "Products", autogenerate: { directory: "products" } },
        { label: "Developers", autogenerate: { directory: "developers" } },
        { label: "Operations", autogenerate: { directory: "operations" } },
        { label: "Legal", autogenerate: { directory: "legal" } },
        { label: "Support", autogenerate: { directory: "support" } },
      ],
    }),
  ],
});
