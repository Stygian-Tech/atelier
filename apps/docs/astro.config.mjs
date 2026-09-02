import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";

import {
  isIndexableEnvironment,
  resolveAtelierOrigin,
} from "../../infra/web/release-environment.mjs";

const indexable = isIndexableEnvironment();

export default defineConfig({
  site: resolveAtelierOrigin("ATELIER_DOCS_ORIGIN", "http://localhost:4322"),
  output: "static",
  integrations: [
    starlight({
      title: "Atelier Docs",
      description: "Product, protocol, and operations documentation for Atelier.",
      social: [{ icon: "github", label: "GitHub", href: "https://github.com/Stygian-Tech/atelier" }],
      editLink: { baseUrl: "https://github.com/Stygian-Tech/atelier/edit/dev/apps/docs/" },
      customCss: ["./src/styles/custom.css"],
      head: [
        {
          tag: "meta",
          attrs: {
            name: "robots",
            content: indexable ? "index, follow" : "noindex, nofollow, noarchive",
          },
        },
      ],
      sidebar: [
        { slug: "index" },
        { label: "Concepts", items: [{ autogenerate: { directory: "concepts" } }] },
        { label: "Products", items: [{ autogenerate: { directory: "products" } }] },
        { label: "Developers", items: [{ autogenerate: { directory: "developers" } }] },
        { label: "Operations", items: [{ autogenerate: { directory: "operations" } }] },
        { label: "Legal", items: [{ autogenerate: { directory: "legal" } }] },
        { label: "Support", items: [{ autogenerate: { directory: "support" } }] },
      ],
    }),
  ],
});
