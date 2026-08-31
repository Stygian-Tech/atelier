import type { MetadataRoute } from "next";

import { getProductOrigins } from "@stygian/atelier-web-ui";

export default function sitemap(): MetadataRoute.Sitemap {
  return [{ url: getProductOrigins().tasks, changeFrequency: "weekly", priority: 1 }];
}
