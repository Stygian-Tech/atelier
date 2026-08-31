import type { Metadata } from "next";
import type { ReactNode } from "react";

import { getProductOrigins, isIndexableProductOrigin } from "@stygian/atelier-web-ui";

import "./globals.css";

const origin = getProductOrigins().calendar;
const indexable = isIndexableProductOrigin(origin);
const title = "Atelier Calendar — Calendar model foundation preview";
const description = "A fixture preview of the planned lossless ICS and provider model; parsing, sync, and writeback are not connected yet.";

export const metadata: Metadata = {
  metadataBase: new URL(origin),
  applicationName: "Atelier Calendar",
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
