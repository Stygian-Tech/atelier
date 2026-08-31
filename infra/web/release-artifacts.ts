import { readdir } from "node:fs/promises";
import { extname, join, relative } from "node:path";

import { getAtelierEnvironment } from "./release-environment.mjs";

const TEXT_OUTPUT_EXTENSIONS = new Set([
  ".body",
  ".css",
  ".html",
  ".js",
  ".json",
  ".mjs",
  ".rsc",
  ".svg",
  ".txt",
  ".webmanifest",
  ".xml",
]);
const LOCAL_ORIGIN_PATTERN = /https?:\/\/(?:localhost|127\.0\.0\.1|\[::1\])(?::\d+)?/gi;

const defaultRoots = [
  "apps/marketing/dist",
  "apps/docs/dist",
  "apps/status/dist",
  "apps/web/home/.next/server/app",
  "apps/web/home/.next/static",
  "apps/web/notes/.next/server/app",
  "apps/web/notes/.next/static",
  "apps/web/mail/.next/server/app",
  "apps/web/mail/.next/static",
  "apps/web/calendar/.next/server/app",
  "apps/web/calendar/.next/static",
  "apps/web/tasks/.next/server/app",
  "apps/web/tasks/.next/static",
];

async function walk(root: string, current = root): Promise<string[]> {
  let entries;
  try {
    entries = await readdir(current, { withFileTypes: true });
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === "ENOENT") {
      throw new Error(`Release artifact root does not exist: ${root}`);
    }
    throw error;
  }

  const files: string[] = [];
  for (const entry of entries) {
    const path = join(current, entry.name);
    if (entry.isDirectory()) files.push(...await walk(root, path));
    else if (entry.isFile() && TEXT_OUTPUT_EXTENSIONS.has(extname(entry.name))) files.push(path);
  }
  return files;
}

export interface LocalhostArtifactViolation {
  file: string;
  origins: string[];
}

export async function findLocalhostArtifacts(roots: string[]): Promise<LocalhostArtifactViolation[]> {
  const violations: LocalhostArtifactViolation[] = [];
  for (const root of roots) {
    for (const file of await walk(root)) {
      const contents = await Bun.file(file).text();
      const origins = [...new Set(contents.match(LOCAL_ORIGIN_PATTERN) ?? [])];
      if (origins.length > 0) {
        violations.push({ file: relative(process.cwd(), file), origins });
      }
    }
  }
  return violations;
}

function requestedRoots(args: string[]) {
  const roots: string[] = [];
  for (let index = 0; index < args.length; index += 1) {
    if (args[index] !== "--root") throw new Error(`Unknown argument: ${args[index]}`);
    const root = args[index + 1];
    if (!root) throw new Error("--root requires a path");
    roots.push(root);
    index += 1;
  }
  return roots.length > 0 ? roots : defaultRoots;
}

async function main() {
  const environment = getAtelierEnvironment();
  if (environment === "local") {
    console.log("Skipping deployed-artifact origin scan for ATELIER_ENV=local");
    return;
  }

  const roots = requestedRoots(Bun.argv.slice(2));
  const violations = await findLocalhostArtifacts(roots);
  if (violations.length > 0) {
    const details = violations
      .map(({ file, origins }) => `${file}: ${origins.join(", ")}`)
      .join("\n");
    throw new Error(`Deployed web artifacts contain localhost origins:\n${details}`);
  }
  console.log(`Verified ${environment} web artifacts contain no localhost origins`);
}

if (import.meta.main) await main();
