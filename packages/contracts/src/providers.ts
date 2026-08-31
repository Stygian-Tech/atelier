export type MailProviderKind = "gmail" | "jmap" | "imap";
export type CalendarProviderKind = "googleCalendar" | "microsoftCalendar" | "caldav";

export interface ProviderCapabilities {
  incrementalSync: boolean;
  pushNotifications: boolean;
  serverSearch: boolean;
  drafts: boolean;
  send: boolean;
  labels: boolean;
  folders: boolean;
  recurrence: boolean;
  attendees: boolean;
  writeback: boolean;
}

export const providerCapabilities = {
  gmail: {
    incrementalSync: true, pushNotifications: true, serverSearch: true, drafts: true, send: true,
    labels: true, folders: false, recurrence: false, attendees: false, writeback: true,
  },
  jmap: {
    incrementalSync: true, pushNotifications: true, serverSearch: true, drafts: true, send: true,
    labels: false, folders: true, recurrence: false, attendees: false, writeback: true,
  },
  imap: {
    incrementalSync: true, pushNotifications: true, serverSearch: true, drafts: true, send: true,
    labels: false, folders: true, recurrence: false, attendees: false, writeback: true,
  },
  googleCalendar: {
    incrementalSync: true, pushNotifications: true, serverSearch: false, drafts: false, send: false,
    labels: false, folders: false, recurrence: true, attendees: true, writeback: true,
  },
  microsoftCalendar: {
    incrementalSync: true, pushNotifications: true, serverSearch: false, drafts: false, send: false,
    labels: false, folders: false, recurrence: true, attendees: true, writeback: true,
  },
  caldav: {
    incrementalSync: true, pushNotifications: false, serverSearch: false, drafts: false, send: false,
    labels: false, folders: false, recurrence: true, attendees: true, writeback: true,
  },
} as const satisfies Record<MailProviderKind | CalendarProviderKind, ProviderCapabilities>;

export interface ProviderSyncCursor {
  accountId: string;
  provider: MailProviderKind | CalendarProviderKind;
  value: string;
  observedAt: string;
}

export interface ProviderAdapter<Mutation> {
  readonly capabilities: ProviderCapabilities;
  initialSync(accountId: string): Promise<ProviderSyncCursor>;
  incrementalSync(cursor: ProviderSyncCursor): Promise<ProviderSyncCursor>;
  apply(accountId: string, mutation: Mutation, idempotencyKey: string): Promise<void>;
}
