import AtelierCore
import Foundation

public struct SyncCursor: Codable, Equatable, Sendable {
    public var accountID: AtelierID
    public var providerCursor: String?
    public var lastSyncedAt: Date?

    public init(accountID: AtelierID, providerCursor: String? = nil, lastSyncedAt: Date? = nil) {
        self.accountID = accountID
        self.providerCursor = providerCursor
        self.lastSyncedAt = lastSyncedAt
    }
}

public enum SyncJobKind: String, Codable, Sendable {
    case initialSync
    case incrementalSync
    case reindex
}

public struct SyncJob: Codable, Equatable, Sendable {
    public var id: AtelierID
    public var accountID: AtelierID
    public var kind: SyncJobKind
    public var notBefore: Date

    public init(id: AtelierID = AtelierID(), accountID: AtelierID, kind: SyncJobKind, notBefore: Date = Date()) {
        self.id = id
        self.accountID = accountID
        self.kind = kind
        self.notBefore = notBefore
    }
}
