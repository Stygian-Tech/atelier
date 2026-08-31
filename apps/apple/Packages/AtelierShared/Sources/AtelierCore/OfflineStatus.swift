import Foundation

public enum PersistencePhase: String, Codable, CaseIterable, Sendable {
    case localOnly
    case queued
    case syncing
    case durable
    case needsAttention
}

public struct OfflineStatus: Codable, Equatable, Sendable {
    public var phase: PersistencePhase
    public var pendingChangeCount: Int
    public var lastDurableAt: Date?

    public init(
        phase: PersistencePhase,
        pendingChangeCount: Int = 0,
        lastDurableAt: Date? = nil
    ) {
        self.phase = phase
        self.pendingChangeCount = max(0, pendingChangeCount)
        self.lastDurableAt = lastDurableAt
    }

    public static let localOnly = OfflineStatus(phase: .localOnly)
}
