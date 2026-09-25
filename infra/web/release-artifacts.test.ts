import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, relative } from "node:path";

import { findLocalhostArtifacts } from "./release-artifacts";

let fixtureRoot = "";

beforeAll(async () => {
  fixtureRoot = await mkdtemp(join(tmpdir(), "atelier-web-artifacts-"));
  await mkdir(join(fixtureRoot, "nested"));
  await mkdir(join(fixtureRoot, "clean"));
  await writeFile(join(fixtureRoot, "index.html"), '<link rel="canonical" href="https://atelier.diy/">');
  await writeFile(join(fixtureRoot, "nested", "route.rsc"), 'href="http://localhost:3000"');
  await writeFile(join(fixtureRoot, "nested", "styles.css"), 'background-image:url("http://127.0.0.1:4321/preview.svg")');
  await writeFile(join(fixtureRoot, "nested", "ignored.bin"), "http://localhost:4321");
});

afterAll(async () => {
  await rm(fixtureRoot, { recursive: true, force: true });
});

describe("release artifact origin scan", () => {
  test("reports localhost only in user-facing text artifacts", async () => {
    expect(await findLocalhostArtifacts([fixtureRoot])).toEqual([
      {
        file: expect.stringContaining("nested/route.rsc"),
        origins: ["http://localhost:3000"],
      },
      {
        file: expect.stringContaining("nested/styles.css"),
        origins: ["http://127.0.0.1:4321"],
      },
    ]);
  });

  test("reports a stable file order across nested artifacts and reversed roots", async () => {
    const root = await mkdtemp(join(tmpdir(), "atelier-web-artifact-order-"));
    const firstRoot = join(root, "a");
    const lastRoot = join(root, "z");
    try {
      await mkdir(join(firstRoot, "nested"), { recursive: true });
      await mkdir(lastRoot);
      const paths = [
        join(lastRoot, "last.html"),
        join(firstRoot, "nested", "z.js"),
        join(firstRoot, "nested", "a.css"),
        join(firstRoot, "first.html"),
      ] as const;
      for (const path of paths) await writeFile(path, "http://localhost:3000");
      const expected = [paths[3], paths[2], paths[1], paths[0]].map((path) => ({
        file: relative(process.cwd(), path),
        origins: ["http://localhost:3000"],
      }));

      expect(await findLocalhostArtifacts([lastRoot, firstRoot])).toEqual(expected);
      expect(await findLocalhostArtifacts([firstRoot, lastRoot])).toEqual(expected);
    } finally {
      await rm(root, { recursive: true, force: true });
    }
  });

  test("accepts a clean production-like output directory", async () => {
    expect(await findLocalhostArtifacts([join(fixtureRoot, "clean")])).toEqual([]);
  });

  test("fails closed when a requested release artifact root is missing", async () => {
    await expect(findLocalhostArtifacts([join(fixtureRoot, "missing")])).rejects.toThrow(
      "Release artifact root does not exist",
    );
  });
});
