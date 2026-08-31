export type AtelierProduct = "home" | "notes" | "mail" | "calendar" | "tasks";

export const productOAuthScopes: Readonly<Record<AtelierProduct, readonly string[]>> = {
  home: ["atproto", "include:diy.atelier.auth.workspace"],
  notes: ["atproto", "include:diy.atelier.auth.notes", "include:diy.atelier.auth.workspace"],
  mail: ["atproto", "include:diy.atelier.auth.mail", "include:diy.atelier.auth.workspace"],
  calendar: ["atproto", "include:diy.atelier.auth.calendar", "include:diy.atelier.auth.workspace"],
  tasks: ["atproto", "include:diy.atelier.auth.tasks", "include:diy.atelier.auth.workspace"],
};

export function scopeString(product: AtelierProduct): string {
  return productOAuthScopes[product].join(" ");
}

export const publicPDSDisclosure =
  "Atelier records saved to a standard AT Protocol repository are publicly readable. Do not store private or secret information until a compatible Permissioned Space is active.";
