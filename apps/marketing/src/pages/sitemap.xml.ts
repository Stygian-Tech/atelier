import type { APIRoute } from "astro";

import { resolveAtelierOrigin } from "../../../../infra/web/release-environment.mjs";

export const prerender = true;

export const GET: APIRoute = () => {
  const origin = resolveAtelierOrigin("ATELIER_MARKETING_ORIGIN", "http://localhost:4321");
  const body = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>${origin}/</loc><changefreq>weekly</changefreq><priority>1.0</priority></url>
</urlset>
`;
  return new Response(body, { headers: { "Content-Type": "application/xml; charset=utf-8" } });
};
