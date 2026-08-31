import { describe, expect, test } from "bun:test";

describe("beta interest privacy boundary", () => {
  test("does not submit or serialize an email address before provider approval", async () => {
    const source = await Bun.file(
      new URL("../src/pages/index.astro", import.meta.url),
    ).text();

    expect(source).toContain("data-beta-preview");
    expect(source).toContain("Address collection is disabled");
    expect(source).not.toContain('action="/beta-thanks"');
    expect(source).not.toContain('method="get"');
    expect(source).not.toContain('name="email"');
    expect(source).toContain('type="email"');
    expect(source).toContain("disabled");
  });
});
