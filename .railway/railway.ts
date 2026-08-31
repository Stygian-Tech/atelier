import {
  defineRailway,
  github,
  project,
  service,
  type BuildConfig,
  type DeployConfig,
} from "railway/iac";

const GITHUB_REPOSITORY = "Stygian-Tech/atelier";
const DEVELOPMENT_REGION = "us-west2";
const HALF_GIB_IN_BYTES = 512 * 1024 * 1024;

type AtelierEnvironment = "development" | "production";
type PublicSurface =
  | "marketing"
  | "docs"
  | "status"
  | "home"
  | "notes"
  | "mail"
  | "calendar"
  | "tasks";

export const PUBLIC_SURFACE_NAMES = [
  "marketing",
  "docs",
  "status",
  "home",
  "notes",
  "tasks",
  "calendar",
  "mail",
] as const satisfies readonly PublicSurface[];

export const PUBLIC_SURFACE_BUILDS = {
  marketing: {
    builder: "DOCKERFILE",
    dockerfilePath: "/apps/marketing/Dockerfile",
    watchPatterns: [
      "/apps/marketing/**",
      "/packages/design-system/**",
      "/infra/static-server/**",
      "/package.json",
      "/bun.lock",
      "/turbo.json",
      "/.dockerignore",
      "/.railway/railway.ts",
      "/infra/railway/services/marketing.toml",
    ],
  },
  docs: {
    builder: "DOCKERFILE",
    dockerfilePath: "/apps/docs/Dockerfile",
    watchPatterns: [
      "/apps/docs/**",
      "/infra/static-server/**",
      "/package.json",
      "/bun.lock",
      "/turbo.json",
      "/.dockerignore",
      "/.railway/railway.ts",
      "/infra/railway/services/docs.toml",
    ],
  },
  status: {
    builder: "DOCKERFILE",
    dockerfilePath: "/apps/status/Dockerfile",
    watchPatterns: [
      "/apps/status/**",
      "/packages/design-system/**",
      "/infra/static-server/**",
      "/package.json",
      "/bun.lock",
      "/turbo.json",
      "/.dockerignore",
      "/.railway/railway.ts",
      "/infra/railway/services/status.toml",
    ],
  },
  home: {
    builder: "RAILPACK",
    buildCommand:
      "bun run build --filter=@stygian/atelier-home-web && bun run infra/web/release-artifacts.ts --root apps/web/home/.next/server/app --root apps/web/home/.next/static",
    watchPatterns: [
      "/apps/web/home/**",
      "/packages/**",
      "/package.json",
      "/bun.lock",
      "/turbo.json",
      "/.dockerignore",
      "/.railway/railway.ts",
      "/infra/railway/services/home.toml",
    ],
  },
  notes: {
    builder: "RAILPACK",
    buildCommand:
      "bun run build --filter=@stygian/atelier-notes-web && bun run infra/web/release-artifacts.ts --root apps/web/notes/.next/server/app --root apps/web/notes/.next/static",
    watchPatterns: [
      "/apps/web/notes/**",
      "/packages/**",
      "/package.json",
      "/bun.lock",
      "/turbo.json",
      "/.dockerignore",
      "/.railway/railway.ts",
      "/infra/railway/services/notes.toml",
    ],
  },
  mail: {
    builder: "RAILPACK",
    buildCommand:
      "bun run build --filter=@stygian/atelier-mail-web && bun run infra/web/release-artifacts.ts --root apps/web/mail/.next/server/app --root apps/web/mail/.next/static",
    watchPatterns: [
      "/apps/web/mail/**",
      "/packages/**",
      "/package.json",
      "/bun.lock",
      "/turbo.json",
      "/.dockerignore",
      "/.railway/railway.ts",
      "/infra/railway/services/mail.toml",
    ],
  },
  calendar: {
    builder: "RAILPACK",
    buildCommand:
      "bun run build --filter=@stygian/atelier-calendar-web && bun run infra/web/release-artifacts.ts --root apps/web/calendar/.next/server/app --root apps/web/calendar/.next/static",
    watchPatterns: [
      "/apps/web/calendar/**",
      "/packages/**",
      "/package.json",
      "/bun.lock",
      "/turbo.json",
      "/.dockerignore",
      "/.railway/railway.ts",
      "/infra/railway/services/calendar.toml",
    ],
  },
  tasks: {
    builder: "RAILPACK",
    buildCommand:
      "bun run build --filter=@stygian/atelier-tasks-web && bun run infra/web/release-artifacts.ts --root apps/web/tasks/.next/server/app --root apps/web/tasks/.next/static",
    watchPatterns: [
      "/apps/web/tasks/**",
      "/packages/**",
      "/package.json",
      "/bun.lock",
      "/turbo.json",
      "/.dockerignore",
      "/.railway/railway.ts",
      "/infra/railway/services/tasks.toml",
    ],
  },
} as const satisfies Record<PublicSurface, BuildConfig>;

export const PUBLIC_SURFACE_START_COMMANDS = {
  marketing: undefined,
  docs: undefined,
  status: undefined,
  home: "bun run --cwd apps/web/home start --hostname 0.0.0.0 --port $PORT",
  notes: "bun run --cwd apps/web/notes start --hostname 0.0.0.0 --port $PORT",
  mail: "bun run --cwd apps/web/mail start --hostname 0.0.0.0 --port $PORT",
  calendar: "bun run --cwd apps/web/calendar start --hostname 0.0.0.0 --port $PORT",
  tasks: "bun run --cwd apps/web/tasks start --hostname 0.0.0.0 --port $PORT",
} as const satisfies Record<PublicSurface, string | undefined>;

const HOSTS: Record<AtelierEnvironment, Record<PublicSurface, string>> = {
  development: {
    marketing: "testing.atelier.diy",
    docs: "docs.testing.atelier.diy",
    status: "status.testing.atelier.diy",
    home: "home.testing.atelier.diy",
    notes: "notes.testing.atelier.diy",
    mail: "mail.testing.atelier.diy",
    calendar: "calendar.testing.atelier.diy",
    tasks: "tasks.testing.atelier.diy",
  },
  production: {
    marketing: "atelier.diy",
    docs: "docs.atelier.diy",
    status: "status.atelier.diy",
    home: "home.atelier.diy",
    notes: "notes.atelier.diy",
    mail: "mail.atelier.diy",
    calendar: "calendar.atelier.diy",
    tasks: "tasks.atelier.diy",
  },
};

function origin(environment: AtelierEnvironment, surface: PublicSurface): string {
  return `https://${HOSTS[environment][surface]}`;
}

function sharedProductEnvironment(environment: AtelierEnvironment): Record<string, string> {
  const apiHost = environment === "development" ? "api.testing.atelier.diy" : "api.atelier.diy";
  const mcpHost = environment === "development" ? "mcp.testing.atelier.diy" : "mcp.atelier.diy";

  return {
    ATELIER_ENV: environment,
    ATELIER_PUBLIC_ORIGIN: origin(environment, "marketing"),
    ATELIER_API_ORIGIN: `https://${apiHost}`,
    ATELIER_MCP_ORIGIN: `https://${mcpHost}`,
    ATPROTO_OAUTH_CLIENT_ID: `https://${apiHost}/oauth/client-metadata.json`,
    NEXT_PUBLIC_HOME_URL: origin(environment, "home"),
    NEXT_PUBLIC_NOTES_URL: origin(environment, "notes"),
    NEXT_PUBLIC_MAIL_URL: origin(environment, "mail"),
    NEXT_PUBLIC_CALENDAR_URL: origin(environment, "calendar"),
    NEXT_PUBLIC_TASKS_URL: origin(environment, "tasks"),
  };
}

function serviceEnvironment(
  environment: AtelierEnvironment,
  surface: PublicSurface,
): Record<string, string> {
  if (surface === "marketing") {
    return {
      ATELIER_ENV: environment,
      ATELIER_MARKETING_ORIGIN: origin(environment, "marketing"),
      ATELIER_DOCS_ORIGIN: origin(environment, "docs"),
      ATELIER_STATUS_ORIGIN: origin(environment, "status"),
      ATELIER_HOME_ORIGIN: origin(environment, "home"),
      ATELIER_NOTES_ORIGIN: origin(environment, "notes"),
      ATELIER_MAIL_ORIGIN: origin(environment, "mail"),
      ATELIER_CALENDAR_ORIGIN: origin(environment, "calendar"),
      ATELIER_TASKS_ORIGIN: origin(environment, "tasks"),
    };
  }

  if (surface === "docs") {
    return {
      ATELIER_ENV: environment,
      ATELIER_DOCS_ORIGIN: origin(environment, "docs"),
    };
  }

  if (surface === "status") {
    return {
      ATELIER_ENV: environment,
      ATELIER_MARKETING_ORIGIN: origin(environment, "marketing"),
      ATELIER_DOCS_ORIGIN: origin(environment, "docs"),
      ATELIER_STATUS_ORIGIN: origin(environment, "status"),
    };
  }

  return {
    ...sharedProductEnvironment(environment),
    ...(surface === "mail"
      ? { NEXT_PUBLIC_APP_ENV: environment === "development" ? "dev" : "production" }
      : {}),
  };
}

function environmentFromName(name: string | undefined): AtelierEnvironment {
  const normalized = name?.trim().toLowerCase();
  if (normalized === "development" || normalized === "production") {
    return normalized;
  }
  throw new Error(`Unsupported Railway environment: ${name ?? "<missing>"}`);
}

function deployConfiguration(environment: AtelierEnvironment, startCommand?: string): DeployConfig {
  return {
    startCommand,
    healthcheckPath: "/",
    healthcheckTimeout: 300,
    sleepApplication: environment === "development",
    restartPolicyType: "ON_FAILURE",
    restartPolicyMaxRetries: 5,
    region: DEVELOPMENT_REGION,
    limitOverride: {
      containers: {
        cpu: 0.5,
        memoryBytes: HALF_GIB_IN_BYTES,
      },
    },
  };
}

export default defineRailway((context) => {
  const environment = environmentFromName(context.environmentName ?? context.environment);
  const branch = environment === "development" ? "dev" : "main";
  const replicas = 1;

  const resources = PUBLIC_SURFACE_NAMES.map((surface) =>
    service(surface, {
      source: github(GITHUB_REPOSITORY, { branch }),
      build: PUBLIC_SURFACE_BUILDS[surface],
      deploy: deployConfiguration(environment, PUBLIC_SURFACE_START_COMMANDS[surface]),
      replicas,
      env: serviceEnvironment(environment, surface),
    }),
  );

  return project("Atelier", { resources });
});
