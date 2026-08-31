import { describe, expect, test } from "bun:test";
import { createHash } from "node:crypto";
import { atelierCollectionNSIDs, atelierLexiconByNSID, atelierLexicons, isAtelierRecordLexicon } from "../src";
import compatibility from "../fixtures/generated/compatibility.json";
import providerRef from "../fixtures/provider-ref.json";
import vendorManifest from "../vendor/manifest.json";

const expectedSchemaDigest = "5eb102f6b0da687c6891b40308cebe83123e526eb818d5b16535ed6a2fe98483";
const expectedCompatibilityDigest = "e96842a9f9896118fc6f42b474ec5dfa3edf5095c6976063245779b42a3280b4";

describe("Atelier lexicons", () => {
  test("first-party and explicitly vendored schemas have unique ids", () => {
    const ids = atelierLexicons.map((schema) => schema.id);
    expect(new Set(ids).size).toBe(ids.length);
    expect(ids.filter((id) => id.startsWith("diy.atelier.")).length).toBe(14);
    expect(ids.filter((id) => !id.startsWith("diy.atelier.")).sort()).toEqual([
      "at.markpub.markdown",
      "at.markpub.text",
      "community.lexicon.calendar.event",
      "community.lexicon.calendar.rsvp",
    ]);
  });

  test("covers every first-party product domain", () => {
    for (const domain of ["notes", "tasks", "calendar", "mail", "project", "capture", "relation", "collaboration"]) {
      expect(atelierCollectionNSIDs.some((id) => id.startsWith(`diy.atelier.${domain}.`))).toBe(true);
    }
  });

  test("provider refs cannot carry provider content", () => {
    const schema = atelierLexiconByNSID.get("diy.atelier.mail.providerRef");
    expect(schema).toBeDefined();
    if (!schema || !isAtelierRecordLexicon(schema)) {
      throw new Error("diy.atelier.mail.providerRef must remain a record lexicon");
    }
    const recordProperties = schema.defs.main.record.properties ?? {};
    for (const forbidden of ["subject", "participants", "snippet", "headers", "body", "title", "location"]) {
      expect(forbidden in recordProperties).toBe(false);
      expect(forbidden in providerRef).toBe(false);
    }
  });

  test("each product has an explicit permission set", () => {
    for (const product of ["notes", "tasks", "calendar", "mail", "workspace"]) {
      expect(atelierLexiconByNSID.get(`diy.atelier.auth.${product}`)?.defs.main.type).toBe("permission-set");
    }
  });

  test("pins exact upstream files and verifies local byte digests", async () => {
    expect(vendorManifest.retrievedAt).toBe("2026-08-30");
    expect(vendorManifest.schemas).toHaveLength(4);
    for (const entry of vendorManifest.schemas) {
      const bytes = await Bun.file(new URL(`../${entry.path}`, import.meta.url)).arrayBuffer();
      expect(createHash("sha256").update(new Uint8Array(bytes)).digest("hex")).toBe(entry.vendoredSha256);
      expect(entry.sourceUrl.startsWith("https://")).toBe(true);
      expect(entry.sourceVersion).not.toBe("");
    }
  });

  test("publishes a stable compatibility digest and public record metadata", () => {
    expect(compatibility.schemaDigest).toBe(expectedSchemaDigest);
    expect(compatibility.compatibilityDigest).toBe(expectedCompatibilityDigest);
    expect(Object.values(compatibility.records).every((record) => record.publicData)).toBe(true);
    expect(compatibility.records["diy.atelier.notes.note"].requiredFields).toEqual([
      "title",
      "markdown",
      "createdAt",
      "updatedAt",
      "schemaVersion",
    ]);
    expect(compatibility.records["diy.atelier.notes.note"].sampleSha256).toBe(
      "49555ab6a31ede8843d9915b26fba74405491e23c1bbb20f331b4a5b9e6df1a3",
    );
  });

  test("keeps community calendar event and RSVP contracts distinct", () => {
    expect(atelierCollectionNSIDs).toContain("community.lexicon.calendar.event");
    expect(atelierCollectionNSIDs).toContain("community.lexicon.calendar.rsvp");
    expect(compatibility.records["community.lexicon.calendar.event"].requiredFields).toEqual(["createdAt", "name"]);
    expect(compatibility.records["community.lexicon.calendar.rsvp"].requiredFields).toEqual(["subject", "status"]);
  });
});
