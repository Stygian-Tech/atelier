import { describe, expect, test } from "bun:test";
import { atelierLexicons, lexiconIDs, privateKVLexiconIDs } from "../src";

describe("Atelier Lexicons", () => {
  test("all schemas use the space.atelierwork namespace", () => {
    expect(lexiconIDs().every((id) => id.startsWith("space.atelierwork."))).toBe(true);
  });

  test("private concepts default to Atelier KV", () => {
    expect(privateKVLexiconIDs()).toEqual(lexiconIDs());
  });

  test("schemas include main definitions", () => {
    for (const schema of atelierLexicons) {
      expect(schema.defs.main).toBeTruthy();
    }
  });
});
