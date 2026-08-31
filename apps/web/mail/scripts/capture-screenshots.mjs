import { chromium } from "playwright";

const browser = await chromium.launch({ headless: true });

try {
  const desktop = await browser.newPage({
    viewport: { width: 1440, height: 1000 },
    deviceScaleFactor: 1,
  });
  await desktop.goto("http://localhost:3000", { waitUntil: "networkidle" });
  await desktop.screenshot({
    path: "../../.codex-desktop.png",
    fullPage: true,
  });

  await desktop.getByLabel("Switch to dark mode").click();
  await desktop.waitForTimeout(150);
  await desktop.screenshot({
    path: "../../.codex-desktop-dark.png",
    fullPage: true,
  });

  const mobile = await browser.newPage({
    viewport: { width: 390, height: 844 },
    isMobile: true,
  });
  await mobile.goto("http://localhost:3000", { waitUntil: "networkidle" });
  await mobile.screenshot({
    path: "../../.codex-mobile.png",
    fullPage: true,
  });

  const result = {
    desktopTitle: await desktop.locator("text=Atelier Mail").first().isVisible(),
    threadVisible: await desktop
      .locator("text=Permissioned KV model for linked mail threads")
      .first()
      .isVisible(),
    mobileSearch: await mobile.locator('input[aria-label="Search"]').isVisible(),
    darkMode: await desktop.locator("html.dark").count(),
  };

  console.log(JSON.stringify(result, null, 2));
} finally {
  await browser.close();
}
