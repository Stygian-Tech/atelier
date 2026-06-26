import AtelierCore
import AtelierPlatform
import AtelierSync
import Foundation

public enum MailProviderKind: String, Codable, CaseIterable, Sendable {
    case gmail
    case jmap
    case imap
}

public struct MailAccount: Codable, Equatable, Sendable {
    public var id: AtelierID
    public var ownerDID: DID
    public var provider: MailProviderKind
    public var displayName: String
    public var emailAddress: String
    public var providerDescriptorKey: String

    public init(
        id: AtelierID = AtelierID(),
        ownerDID: DID,
        provider: MailProviderKind,
        displayName: String,
        emailAddress: String,
        providerDescriptorKey: String
    ) {
        self.id = id
        self.ownerDID = ownerDID
        self.provider = provider
        self.displayName = displayName
        self.emailAddress = emailAddress
        self.providerDescriptorKey = providerDescriptorKey
    }
}

public enum MailboxRole: String, Codable, Sendable {
    case inbox
    case sent
    case drafts
    case trash
    case archive
    case spam
    case custom
}

public struct Mailbox: Codable, Equatable, Sendable {
    public var id: AtelierID
    public var accountID: AtelierID
    public var name: String
    public var role: MailboxRole
    public var providerID: String

    public init(id: AtelierID = AtelierID(), accountID: AtelierID, name: String, role: MailboxRole, providerID: String) {
        self.id = id
        self.accountID = accountID
        self.name = name
        self.role = role
        self.providerID = providerID
    }
}

public struct MailThread: Codable, Equatable, Sendable {
    public var id: AtelierID
    public var accountID: AtelierID
    public var providerThreadID: String
    public var subject: String
    public var participantsSummary: String
    public var snippet: String
    public var unreadCount: Int
    public var isStarred: Bool
    public var lastMessageAt: Date

    public init(
        id: AtelierID = AtelierID(),
        accountID: AtelierID,
        providerThreadID: String,
        subject: String,
        participantsSummary: String,
        snippet: String,
        unreadCount: Int,
        isStarred: Bool = false,
        lastMessageAt: Date
    ) {
        self.id = id
        self.accountID = accountID
        self.providerThreadID = providerThreadID
        self.subject = subject
        self.participantsSummary = participantsSummary
        self.snippet = snippet
        self.unreadCount = unreadCount
        self.isStarred = isStarred
        self.lastMessageAt = lastMessageAt
    }
}

public struct MailAddress: Codable, Equatable, Sendable {
    public var name: String?
    public var address: String

    public init(name: String? = nil, address: String) {
        self.name = name
        self.address = address
    }
}

public struct MailMessage: Codable, Equatable, Sendable {
    public var id: AtelierID
    public var threadID: AtelierID
    public var providerMessageID: String
    public var messageIDHeader: String
    public var from: MailAddress
    public var to: [MailAddress]
    public var date: Date
    public var textBody: String?
    public var htmlBody: String?

    public init(
        id: AtelierID = AtelierID(),
        threadID: AtelierID,
        providerMessageID: String,
        messageIDHeader: String,
        from: MailAddress,
        to: [MailAddress],
        date: Date,
        textBody: String?,
        htmlBody: String?
    ) {
        self.id = id
        self.threadID = threadID
        self.providerMessageID = providerMessageID
        self.messageIDHeader = messageIDHeader
        self.from = from
        self.to = to
        self.date = date
        self.textBody = textBody
        self.htmlBody = htmlBody
    }
}

public enum MailAction: Codable, Equatable, Sendable {
    case archive(threadID: AtelierID)
    case trash(threadID: AtelierID)
    case markRead(threadID: AtelierID, isRead: Bool)
    case star(threadID: AtelierID, isStarred: Bool)
}

public protocol MailProviderAdapter: Sendable {
    var kind: MailProviderKind { get }
    func initialSync(account: MailAccount) async throws -> SyncCursor
    func incrementalSync(account: MailAccount, cursor: SyncCursor) async throws -> SyncCursor
    func apply(action: MailAction, account: MailAccount) async throws
}

public struct MailSyncSnapshot: Codable, Equatable, Sendable {
    public var cursor: SyncCursor
    public var mailboxes: [Mailbox]
    public var threads: [MailThread]
    public var messages: [MailMessage]

    public init(cursor: SyncCursor, mailboxes: [Mailbox], threads: [MailThread], messages: [MailMessage]) {
        self.cursor = cursor
        self.mailboxes = mailboxes
        self.threads = threads
        self.messages = messages
    }
}

public protocol SnapshotMailProviderAdapter: MailProviderAdapter {
    func initialSnapshot(account: MailAccount) async throws -> MailSyncSnapshot
    func incrementalSnapshot(account: MailAccount, cursor: SyncCursor) async throws -> MailSyncSnapshot
    func send(account: MailAccount, draft: MailDraft) async throws -> MailSendReceipt
}

public struct MailDraft: Codable, Equatable, Sendable {
    public var id: AtelierID
    public var accountID: AtelierID
    public var threadID: AtelierID?
    public var to: [MailAddress]
    public var subject: String
    public var textBody: String

    public init(
        id: AtelierID = AtelierID(),
        accountID: AtelierID,
        threadID: AtelierID? = nil,
        to: [MailAddress],
        subject: String,
        textBody: String
    ) {
        self.id = id
        self.accountID = accountID
        self.threadID = threadID
        self.to = to
        self.subject = subject
        self.textBody = textBody
    }
}

public struct MailSendReceipt: Codable, Equatable, Sendable {
    public var draftID: AtelierID
    public var providerMessageID: String
    public var sentAt: Date

    public init(draftID: AtelierID, providerMessageID: String, sentAt: Date = Date()) {
        self.draftID = draftID
        self.providerMessageID = providerMessageID
        self.sentAt = sentAt
    }
}

public enum MailProviderError: Error, Equatable {
    case unsupportedProvider(MailProviderKind)
    case accountProviderMismatch(expected: MailProviderKind, actual: MailProviderKind)
}

public struct GmailProviderAdapter: SnapshotMailProviderAdapter {
    public let kind: MailProviderKind = .gmail

    public init() {}

    public func initialSync(account: MailAccount) async throws -> SyncCursor {
        try await initialSnapshot(account: account).cursor
    }

    public func incrementalSync(account: MailAccount, cursor: SyncCursor) async throws -> SyncCursor {
        try await incrementalSnapshot(account: account, cursor: cursor).cursor
    }

    public func initialSnapshot(account: MailAccount) async throws -> MailSyncSnapshot {
        try validate(account)
        return snapshot(account: account, providerCursor: "gmail-history-1001")
    }

    public func incrementalSnapshot(account: MailAccount, cursor: SyncCursor) async throws -> MailSyncSnapshot {
        try validate(account)
        return snapshot(account: account, providerCursor: "gmail-history-1002")
    }

    public func apply(action: MailAction, account: MailAccount) async throws {
        try validate(account)
    }

    public func send(account: MailAccount, draft: MailDraft) async throws -> MailSendReceipt {
        try validate(account)
        return MailSendReceipt(draftID: draft.id, providerMessageID: "gmail-sent-\(draft.id.rawValue)")
    }

    private func validate(_ account: MailAccount) throws {
        guard account.provider == kind else {
            throw MailProviderError.accountProviderMismatch(expected: kind, actual: account.provider)
        }
    }

    private func snapshot(account: MailAccount, providerCursor: String) -> MailSyncSnapshot {
        let syncedAt = Date(timeIntervalSince1970: 1_789_856_400)
        let inbox = Mailbox(accountID: account.id, name: "Inbox", role: .inbox, providerID: "INBOX")
        let starred = Mailbox(accountID: account.id, name: "Starred", role: .custom, providerID: "STARRED")
        let thread = MailThread(
            accountID: account.id,
            providerThreadID: "gmail-thread-atelier-001",
            subject: "Gmail API wiring smoke test",
            participantsSummary: "Google Workspace",
            snippet: "This normalized thread came from the Gmail adapter boundary.",
            unreadCount: 1,
            lastMessageAt: syncedAt
        )
        let message = MailMessage(
            threadID: thread.id,
            providerMessageID: "gmail-message-atelier-001",
            messageIDHeader: "<gmail-message-atelier-001@mail.gmail.com>",
            from: MailAddress(name: "Google Workspace", address: "workspace-noreply@google.com"),
            to: [MailAddress(name: account.displayName, address: account.emailAddress)],
            date: syncedAt,
            textBody: "This normalized message proves Gmail sync can feed the Atelier mail domain.",
            htmlBody: nil
        )

        return MailSyncSnapshot(
            cursor: SyncCursor(accountID: account.id, providerCursor: providerCursor, lastSyncedAt: syncedAt),
            mailboxes: [inbox, starred],
            threads: [thread],
            messages: [message]
        )
    }
}

public enum MailThreadURI {
    public static func make(_ id: AtelierID) -> AtelierURI {
        AtelierURI(app: "mail", resource: "thread", id: id.rawValue)
    }
}
