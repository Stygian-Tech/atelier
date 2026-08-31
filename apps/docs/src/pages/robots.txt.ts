import type { APIRoute } from "astro";

import {
  isIndexableEnvironment,
  resolveAtelierOrigin,
} from "../../../../infra/web/release-environment.mjs";

export const prerender = true;

export const GET: APIRoute = () => {
  const origin = resolveAtelierOrigin("ATELIER_DOCS_ORIGIN", "http://localhost:4322");
  const body = isIndexableEnvironment()
    ? `User-agent: *\nAllow: /\nSitemap: ${origin}/sitemap-index.xml\n`
    : "User-agent: *\nDisallow: /\n";
  return new Response(body, { headers: { "Content-Type": "text/plain; charset=utf-8" } });
};
