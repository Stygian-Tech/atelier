import { describe, expect, test } from "bun:test";
import {
  assertOpaqueProviderReference,
  atelierCanonicalRecordJSON,
  atelierCompatibilityDigest,
  atelierLexiconDigest,
  atelierPermissionSets,
  atelierRecordMetadata,
  type DiyAtelierNotesNoteRecord,
  productOAuthScopes,
  providerCapabilities,
  publicPDSDisclosure,
  scopeString,
} from "../src";

const expectedNoteJSON = "{\"$type\":\"diy.atelier.notes.note\",\"createdAt\":\"2026-01-02T03:04:05.000Z\",\"markdown\":{\"text\":{\"markdown\":\"# Compatibility\\n\"}},\"schemaVersion\":1,\"title\":\"Compatibility title\",\"updatedAt\":\"2026-01-02T03:04:05.000Z\"}";

describe("shared contracts", () => {
  test("all product sessions use progressive permission sets", () => {
    for (const [product, scopes] of Object.entries(productOAuthScopes)) {
      expect(scopes[0]).toBe("atproto");
      expect(scopes.some((scope) => scope.startsWith("include:diy.atelier.auth."))).toBe(true);
      expect(scopes.some((scope) => scope.includes("space.atelierwork"))).toBe(false);
      expect(scopeString(product as keyof typeof productOAuthScopes)).toBe(scopes.join(" "));
    }
  });

  test("makes public-PDS behavior explicit", () => {
    expect(publicPDSDisclosure).toContain("publicly readable");
    expect(publicPDSDisclosure).toContain("Permissioned Space");
  });

  test("accepts exactly the opaque provider reference fields", () => {
    expect(() => assertOpaqueProviderReference({
      provider: "gmail",
      opaqueId: "hmac",
      resourceKind: "thread",
      sourceVersion: "1",
    })).not.toThrow();
  });

  test("rejects provider content and unknown fields in opaque references", () => {
    expect(() => assertOpaqueProviderReference({ provider: "gmail", opaqueId: "hmac", resourceKind: "thread", sourceVersion: "1", subject: "leak" })).toThrow();
    expect(() => assertOpaqueProviderReference({ provider: "gmail", opaqueId: "hmac", resourceKind: "thread", sourceVersion: "1", futurePreview: "leak" })).toThrow();
  });

  test("rejects unknown providers in opaque references", () => {
    expect(() => assertOpaqueProviderReference({ provider: "other", opaqueId: "hmac", resourceKind: "thread", sourceVersion: "1" })).toThrow();
  });

  test("rejects missing, empty, and non-string provider reference fields", () => {
    const valid = {
      provider: "gmail",
      opaqueId: "hmac",
      resourceKind: "thread",
      sourceVersion: "1",
    };

    for (const required of Object.keys(valid)) {
      const missing = { ...valid } as Record<string, unknown>;
      delete missing[required];
      expect(() => assertOpaqueProviderReference(missing)).toThrow(`requires ${required}`);
      expect(() => assertOpaqueProviderReference({ ...valid, [required]: "" })).toThrow(`requires ${required}`);
      expect(() => assertOpaqueProviderReference({ ...valid, [required]: 1 })).toThrow(`requires ${required}`);
    }
  });

  test("describes current transport differences without claiming adapters exist", () => {
    expect(providerCapabilities.gmail.labels).toBe(true);
    expect(providerCapabilities.imap.folders).toBe(true);
    expect(providerCapabilities.caldav.pushNotifications).toBe(false);
  });

  test("exposes generated record fields and stable canonical JSON", () => {
    const note: DiyAtelierNotesNoteRecord = {
      "$type": "diy.atelier.notes.note",
      createdAt: "2026-01-02T03:04:05.000Z",
      markdown: { text: { markdown: "# Compatibility\n" } },
      schemaVersion: 1,
      title: "Compatibility title",
      updatedAt: "2026-01-02T03:04:05.000Z",
    };
    expect(JSON.stringify(note)).toBe(expectedNoteJSON);
    expect(atelierCanonicalRecordJSON["diy.atelier.notes.note"]).toBe(expectedNoteJSON);
  });

  test("shares identifiers, required fields, disclosure metadata, and permissions", () => {
    expect(atelierLexiconDigest).toBe("5eb102f6b0da687c6891b40308cebe83123e526eb818d5b16535ed6a2fe98483");
    expect(atelierCompatibilityDigest).toBe("e96842a9f9896118fc6f42b474ec5dfa3edf5095c6976063245779b42a3280b4");
    expect(atelierRecordMetadata["diy.atelier.notes.note"].requiredFields).toEqual([
      "title",
      "markdown",
      "createdAt",
      "updatedAt",
      "schemaVersion",
    ]);
    expect(Object.values(atelierRecordMetadata).every((metadata) => metadata.publicData)).toBe(true);
    expect(atelierPermissionSets["diy.atelier.auth.calendar"][0]?.collection).toEqual([
      "diy.atelier.calendar.event",
      "community.lexicon.calendar.event",
      "community.lexicon.calendar.rsvp",
    ]);
  });
});
