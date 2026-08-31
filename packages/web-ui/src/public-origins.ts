export type AtelierEnvironment = "local" | "development" | "production";

export interface ProductOrigins {
  home: string;
  notes: string;
  mail: string;
  calendar: string;
  tasks: string;
}

interface PublicOriginEnvironment {
  ATELIER_ENV?: string;
  NEXT_PUBLIC_HOME_URL?: string;
  NEXT_PUBLIC_NOTES_URL?: string;
  NEXT_PUBLIC_MAIL_URL?: string;
  NEXT_PUBLIC_CALENDAR_URL?: string;
  NEXT_PUBLIC_TASKS_URL?: string;
}

const expectedOrigins = {
  development: {
    home: "https://home.testing.atelier.diy",
    notes: "https://notes.testing.atelier.diy",
    mail: "https://mail.testing.atelier.diy",
    calendar: "https://calendar.testing.atelier.diy",
    tasks: "https://tasks.testing.atelier.diy",
  },
  production: {
    home: "https://home.atelier.diy",
    notes: "https://notes.atelier.diy",
    mail: "https://mail.atelier.diy",
    calendar: "https://calendar.atelier.diy",
    tasks: "https://tasks.atelier.diy",
  },
} satisfies Record<Exclude<AtelierEnvironment, "local">, ProductOrigins>;

export function parseAtelierEnvironment(raw?: string): AtelierEnvironment {
  const value = raw?.trim().toLowerCase();
  if (!value || value === "local") return "local";
  if (value === "development" || value === "production") return value;
  throw new Error(`Unsupported ATELIER_ENV: ${raw}`);
}

function normalizedOrigin(value: string, label: string) {
  let url: URL;
  try {
    url = new URL(value);
  } catch {
    throw new Error(`${label} must be an absolute HTTP(S) origin`);
  }
  if (
    (url.protocol !== "http:" && url.protocol !== "https:") ||
    url.pathname !== "/" ||
    url.search ||
    url.hash ||
    url.username ||
    url.password
  ) {
    throw new Error(`${label} must contain only an absolute HTTP(S) origin`);
  }
  return url.origin;
}

export function resolveProductOrigins(env: PublicOriginEnvironment): ProductOrigins {
  const environment = parseAtelierEnvironment(env.ATELIER_ENV);
  const configured = {
    home: env.NEXT_PUBLIC_HOME_URL,
    notes: env.NEXT_PUBLIC_NOTES_URL,
    mail: env.NEXT_PUBLIC_MAIL_URL,
    calendar: env.NEXT_PUBLIC_CALENDAR_URL,
    tasks: env.NEXT_PUBLIC_TASKS_URL,
  };

  return Object.fromEntries(
    (["home", "notes", "mail", "calendar", "tasks"] as const).map((product) => {
      const variable = `NEXT_PUBLIC_${product.toUpperCase()}_URL`;
      const value = configured[product]?.trim();
      if (!value) {
        throw new Error(`${variable} is required when ATELIER_ENV=${environment}`);
      }
      const origin = normalizedOrigin(value, variable);
      if (environment !== "local" && origin !== expectedOrigins[environment][product]) {
        throw new Error(
          `${variable} must be ${expectedOrigins[environment][product]} when ATELIER_ENV=${environment}`,
        );
      }
      return [product, origin];
    }),
  ) as unknown as ProductOrigins;
}

export function getProductOrigins(): ProductOrigins {
  return resolveProductOrigins({
    ATELIER_ENV: process.env.ATELIER_ENV,
    NEXT_PUBLIC_HOME_URL: process.env.NEXT_PUBLIC_HOME_URL,
    NEXT_PUBLIC_NOTES_URL: process.env.NEXT_PUBLIC_NOTES_URL,
    NEXT_PUBLIC_MAIL_URL: process.env.NEXT_PUBLIC_MAIL_URL,
    NEXT_PUBLIC_CALENDAR_URL: process.env.NEXT_PUBLIC_CALENDAR_URL,
    NEXT_PUBLIC_TASKS_URL: process.env.NEXT_PUBLIC_TASKS_URL,
  });
}

export function isProductionEnvironment() {
  return parseAtelierEnvironment(process.env.ATELIER_ENV) === "production";
}

export function isIndexableProductOrigin(origin: string) {
  const hostname = new URL(origin).hostname;
  return hostname === "atelier.diy" || (hostname.endsWith(".atelier.diy") && !hostname.endsWith(".testing.atelier.diy"));
}
