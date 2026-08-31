import type { MetadataRoute } from "next";

import { getProductOrigins, isIndexableProductOrigin } from "@stygian/atelier-web-ui";

export default function robots(): MetadataRoute.Robots {
  const origin = getProductOrigins().calendar;
  const indexable = isIndexableProductOrigin(origin);
  return {
    rules: { userAgent: "*", ...(indexable ? { allow: "/" } : { disallow: "/" }) },
    sitemap: `${origin}/sitemap.xml`,
    ...(indexable ? { host: origin } : {}),
  };
}
