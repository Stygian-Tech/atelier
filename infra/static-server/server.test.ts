import { afterAll, beforeAll, describe, expect, test } from "bun:test";
import { mkdtemp, rm, writeFile, mkdir } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";

import { candidatesForPath, serveStaticRequest } from "./server";

let fixtureRoot = "";

beforeAll(async () => {
  fixtureRoot = await mkdtemp(join(tmpdir(), "atelier-static-"));
  await mkdir(join(fixtureRoot, "docs"));
  await writeFile(join(fixtureRoot, "index.html"), "home");
  await writeFile(join(fixtureRoot, "docs", "index.html"), "docs");
  await writeFile(join(fixtureRoot, "404.html"), "missing");
});

afterAll(async () => {
  await rm(fixtureRoot, { recursive: true, force: true });
});

describe("static site server", () => {
  test("maps root, directory, and asset paths without escaping the root", () => {
    expect(candidatesForPath("/")).toEqual(["index.html"]);
    expect(candidatesForPath("/docs/")).toEqual(["docs/index.html", "docs"]);
    expect(candidatesForPath("/_astro/app.js")).toEqual(["_astro/app.js"]);
    expect(candidatesForPath("/%2e%2e/secret")).toEqual([]);
    expect(candidatesForPath("/bad%ZZ")).toEqual([]);
  });

  test("serves static pages, HEAD, 404, and method guards", async () => {
    const home = await serveStaticRequest(new Request("http://atelier.local/"), fixtureRoot);
    expect(home.status).toBe(200);
    expect(await home.text()).toBe("home");
    expect(home.headers.get("cache-control")).toBe("no-cache");

    const docs = await serveStaticRequest(new Request("http://atelier.local/docs/"), fixtureRoot);
    expect(await docs.text()).toBe("docs");

    const head = await serveStaticRequest(new Request("http://atelier.local/", { method: "HEAD" }), fixtureRoot);
    expect(head.status).toBe(200);
    expect(await head.text()).toBe("");

    const missing = await serveStaticRequest(new Request("http://atelier.local/nope"), fixtureRoot);
    expect(missing.status).toBe(404);
    expect(await missing.text()).toBe("missing");

    const post = await serveStaticRequest(new Request("http://atelier.local/", { method: "POST" }), fixtureRoot);
    expect(post.status).toBe(405);
  });
});
