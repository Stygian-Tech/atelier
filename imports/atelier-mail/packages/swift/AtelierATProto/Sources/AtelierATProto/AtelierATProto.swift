import AtelierCore
import Foundation

public struct ATProtoIdentity: Codable, Equatable, Sendable {
    public var did: DID
    public var handle: String
    public var pdsEndpoint: URL
    public var didDocumentUpdatedAt: Date?

    public init(did: DID, handle: String, pdsEndpoint: URL, didDocumentUpdatedAt: Date? = nil) {
        self.did = did
        self.handle = handle
        self.pdsEndpoint = pdsEndpoint
        self.didDocumentUpdatedAt = didDocumentUpdatedAt
    }
}

public struct OAuthSession: Codable, Equatable, Sendable {
    public var subject: DID
    public var accessTokenRef: String
    public var refreshTokenRef: String?
    public var expiresAt: Date

    public init(subject: DID, accessTokenRef: String, refreshTokenRef: String?, expiresAt: Date) {
        self.subject = subject
        self.accessTokenRef = accessTokenRef
        self.refreshTokenRef = refreshTokenRef
        self.expiresAt = expiresAt
    }
}

public protocol ATProtoIdentityResolving: Sendable {
    func resolve(handleOrDID: String) async throws -> ATProtoIdentity
}

public struct StaticIdentityResolver: ATProtoIdentityResolving {
    public var identity: ATProtoIdentity

    public init(identity: ATProtoIdentity) {
        self.identity = identity
    }

    public func resolve(handleOrDID: String) async throws -> ATProtoIdentity {
        identity
    }
}
