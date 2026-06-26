export type Provider = "gmail" | "jmap" | "imap";

export interface MailAccount {
  id: string;
  name: string;
  address: string;
  provider: Provider;
  accent: string;
  unread: number;
}

export interface Mailbox {
  id: string;
  label: string;
  count: number;
}

export interface MailThread {
  id: string;
  accountId: string;
  from: string;
  email: string;
  avatarInitials: string;
  avatarTone: "coral" | "cyan" | "gold" | "ink";
  subject: string;
  snippet: string;
  time: string;
  unread: boolean;
  starred: boolean;
  flagged: boolean;
  labels: string[];
  body: string[];
}

export interface ComposerDraft {
  to: string;
  subject: string;
  body: string;
}
