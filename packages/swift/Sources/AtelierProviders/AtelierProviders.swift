import AtelierContracts
import Foundation

public struct ProviderCapabilities: Codable, Equatable, Sendable {
    public let incrementalSync: Bool
    public let pushNotifications: Bool
    public let serverSearch: Bool
    public let drafts: Bool
    public let send: Bool
    public let labels: Bool
    public let folders: Bool
    public let recurrence: Bool
    public let attendees: Bool
    public let writeback: Bool

    public init(
        incrementalSync: Bool, pushNotifications: Bool, serverSearch: Bool,
        drafts: Bool, send: Bool, labels: Bool, folders: Bool,
        recurrence: Bool, attendees: Bool, writeback: Bool
    ) {
        self.incrementalSync = incrementalSync
        self.pushNotifications = pushNotifications
        self.serverSearch = serverSearch
        self.drafts = drafts
        self.send = send
        self.labels = labels
        self.folders = folders
        self.recurrence = recurrence
        self.attendees = attendees
        self.writeback = writeback
    }
}

public enum MailProviderKind: String, Codable, CaseIterable, Sendable {
    case gmail, jmap, imap

    public var capabilities: ProviderCapabilities {
        switch self {
        case .gmail:
            .init(incrementalSync: true, pushNotifications: true, serverSearch: true, drafts: true, send: true, labels: true, folders: false, recurrence: false, attendees: false, writeback: true)
        case .jmap:
            .init(incrementalSync: true, pushNotifications: true, serverSearch: true, drafts: true, send: true, labels: false, folders: true, recurrence: false, attendees: false, writeback: true)
        case .imap:
            .init(incrementalSync: true, pushNotifications: true, serverSearch: true, drafts: true, send: true, labels: false, folders: true, recurrence: false, attendees: false, writeback: true)
        }
    }
}

public enum CalendarProviderKind: String, Codable, CaseIterable, Sendable {
    case googleCalendar, microsoftCalendar, caldav

    public var capabilities: ProviderCapabilities {
        .init(
            incrementalSync: true,
            pushNotifications: self != .caldav,
            serverSearch: false,
            drafts: false,
            send: false,
            labels: false,
            folders: false,
            recurrence: true,
            attendees: true,
            writeback: true
        )
    }
}

public struct ProviderSyncCursor: Codable, Equatable, Sendable {
    public let accountID: UUID
    public let value: String
    public let observedAt: Date

    public init(accountID: UUID, value: String, observedAt: Date = Date()) {
        self.accountID = accountID
        self.value = value
        self.observedAt = observedAt
    }
}

public protocol ProviderAdapter: Sendable {
    associatedtype Mutation: Codable & Sendable
    var capabilities: ProviderCapabilities { get }
    func initialSync(accountID: UUID) async throws -> ProviderSyncCursor
    func incrementalSync(cursor: ProviderSyncCursor) async throws -> ProviderSyncCursor
    func apply(accountID: UUID, mutation: Mutation, idempotencyKey: String) async throws
}

public enum ProviderAvailability: Codable, Equatable, Sendable {
    case contractOnly(reason: String)
    case configured
}

public struct ProviderDescriptor: Codable, Equatable, Sendable {
    public let name: String
    public let capabilities: ProviderCapabilities
    public let availability: ProviderAvailability

    public init(name: String, capabilities: ProviderCapabilities, availability: ProviderAvailability) {
        self.name = name
        self.capabilities = capabilities
        self.availability = availability
    }
}

public struct GmailSyncState: Codable, Equatable, Sendable {
    public let historyID: String
    public let watchExpiresAt: Date?

    public init(historyID: String, watchExpiresAt: Date? = nil) {
        self.historyID = historyID
        self.watchExpiresAt = watchExpiresAt
    }
}

public enum GmailSyncDisposition: Codable, Equatable, Sendable {
    case incremental(fromHistoryID: String)
    case fullReconciliation(reason: String)
    case renewWatch(notAfter: Date)
}

public struct JMAPSyncState: Codable, Equatable, Sendable {
    public let accountState: String
    public let mailboxState: String
    public let emailState: String

    public init(accountState: String, mailboxState: String, emailState: String) {
        self.accountState = accountState
        self.mailboxState = mailboxState
        self.emailState = emailState
    }
}

public struct IMAPSyncState: Codable, Equatable, Sendable {
    public let mailbox: String
    public let uidValidity: UInt64
    public let highestModSequence: UInt64?
    public let lastSeenUID: UInt64?

    public init(mailbox: String, uidValidity: UInt64, highestModSequence: UInt64?, lastSeenUID: UInt64?) {
        self.mailbox = mailbox
        self.uidValidity = uidValidity
        self.highestModSequence = highestModSequence
        self.lastSeenUID = lastSeenUID
    }
}

public struct CalendarSyncState: Codable, Equatable, Sendable {
    public let syncToken: String?
    public let subscriptionID: String?
    public let subscriptionExpiresAt: Date?

    public init(syncToken: String?, subscriptionID: String? = nil, subscriptionExpiresAt: Date? = nil) {
        self.syncToken = syncToken
        self.subscriptionID = subscriptionID
        self.subscriptionExpiresAt = subscriptionExpiresAt
    }
}

public enum CalendarSourceAuthority: String, Codable, Sendable {
    case atelierPDS
    case provider
    case subscribedFeed
}

public protocol GmailProviderAdapter: ProviderAdapter where Mutation == MailMutation {
    func reconcileAfterExpiredHistory(accountID: UUID) async throws -> GmailSyncState
    func renewWatch(accountID: UUID) async throws -> Date
}

public protocol JMAPProviderAdapter: ProviderAdapter where Mutation == MailMutation {
    func session(accountID: UUID) async throws -> JMAPSyncState
}

public protocol IMAPProviderAdapter: ProviderAdapter where Mutation == MailMutation {
    func idle(accountID: UUID, mailbox: String) async throws
}

public enum MailMutation: Codable, Equatable, Sendable {
    case setRead(opaqueThreadID: String, isRead: Bool)
    case setStarred(opaqueThreadID: String, isStarred: Bool)
    case move(opaqueThreadID: String, destination: String)
    case saveDraft(markdown: String)
    case sendDraft(opaqueDraftID: String)
}

public enum CalendarMutation: Codable, Equatable, Sendable {
    case upsert(icalendar: String, expectedSourceVersion: String?)
    case delete(opaqueEventID: String, expectedSourceVersion: String?)
    case respond(opaqueEventID: String, status: String, expectedSourceVersion: String?)
}

public protocol CalendarProviderAdapter: ProviderAdapter where Mutation == CalendarMutation {
    var sourceAuthority: CalendarSourceAuthority { get }
    func reconcile(accountID: UUID, state: CalendarSyncState?) async throws -> CalendarSyncState
}
