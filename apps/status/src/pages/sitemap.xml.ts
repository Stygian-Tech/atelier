import type { APIRoute } from "astro";

import { resolveAtelierOrigin } from "../../../../infra/web/release-environment.mjs";

export const prerender = true;

export const GET: APIRoute = () => {
  const origin = resolveAtelierOrigin("ATELIER_STATUS_ORIGIN", "http://localhost:4323");
  const body = `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url><loc>${origin}/</loc><changefreq>daily</changefreq><priority>0.6</priority></url>
</urlset>
`;
  return new Response(body, { headers: { "Content-Type": "application/xml; charset=utf-8" } });
};
