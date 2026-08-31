import type { MailAccount, Mailbox, MailThread } from "./types";

export const accounts: MailAccount[] = [
  {
    id: "gmail-primary",
    name: "Atelier Ops",
    address: "ops@atelier.diy",
    provider: "gmail",
    accent: "#f05d5e",
    unread: 12,
  },
  {
    id: "jmap-studio",
    name: "Studio",
    address: "studio@atelier.diy",
    provider: "jmap",
    accent: "#22b8cf",
    unread: 4,
  },
  {
    id: "imap-archive",
    name: "Archive",
    address: "archive@atelier.diy",
    provider: "imap",
    accent: "#e6b800",
    unread: 0,
  },
];

export const mailboxes: Mailbox[] = [
  { id: "inbox", label: "Unified Inbox", count: 16 },
  { id: "starred", label: "Starred", count: 5 },
  { id: "drafts", label: "Drafts", count: 2 },
  { id: "sent", label: "Sent", count: 0 },
  { id: "archive", label: "Archive", count: 0 },
];

export const threads: MailThread[] = [
  {
    id: "thread-001",
    accountId: "gmail-primary",
    from: "Mira Chen",
    email: "mira@example.com",
    avatarInitials: "MC",
    avatarTone: "coral",
    subject: "Opaque PDS references for linked mail threads",
    snippet: "Provider content stays server-side; public PDS records carry only opaque, HMAC-derived references.",
    time: "9:42 AM",
    unread: true,
    starred: true,
    flagged: false,
    labels: ["Architecture", "PDS"],
    body: [
      "Provider content stays server-side; public PDS records carry only opaque, HMAC-derived references.",
      "The key detail is keeping source identity, version, and relationship hooks stable without publishing subjects, participants, snippets, titles, locations, or bodies.",
      "Also: please keep linked-thread records free of message snippets. A target URI plus optional user-authored note is enough."
    ],
  },
  {
    id: "thread-002",
    accountId: "gmail-primary",
    from: "Google Cloud",
    email: "notifications@google.com",
    avatarInitials: "G",
    avatarTone: "cyan",
    subject: "Pub/Sub topic verification for Gmail watch",
    snippet: "Your webhook endpoint can now receive push messages for historyId cursor updates.",
    time: "8:18 AM",
    unread: true,
    starred: false,
    flagged: true,
    labels: ["Gmail", "Sync"],
    body: [
      "Your webhook endpoint can now receive push messages for historyId cursor updates.",
      "Remember to validate the audience and issuer before enqueueing sync work."
    ],
  },
  {
    id: "thread-003",
    accountId: "jmap-studio",
    from: "Fastmail JMAP",
    email: "api@fastmail.com",
    avatarInitials: "FJ",
    avatarTone: "ink",
    subject: "JMAP changes endpoint notes",
    snippet: "Threads, mailboxes, identities, and search can all map cleanly into the common mail domain.",
    time: "Yesterday",
    unread: false,
    starred: false,
    flagged: false,
    labels: ["JMAP"],
    body: [
      "Threads, mailboxes, identities, and search can all map cleanly into the common mail domain.",
      "The main thing to preserve is the account-scoped cursor and a durable provider mapping table."
    ],
  },
  {
    id: "thread-004",
    accountId: "imap-archive",
    from: "Legacy IMAP",
    email: "ops@legacy.example",
    avatarInitials: "LI",
    avatarTone: "gold",
    subject: "Threading fallback fixture",
    snippet: "This mailbox has incomplete References headers, so the fixture should become a single-message thread.",
    time: "Mon",
    unread: false,
    starred: true,
    flagged: false,
    labels: ["IMAP", "Fixture"],
    body: [
      "This mailbox has incomplete References headers, so the fixture should become a single-message thread.",
      "A normalized subject plus time-window fallback is acceptable only after header threading fails."
    ],
  },
];
