import { describe, expect, test } from "bun:test";
import {
  createRailwayContext,
  project,
  type BuildConfig,
  type DeployConfig,
  type ProjectDefinition,
  type ServiceNode,
} from "railway/iac";

import railwayProgram, {
  PUBLIC_SURFACE_NAMES,
} from "../../.railway/railway";

const EXPECTED_SURFACES = [
  "marketing",
  "docs",
  "status",
  "home",
  "notes",
  "tasks",
  "calendar",
  "mail",
] as const;

const EXPECTED_DEVELOPMENT_HOSTS: Record<string, string> = {
  marketing: "testing.atelier.diy",
  docs: "docs.testing.atelier.diy",
  status: "status.testing.atelier.diy",
  home: "home.testing.atelier.diy",
  notes: "notes.testing.atelier.diy",
  mail: "mail.testing.atelier.diy",
  calendar: "calendar.testing.atelier.diy",
  tasks: "tasks.testing.atelier.diy",
};

const EXPECTED_PRODUCTION_HOSTS: Record<string, string> = {
  marketing: "atelier.diy",
  docs: "docs.atelier.diy",
  status: "status.atelier.diy",
  home: "home.atelier.diy",
  notes: "notes.atelier.diy",
  mail: "mail.atelier.diy",
  calendar: "calendar.atelier.diy",
  tasks: "tasks.atelier.diy",
};

const EXPECTED_DOCKERFILES: Record<string, string> = {
  marketing: "/apps/marketing/Dockerfile",
  docs: "/apps/docs/Dockerfile",
  status: "/apps/status/Dockerfile",
  home: "/apps/web/home/Dockerfile",
  notes: "/apps/web/notes/Dockerfile",
  mail: "/apps/web/mail/Dockerfile",
  calendar: "/apps/web/calendar/Dockerfile",
  tasks: "/apps/web/tasks/Dockerfile",
};

const NEXT_SURFACES = ["home", "notes", "mail", "calendar", "tasks"] as const;

type MarqueRecord = {
  flatten?: boolean;
  name: string;
  type: string;
  value: string;
};

async function render(environment: string): Promise<ServiceNode[]> {
  const context = createRailwayContext({
    command: "plan",
    environment,
    environmentName: environment,
    projectName: "Atelier",
  });
  const definition = (await railwayProgram(context, project)) as ProjectDefinition;
  return (definition.resources ?? []).flat() as ServiceNode[];
}

async function legacyContract(surface: string): Promise<{
  build: BuildConfig;
  deploy: DeployConfig;
}> {
  return Bun.TOML.parse(
    await Bun.file(`infra/railway/services/${surface}.toml`).text(),
  ) as {
    build: BuildConfig;
    deploy: DeployConfig;
  };
}

function literalVariables(serviceNode: ServiceNode): Record<string, string> {
  return Object.fromEntries(
    Object.entries(serviceNode.variables ?? {}).map(([name, variable]) => {
      if (variable.type !== "literal") {
        throw new Error(`${serviceNode.name}.${name} is not a literal public variable`);
      }
      return [name, variable.value ?? ""];
    }),
  );
}

describe("Railway public-surface plan", () => {
  test("keeps only the web builds' required provenance manifests in the build context", async () => {
    const entries = (await Bun.file(".dockerignore").text())
      .split("\n")
      .map((line) => line.trim())
      .filter((line) => line.length > 0 && !line.startsWith("#"));
    const expectedExceptions = [
      "!imports/atelier-mail/",
      "!imports/atelier-mail/bun.lock",
      "!imports/atelier-mail/bunfig.toml",
      "!imports/atelier-mail/package.json",
      "!imports/atelier-mail/packages/",
      "!imports/atelier-mail/packages/lexicons/",
      "!imports/atelier-mail/packages/lexicons/package.json",
    ];

    expect(entries).toContain("imports/**");
    expect(entries).not.toContain("imports");
    expect(entries.filter((entry) => entry.startsWith("!imports/"))).toEqual(
      expectedExceptions,
    );
    for (const exception of expectedExceptions) {
      expect(entries.indexOf(exception)).toBeGreaterThan(entries.indexOf("imports/**"));
    }
  });

  test("contains exactly the eight deployable surfaces", async () => {
    expect(PUBLIC_SURFACE_NAMES).toEqual(EXPECTED_SURFACES);
    const services = await render("development");
    expect(services.map((surface) => surface.name)).toEqual(EXPECTED_SURFACES);
    expect(services).toHaveLength(8);
  });

  test("rebuilds every surface when the Docker context contract changes", async () => {
    for (const surface of await render("development")) {
      const legacy = await legacyContract(surface.name);

      expect(
        (surface.build?.watchPatterns ?? []).filter(
          (pattern) => pattern === "/.dockerignore",
        ),
      ).toHaveLength(1);
      expect(
        (legacy.build.watchPatterns ?? []).filter(
          (pattern) => pattern === "/.dockerignore",
        ),
      ).toHaveLength(1);
    }
  });

  test("isolates every public build in its checked-in Dockerfile", async () => {
    for (const surface of await render("development")) {
      const legacy = await legacyContract(surface.name);

      expect(surface.build?.builder).toBe("DOCKERFILE");
      expect(surface.build?.dockerfilePath).toBe(EXPECTED_DOCKERFILES[surface.name]);
      expect(surface.build?.buildCommand).toBeUndefined();
      expect(legacy.build.builder).toBe("DOCKERFILE");
      expect(legacy.build.dockerfilePath).toBe(EXPECTED_DOCKERFILES[surface.name]);
      expect(legacy.build.buildCommand).toBeUndefined();
    }
  });

  test("delegates runtime startup to each image without interpolating Railway PORT", async () => {
    const services = await render("development");

    for (const surface of services) {
      const legacy = await legacyContract(surface.name);
      expect(surface.deploy?.startCommand).toBeUndefined();
      expect(legacy.deploy.startCommand).toBeUndefined();
    }

    expect(await Bun.file(".railway/railway.ts").text()).not.toContain("$PORT");

    for (const surfaceName of NEXT_SURFACES) {
      const dockerfile = await Bun.file(
        `apps/web/${surfaceName}/Dockerfile`,
      ).text();
      const packageManifest = await Bun.file(
        `apps/web/${surfaceName}/package.json`,
      ).json();
      const legacyText = await Bun.file(
        `infra/railway/services/${surfaceName}.toml`,
      ).text();

      expect(packageManifest.scripts.start).toBe("next start");
      expect(dockerfile).toContain("ENV HOSTNAME=0.0.0.0");
      expect(
        dockerfile
          .split("\n")
          .map((line) => line.trim())
          .filter((line) => line.startsWith("CMD ")),
      ).toEqual([
        `CMD ["bun", "run", "--cwd", "apps/web/${surfaceName}", "start"]`,
      ]);
      expect(legacyText).not.toContain("$PORT");
    }
  });

  test("keeps Development DNS scoped to deployed Railway surfaces", async () => {
    const manifest = (await Bun.file("infra/marque/testing.json").json()) as {
      apply: boolean;
      environment: string;
      provider: string;
      records: MarqueRecord[];
      reviewStatus: string;
      verificationRecords: MarqueRecord[];
      zone: string;
    };
    const expectedNames = Object.values(EXPECTED_DEVELOPMENT_HOSTS)
      .map((hostname) => hostname.replace(/\.atelier\.diy$/, ""))
      .sort();
    const recordNames = manifest.records.map((record) => record.name).sort();
    const verificationNames = manifest.verificationRecords
      .map((record) => record.name)
      .sort();

    expect(manifest).toMatchObject({
      apply: false,
      environment: "development",
      provider: "marque",
      reviewStatus: "railway-targets-captured-awaiting-marque-zone-review",
      zone: "atelier.diy",
    });
    expect(recordNames).toEqual(expectedNames);
    expect(new Set(recordNames).size).toBe(recordNames.length);
    expect(recordNames).not.toContain("api.testing");
    expect(recordNames).not.toContain("mcp.testing");
    expect(JSON.stringify(manifest)).not.toContain("REPLACE_");

    for (const record of manifest.records) {
      expect(record.type).toBe("CNAME");
      expect(record.value).toMatch(/^[a-z0-9]+\.up\.railway\.app\.$/);
    }

    expect(verificationNames).toEqual(
      expectedNames.map((name) => `_railway-verify.${name}`).sort(),
    );
    expect(new Set(verificationNames).size).toBe(verificationNames.length);
    for (const record of manifest.verificationRecords) {
      expect(record.type).toBe("TXT");
      expect(record.value).toMatch(/^railway-verify=[0-9a-f]{64}$/);
    }
  });

  test("keeps Production DNS scoped to approved deployed Railway surfaces", async () => {
    const manifest = (await Bun.file("infra/marque/production.json").json()) as {
      apply: boolean;
      environment: string;
      productionApprovalGrantedOn: string;
      provider: string;
      records: MarqueRecord[];
      requiresExplicitProductionApproval: boolean;
      reviewStatus: string;
      verificationRecords: MarqueRecord[];
      zone: string;
    };
    const expectedNames = Object.values(EXPECTED_PRODUCTION_HOSTS)
      .map((hostname) =>
        hostname === "atelier.diy" ? "@" : hostname.replace(/\.atelier\.diy$/, ""),
      )
      .sort();
    const recordNames = manifest.records.map((record) => record.name).sort();
    const verificationNames = manifest.verificationRecords
      .map((record) => record.name)
      .sort();

    expect(manifest).toMatchObject({
      apply: false,
      environment: "production",
      productionApprovalGrantedOn: "2026-08-31",
      provider: "marque",
      requiresExplicitProductionApproval: true,
      reviewStatus:
        "railway-targets-captured-production-approved-awaiting-marque-zone-review",
      zone: "atelier.diy",
    });
    expect(recordNames).toEqual(expectedNames);
    expect(new Set(recordNames).size).toBe(recordNames.length);
    expect(recordNames).not.toContain("api");
    expect(recordNames).not.toContain("mcp");
    expect(JSON.stringify(manifest)).not.toContain("REPLACE_");

    for (const record of manifest.records) {
      expect(record.type).toBe("CNAME");
      expect(record.value).toMatch(/^[a-z0-9]+\.up\.railway\.app\.$/);
      expect(record.flatten).toBe(record.name === "@" ? true : undefined);
    }

    expect(verificationNames).toEqual(
      expectedNames
        .map((name) => (name === "@" ? "_railway-verify" : `_railway-verify.${name}`))
        .sort(),
    );
    expect(new Set(verificationNames).size).toBe(verificationNames.length);
    for (const record of manifest.verificationRecords) {
      expect(record.type).toBe("TXT");
      expect(record.value).toMatch(/^railway-verify=[0-9a-f]{64}$/);
    }
  });

  test("uses the exact Development source, build, runtime, and safety limits", async () => {
    const services = await render("development");

    for (const surface of services) {
      const legacy = await legacyContract(surface.name);
      const legacyWatchPatterns = legacy.build.watchPatterns ?? [];
      const ownContract = legacyWatchPatterns.at(-1);
      const expectedWatchPatterns = [
        ...legacyWatchPatterns.slice(0, -1),
        "/.railway/railway.ts",
        ...(ownContract ? [ownContract] : []),
      ];
      expect(surface.source).toMatchObject({
        type: "github",
        repo: "Stygian-Tech/atelier",
        branch: "dev",
      });
      expect(surface.configFile).toBeUndefined();
      expect(surface.build).toEqual({
        ...legacy.build,
        watchPatterns: expectedWatchPatterns,
      });
      expect(surface.deploy).toEqual({
        ...legacy.deploy,
        numReplicas: 1,
        region: "us-west2",
        sleepApplication: true,
        limitOverride: {
          containers: {
            cpu: 0.5,
            memoryBytes: 536_870_912,
          },
        },
      });
      expect(surface.networking?.customDomains).toBeUndefined();
      expect(Object.values(literalVariables(surface))).toContain(
        `https://${EXPECTED_DEVELOPMENT_HOSTS[surface.name]}`,
      );
    }
  });

  test("keeps Production manual but ready to run on main", async () => {
    const services = await render("production");

    for (const surface of services) {
      expect(surface.source).toMatchObject({
        type: "github",
        repo: "Stygian-Tech/atelier",
        branch: "main",
      });
      expect(surface.deploy).toMatchObject({
        numReplicas: 1,
        region: "us-west2",
        sleepApplication: false,
        limitOverride: {
          containers: {
            cpu: 0.5,
            memoryBytes: 536_870_912,
          },
        },
      });
      expect(surface.networking?.customDomains).toBeUndefined();
      expect(Object.values(literalVariables(surface))).toContain(
        `https://${EXPECTED_PRODUCTION_HOSTS[surface.name]}`,
      );
    }
  });

  test("uses environment-local URLs and never localhost", async () => {
    for (const environment of ["development", "production"]) {
      for (const surface of await render(environment)) {
        const variables = literalVariables(surface);
        expect(Object.values(variables).some((value) => value.includes("localhost"))).toBeFalse();
        expect(variables.ATELIER_ENV).toBe(environment);
      }
    }
  });

  test("fails closed for an unrecognized environment", async () => {
    expect(render("preview")).rejects.toThrow("Unsupported Railway environment");
  });
});
