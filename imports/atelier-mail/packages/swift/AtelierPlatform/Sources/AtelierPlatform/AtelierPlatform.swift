import AtelierATProto
import AtelierCore
import AtelierMCP
import Foundation

public enum PermissionedStorageTarget: String, Codable, Sendable {
    case atelierKV
    case atprotoPermissionedData
}

public struct PermissionedRecordKey: Codable, Hashable, Sendable {
    public var ownerDID: DID
    public var namespace: String
    public var key: String

    public init(ownerDID: DID, namespace: String, key: String) throws {
        guard namespace.hasPrefix(AtelierNamespace.root + ".") else {
            throw AtelierCoreError.invalidNamespace(namespace)
        }
        self.ownerDID = ownerDID
        self.namespace = namespace
        self.key = key
    }
}

public struct PermissionedRecordEnvelope: Codable, Equatable, Sendable {
    public var key: PermissionedRecordKey
    public var schemaVersion: Int
    public var storageTarget: PermissionedStorageTarget
    public var encryptedPayload: Data
    public var encryptionKeyRef: String
    public var updatedAt: Date

    public init(
        key: PermissionedRecordKey,
        schemaVersion: Int,
        storageTarget: PermissionedStorageTarget = .atelierKV,
        encryptedPayload: Data,
        encryptionKeyRef: String,
        updatedAt: Date = Date()
    ) {
        self.key = key
        self.schemaVersion = schemaVersion
        self.storageTarget = storageTarget
        self.encryptedPayload = encryptedPayload
        self.encryptionKeyRef = encryptionKeyRef
        self.updatedAt = updatedAt
    }
}

public protocol PermissionedKVStore: Sendable {
    func get(_ key: PermissionedRecordKey) async throws -> PermissionedRecordEnvelope?
    func put(_ envelope: PermissionedRecordEnvelope) async throws
}

public struct CrossAppReference: Codable, Equatable, Sendable {
    public var source: AtelierURI
    public var target: AtelierURI
    public var ownerDID: DID
    public var createdAt: Date

    public init(source: AtelierURI, target: AtelierURI, ownerDID: DID, createdAt: Date = Date()) {
        self.source = source
        self.target = target
        self.ownerDID = ownerDID
        self.createdAt = createdAt
    }
}
