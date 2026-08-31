import type { Metadata } from "next";
import { getProductOrigins, isIndexableProductOrigin } from "@stygian/atelier-web-ui";
import { EnvironmentBanner } from "@/components/shared/EnvironmentBanner";
import { getAppEnv, shouldShowEnvironmentBanner } from "@/lib/appEnv";
import "./globals.css";

const origin = getProductOrigins().mail;
const indexable = isIndexableProductOrigin(origin);
const title = "Atelier Mail — Foundation preview";
const description = "A transparent fixture preview of Atelier Mail; provider sync, delivery, and mutations are not connected yet.";

export const metadata: Metadata = {
  metadataBase: new URL(origin),
  applicationName: "Atelier Mail",
  title,
  description,
  alternates: { canonical: "/" },
  robots: { index: indexable, follow: indexable },
  openGraph: { title, description, url: "/", siteName: "Atelier Mail", type: "website", locale: "en_US" },
  twitter: { card: "summary", title, description },
};

const themeScript = `
(function() {
  try {
    var theme = window.localStorage.getItem("atelier-mail-theme");
    if (theme !== "light" && theme !== "dark") {
      theme = window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
    }
    document.documentElement.classList.toggle("dark", theme === "dark");
    document.documentElement.dataset.theme = theme;
  } catch (_) {}
})();
`;

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  const appEnv = getAppEnv();
  const bannerHeight = shouldShowEnvironmentBanner(appEnv) ? "2.0625rem" : "0px";

  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <script dangerouslySetInnerHTML={{ __html: themeScript }} />
      </head>
      <body style={{ "--environment-banner-height": bannerHeight } as React.CSSProperties}>
        <EnvironmentBanner appEnv={appEnv} />
        {children}
      </body>
    </html>
  );
}
