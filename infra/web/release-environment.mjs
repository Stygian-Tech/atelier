const DEPLOYED_ORIGINS = {
  development: {
    ATELIER_PUBLIC_ORIGIN: "https://testing.atelier.diy",
    ATELIER_API_ORIGIN: "https://api.testing.atelier.diy",
    ATELIER_MCP_ORIGIN: "https://mcp.testing.atelier.diy",
    ATELIER_MARKETING_ORIGIN: "https://testing.atelier.diy",
    ATELIER_DOCS_ORIGIN: "https://docs.testing.atelier.diy",
    ATELIER_STATUS_ORIGIN: "https://status.testing.atelier.diy",
    ATELIER_HOME_ORIGIN: "https://home.testing.atelier.diy",
    ATELIER_NOTES_ORIGIN: "https://notes.testing.atelier.diy",
    ATELIER_MAIL_ORIGIN: "https://mail.testing.atelier.diy",
    ATELIER_CALENDAR_ORIGIN: "https://calendar.testing.atelier.diy",
    ATELIER_TASKS_ORIGIN: "https://tasks.testing.atelier.diy",
    NEXT_PUBLIC_HOME_URL: "https://home.testing.atelier.diy",
    NEXT_PUBLIC_NOTES_URL: "https://notes.testing.atelier.diy",
    NEXT_PUBLIC_MAIL_URL: "https://mail.testing.atelier.diy",
    NEXT_PUBLIC_CALENDAR_URL: "https://calendar.testing.atelier.diy",
    NEXT_PUBLIC_TASKS_URL: "https://tasks.testing.atelier.diy",
  },
  production: {
    ATELIER_PUBLIC_ORIGIN: "https://atelier.diy",
    ATELIER_API_ORIGIN: "https://api.atelier.diy",
    ATELIER_MCP_ORIGIN: "https://mcp.atelier.diy",
    ATELIER_MARKETING_ORIGIN: "https://atelier.diy",
    ATELIER_DOCS_ORIGIN: "https://docs.atelier.diy",
    ATELIER_STATUS_ORIGIN: "https://status.atelier.diy",
    ATELIER_HOME_ORIGIN: "https://home.atelier.diy",
    ATELIER_NOTES_ORIGIN: "https://notes.atelier.diy",
    ATELIER_MAIL_ORIGIN: "https://mail.atelier.diy",
    ATELIER_CALENDAR_ORIGIN: "https://calendar.atelier.diy",
    ATELIER_TASKS_ORIGIN: "https://tasks.atelier.diy",
    NEXT_PUBLIC_HOME_URL: "https://home.atelier.diy",
    NEXT_PUBLIC_NOTES_URL: "https://notes.atelier.diy",
    NEXT_PUBLIC_MAIL_URL: "https://mail.atelier.diy",
    NEXT_PUBLIC_CALENDAR_URL: "https://calendar.atelier.diy",
    NEXT_PUBLIC_TASKS_URL: "https://tasks.atelier.diy",
  },
};

const PRODUCT_ORIGIN_VARIABLES = [
  "NEXT_PUBLIC_HOME_URL",
  "NEXT_PUBLIC_NOTES_URL",
  "NEXT_PUBLIC_MAIL_URL",
  "NEXT_PUBLIC_CALENDAR_URL",
  "NEXT_PUBLIC_TASKS_URL",
];

export function getAtelierEnvironment(raw = process.env.ATELIER_ENV) {
  const value = raw?.trim().toLowerCase();
  if (!value || value === "local") return "local";
  if (value === "development" || value === "production") return value;
  throw new Error(
    `ATELIER_ENV must be local, development, or production; received ${JSON.stringify(raw)}`,
  );
}

export function resolveAtelierOrigin(name, localFallback, env = process.env) {
  const environment = getAtelierEnvironment(env.ATELIER_ENV);
  const configured = env[name]?.trim();

  if (environment !== "local" && !configured) {
    throw new Error(`${name} is required when ATELIER_ENV=${environment}`);
  }

  const candidate = configured || localFallback;
  let url;
  try {
    url = new URL(candidate);
  } catch {
    throw new Error(`${name} must be an absolute HTTP(S) origin`);
  }

  const isOriginOnly =
    url.pathname === "/" &&
    !url.search &&
    !url.hash &&
    !url.username &&
    !url.password;
  if (!isOriginOnly || (url.protocol !== "http:" && url.protocol !== "https:")) {
    throw new Error(`${name} must contain only an absolute HTTP(S) origin`);
  }

  if (environment !== "local") {
    const expected = DEPLOYED_ORIGINS[environment][name];
    if (!expected) {
      throw new Error(`${name} has no approved ${environment} origin`);
    }
    if (url.origin !== expected) {
      throw new Error(
        `${name} must be ${expected} when ATELIER_ENV=${environment}; received ${url.origin}`,
      );
    }
  }

  return url.origin;
}

export function assertProductOrigins(env = process.env) {
  resolveProductOriginVariables(env);
}

export function resolveProductOriginVariables(env = process.env) {
  const resolved = {};
  for (const name of PRODUCT_ORIGIN_VARIABLES) {
    const localPort = 3000 + PRODUCT_ORIGIN_VARIABLES.indexOf(name);
    resolved[name] = resolveAtelierOrigin(name, `http://localhost:${localPort}`, env);
  }
  return resolved;
}

export function isIndexableEnvironment(env = process.env) {
  return getAtelierEnvironment(env.ATELIER_ENV) === "production";
}

export function createNextSecurityHeaders() {
  return [
    { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
    { key: "X-Content-Type-Options", value: "nosniff" },
    { key: "X-Frame-Options", value: "DENY" },
    { key: "Permissions-Policy", value: "camera=(), geolocation=(), microphone=()" },
  ];
}
