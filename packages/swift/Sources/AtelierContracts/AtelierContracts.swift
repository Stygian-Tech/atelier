import Foundation

public struct DID: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(_ rawValue: String) throws {
        guard rawValue.hasPrefix("did:"), rawValue.count > 5 else {
            throw ContractError.invalidDID(rawValue)
        }
        self.rawValue = rawValue
    }

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }
}

public enum AtelierNamespace: Sendable {
    public static let root = "diy.atelier"
    public static let notes = "\(root).notes"
    public static let tasks = "\(root).tasks"
    public static let calendar = "\(root).calendar"
    public static let mail = "\(root).mail"
    public static let project = "\(root).project"
    public static let capture = "\(root).capture"
    public static let relation = "\(root).relation"
    public static let collaboration = "\(root).collaboration"
}

public enum AtelierProduct: String, Codable, CaseIterable, Sendable {
    case home, notes, mail, calendar, tasks
}

public enum OAuthPermissionSets: Sendable {
    public static func scopes(for product: AtelierProduct) -> [String] {
        switch product {
        case .home:
            ["atproto", "include:diy.atelier.auth.workspace"]
        case .notes:
            ["atproto", "include:diy.atelier.auth.notes", "include:diy.atelier.auth.workspace"]
        case .mail:
            ["atproto", "include:diy.atelier.auth.mail", "include:diy.atelier.auth.workspace"]
        case .calendar:
            ["atproto", "include:diy.atelier.auth.calendar", "include:diy.atelier.auth.workspace"]
        case .tasks:
            ["atproto", "include:diy.atelier.auth.tasks", "include:diy.atelier.auth.workspace"]
        }
    }
}

public enum DataBoundary: Sendable {
    public static let publicPDSDisclosure =
        "Atelier records saved to a standard AT Protocol repository are publicly readable. Do not store private or secret information until a compatible Permissioned Space is active."
}

public struct OpaqueProviderReference: Codable, Equatable, Sendable {
    public enum Provider: String, Codable, Sendable {
        case gmail, jmap, imap, googleCalendar, microsoftCalendar, caldav
    }

    public let provider: Provider
    public let opaqueID: String
    public let resourceKind: String
    public let sourceVersion: String

    public init(provider: Provider, opaqueID: String, resourceKind: String, sourceVersion: String) throws {
        guard !opaqueID.isEmpty, !resourceKind.isEmpty, !sourceVersion.isEmpty else {
            throw ContractError.invalidOpaqueProviderReference
        }
        self.provider = provider
        self.opaqueID = opaqueID
        self.resourceKind = resourceKind
        self.sourceVersion = sourceVersion
    }
}

public struct XRPCErrorEnvelope: Codable, Equatable, Sendable {
    public let error: String
    public let message: String

    public init(error: String, message: String) {
        self.error = error
        self.message = message
    }
}

public enum ContractError: Error, Equatable, Sendable {
    case invalidDID(String)
    case invalidOpaqueProviderReference
}
