import { environmentBannerMessage, shouldShowEnvironmentBanner, type AppEnv } from "@/lib/appEnv";

export function EnvironmentBanner({ appEnv }: { appEnv: AppEnv }) {
  if (!shouldShowEnvironmentBanner(appEnv)) return null;

  return (
    <div
      role="status"
      aria-label={`${appEnv} environment`}
      className="border-b border-yellow-500/60 bg-yellow-300/55 px-4 py-2 text-center text-xs font-semibold text-yellow-950 shadow-sm backdrop-blur-md"
    >
      {environmentBannerMessage(appEnv)} - development data and relaxed limits
    </div>
  );
}
