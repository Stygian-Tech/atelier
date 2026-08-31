import type { APIRoute } from "astro";

import {
  isIndexableEnvironment,
  resolveAtelierOrigin,
} from "../../../../infra/web/release-environment.mjs";

export const prerender = true;

export const GET: APIRoute = () => {
  const origin = resolveAtelierOrigin("ATELIER_MARKETING_ORIGIN", "http://localhost:4321");
  const body = isIndexableEnvironment()
    ? `User-agent: *\nAllow: /\nDisallow: /beta-thanks/\nSitemap: ${origin}/sitemap.xml\n`
    : "User-agent: *\nDisallow: /\n";
  return new Response(body, { headers: { "Content-Type": "text/plain; charset=utf-8" } });
};
