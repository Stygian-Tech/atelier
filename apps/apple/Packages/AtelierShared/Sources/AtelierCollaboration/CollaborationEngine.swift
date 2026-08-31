import AtelierCore
import Foundation

public struct CollaborationProtocolVersion: Codable, Equatable, Sendable {
    public let major: UInt16
    public let minor: UInt16

    public init(major: UInt16, minor: UInt16) {
        self.major = major
        self.minor = minor
    }

    public static let foundation = CollaborationProtocolVersion(major: 0, minor: 1)
}

public struct CollaborationOperation: Codable, Equatable, Sendable {
    public let documentID: UUID
    public let authorDID: String
    public let sequence: UInt64
    public let payload: Data
    public let version: CollaborationProtocolVersion

    public init(
        documentID: UUID,
        authorDID: String,
        sequence: UInt64,
        payload: Data,
        version: CollaborationProtocolVersion = .foundation
    ) {
        self.documentID = documentID
        self.authorDID = authorDID
        self.sequence = sequence
        self.payload = payload
        self.version = version
    }
}

public enum CollaborationAvailability: Equatable, Sendable {
    case notConfigured
    case available
    case unavailable(reason: String)
}

public protocol CollaborationEngine: Sendable {
    func availability() async -> CollaborationAvailability
    func apply(_ operation: CollaborationOperation) async throws
}
