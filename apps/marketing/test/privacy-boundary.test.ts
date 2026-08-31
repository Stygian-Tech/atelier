import { describe, expect, test } from "bun:test";

describe("beta interest privacy boundary", () => {
  test("does not submit or serialize an email address before provider approval", async () => {
    const source = await Bun.file(
      new URL("../src/pages/index.astro", import.meta.url),
    ).text();

    expect(source).toContain("data-beta-preview");
    expect(source).toContain("No address is submitted, serialized, or stored");
    expect(source).not.toContain('action="/beta-thanks"');
    expect(source).not.toContain('method="get"');
    expect(source).not.toContain('name="email"');
    expect(source).toContain('type="email"');
    expect(source).toContain("disabled");
  });

  test("does not present the non-functional thanks route as a successful signup", async () => {
    const source = await Bun.file(
      new URL("../src/pages/beta-thanks.astro", import.meta.url),
    ).text();

    expect(source).toContain("Beta signup is not open");
    expect(source).toContain("No interest was submitted");
    expect(source).toContain("structuredData={false}");
    expect(source).toContain("indexable={false}");
    expect(source).not.toContain("interest received");
  });
});
