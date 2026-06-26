import linkedThread from "./space/atelierwork/mail/linkedThread.json";
import providerDescriptor from "./space/atelierwork/mail/providerDescriptor.json";
import crossAppReference from "./space/atelierwork/platform/crossAppReference.json";
import mcpGrant from "./space/atelierwork/platform/mcpGrant.json";
import preference from "./space/atelierwork/platform/preference.json";
import workspacePointer from "./space/atelierwork/workspace/pointer.json";
import taskPointer from "./space/atelierwork/tasks/pointer.json";

export const atelierLexicons = [
  linkedThread,
  providerDescriptor,
  crossAppReference,
  mcpGrant,
  preference,
  workspacePointer,
  taskPointer,
] as const;

export type AtelierLexicon = (typeof atelierLexicons)[number];

export function lexiconIDs(): string[] {
  return atelierLexicons.map((schema) => schema.id);
}

export function privateKVLexiconIDs(): string[] {
  return atelierLexicons
    .filter((schema) => schema.metadata?.atelierStorage === "private-kv")
    .map((schema) => schema.id);
}
