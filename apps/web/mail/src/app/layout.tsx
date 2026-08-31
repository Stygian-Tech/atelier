import type { Metadata } from "next";
import { EnvironmentBanner } from "@/components/shared/EnvironmentBanner";
import { getAppEnv, shouldShowEnvironmentBanner } from "@/lib/appEnv";
import "./globals.css";

export const metadata: Metadata = {
  title: "Atelier Mail",
  description: "Provider-neutral mail for Atelier, powered by ATProto identity.",
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
