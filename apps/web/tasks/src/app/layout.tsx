import type { Metadata } from "next";
import type { ReactNode } from "react";

import { getProductOrigins, isIndexableProductOrigin } from "@stygian/atelier-web-ui";

import "./globals.css";

const origin = getProductOrigins().tasks;
const indexable = isIndexableProductOrigin(origin);
const title = "Atelier Tasks — Collaborative task foundation preview";
const description = "A local fixture of Atelier Tasks; persistence, offline queues, collaboration, and PDS mutations are not connected yet.";

export const metadata: Metadata = {
  metadataBase: new URL(origin),
  applicationName: "Atelier Tasks",
  title,
  description,
  alternates: { canonical: "/" },
  robots: { index: indexable, follow: indexable },
  openGraph: { title, description, url: "/", siteName: "Atelier", type: "website", locale: "en_US" },
  twitter: { card: "summary", title, description },
};

export default function RootLayout({ children }: Readonly<{ children: ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
