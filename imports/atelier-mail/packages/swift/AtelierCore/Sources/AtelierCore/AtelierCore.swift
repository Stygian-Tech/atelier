import Foundation

public struct DID: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) throws {
        guard rawValue.hasPrefix("did:") else {
            throw AtelierCoreError.invalidDID(rawValue)
        }
        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

public struct AtelierURI: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(app: String, resource: String, id: String) {
        self.rawValue = "atelier://\(app)/\(resource)/\(id)"
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

public struct AtelierID: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String = UUID().uuidString.lowercased()) {
        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

public enum AtelierNamespace {
    public static let root = "space.atelierwork"
    public static let platform = "\(root).platform"
    public static let mail = "\(root).mail"
    public static let workspace = "\(root).workspace"
    public static let tasks = "\(root).tasks"
}

public enum AtelierCoreError: Error, Equatable {
    case invalidDID(String)
    case invalidNamespace(String)
}

