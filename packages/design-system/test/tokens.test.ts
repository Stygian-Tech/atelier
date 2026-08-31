import { describe, expect, test } from "bun:test";

import { atelierColors, atelierRadii } from "../src";

describe("Atelier design tokens", () => {
  test("keeps the approved warm-paper product palette", () => {
    expect(atelierColors).toEqual({
      paper: "#fffaf7",
      ink: "#242120",
      coral: "#ff6542",
      cyan: "#1fb8ca",
      butter: "#fff0a8",
      border: "#eadeda",
      muted: "#716966",
    });
  });

  test("uses distinguishable control, card, panel, and pill radii", () => {
    expect(new Set(Object.values(atelierRadii)).size).toBe(4);
    expect(atelierRadii.pill).toBe("999px");
  });
});
