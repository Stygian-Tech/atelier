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

const RAILPACK_ARTIFACT_ROOTS: Record<string, string> = {
  home: "apps/web/home",
  notes: "apps/web/notes",
  mail: "apps/web/mail",
  calendar: "apps/web/calendar",
  tasks: "apps/web/tasks",
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
  test("contains exactly the eight deployable surfaces", async () => {
    expect(PUBLIC_SURFACE_NAMES).toEqual(EXPECTED_SURFACES);
    const services = await render("development");
    expect(services.map((surface) => surface.name)).toEqual(EXPECTED_SURFACES);
    expect(services).toHaveLength(8);
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
      const artifactRoot = RAILPACK_ARTIFACT_ROOTS[surface.name];
      const expectedBuildCommand = artifactRoot
        ? `${legacy.build.buildCommand} && bun run infra/web/release-artifacts.ts --root ${artifactRoot}/.next/server/app --root ${artifactRoot}/.next/static`
        : legacy.build.buildCommand;

      expect(surface.source).toMatchObject({
        type: "github",
        repo: "Stygian-Tech/atelier",
        branch: "dev",
      });
      expect(surface.configFile).toBeUndefined();
      expect(surface.build).toEqual({
        ...legacy.build,
        ...(expectedBuildCommand ? { buildCommand: expectedBuildCommand } : {}),
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
