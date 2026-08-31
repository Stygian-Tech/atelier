export type AtelierEnvironment = "local" | "development" | "production";

export function getAtelierEnvironment(raw?: string): AtelierEnvironment;
export function resolveAtelierOrigin(
  name: string,
  localFallback: string,
  env?: Record<string, string | undefined>,
): string;
export function assertProductOrigins(env?: Record<string, string | undefined>): void;
export function resolveProductOriginVariables(
  env?: Record<string, string | undefined>,
): Record<string, string>;
export function isIndexableEnvironment(env?: Record<string, string | undefined>): boolean;
export function createNextSecurityHeaders(): Array<{ key: string; value: string }>;
