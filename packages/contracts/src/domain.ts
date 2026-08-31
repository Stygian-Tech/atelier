export type DID = `did:${string}`;
export type ATURI = `at://${string}`;

export interface StrongRef {
  uri: ATURI;
  cid: string;
}

export interface MarkdownValue {
  $type: "at.markpub.markdown";
  text: {
    $type?: "at.markpub.text";
    markdown: string;
    textBlob?: unknown;
  };
  flavor?: "gfm" | "commonmark";
  renderingRules?: string;
}

export type PublicPDSPersistenceState = "local" | "converged" | "durable";

export interface OpaqueProviderReference {
  provider: "gmail" | "jmap" | "imap" | "googleCalendar" | "microsoftCalendar" | "caldav";
  opaqueId: string;
  resourceKind: string;
  sourceVersion: string;
}

const opaqueProviderReferenceKeys = new Set([
  "provider",
  "opaqueId",
  "resourceKind",
  "sourceVersion",
]);

const opaqueProviderKinds = new Set<OpaqueProviderReference["provider"]>([
  "gmail",
  "jmap",
  "imap",
  "googleCalendar",
  "microsoftCalendar",
  "caldav",
]);

export function assertOpaqueProviderReference(value: Record<string, unknown>): asserts value is Record<string, unknown> & OpaqueProviderReference {
  for (const key of Object.keys(value)) {
    if (!opaqueProviderReferenceKeys.has(key)) {
      throw new Error(`Opaque provider reference must not include ${key}`);
    }
  }

  for (const required of ["provider", "opaqueId", "resourceKind", "sourceVersion"]) {
    if (typeof value[required] !== "string" || value[required] === "") {
      throw new Error(`Opaque provider reference requires ${required}`);
    }
  }

  if (!opaqueProviderKinds.has(value.provider as OpaqueProviderReference["provider"])) {
    throw new Error("Opaque provider reference requires a supported provider");
  }
}
