export type AppEnv = "prod" | "dev" | "local" | "test" | (string & {});

export function normalizeAppEnv(raw: string): AppEnv {
  const value = raw.trim().toLowerCase();
  if (value === "production") return "prod";
  return value as AppEnv;
}

export function getAppEnv(): AppEnv {
  const raw = process.env.NEXT_PUBLIC_APP_ENV?.trim() || process.env.APP_ENV?.trim() || "";
  if (raw) return normalizeAppEnv(raw);
  if (process.env.NODE_ENV === "development") return "local";
  if (process.env.VERCEL_ENV === "production") return "prod";
  return "dev";
}

export function shouldShowEnvironmentBanner(appEnv: AppEnv): boolean {
  return appEnv === "local" || appEnv === "dev" || appEnv === "test";
}

export function shouldShowDebugChrome(appEnv: AppEnv): boolean {
  return shouldShowEnvironmentBanner(appEnv);
}

export function environmentBannerMessage(appEnv: AppEnv): string {
  switch (appEnv) {
    case "local":
      return "Local Environment";
    case "dev":
      return "Development Environment";
    case "test":
      return "Testing Environment";
    default:
      return "";
  }
}
