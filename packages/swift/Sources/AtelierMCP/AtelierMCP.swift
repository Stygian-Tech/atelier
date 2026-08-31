import AtelierContracts
import Foundation

public enum MCPToolRisk: String, Codable, Sendable {
    case read, write, sensitiveWrite
}

public struct MCPToolDescriptor: Codable, Equatable, Sendable {
    public let name: String
    public let description: String
    public let risk: MCPToolRisk
    public let requiredScopes: Set<String>

    public init(name: String, description: String, risk: MCPToolRisk, requiredScopes: Set<String>) {
        self.name = name
        self.description = description
        self.risk = risk
        self.requiredScopes = requiredScopes
    }
}

public struct MCPInvocationAuthorization: Equatable, Sendable {
    public let subject: DID
    public let grantedScopes: Set<String>
    public let approvalToken: String?

    public init(subject: DID, grantedScopes: Set<String>, approvalToken: String? = nil) {
        self.subject = subject
        self.grantedScopes = grantedScopes
        self.approvalToken = approvalToken
    }
}

public enum MCPAuthorizationError: Error, Equatable, Sendable {
    case missingScopes(Set<String>)
}

public struct MCPAuthorizationPolicy: Sendable {
    public init() {}

    /// Checks OAuth scope only. Sensitive-write approval is deliberately a separate, async
    /// authorization stage because it must verify content binding and atomically consume a nonce.
    public func authorizeScopes(
        _ tool: MCPToolDescriptor,
        invocation: MCPInvocationAuthorization
    ) throws {
        let missing = tool.requiredScopes.subtracting(invocation.grantedScopes)
        guard missing.isEmpty else { throw MCPAuthorizationError.missingScopes(missing) }
    }
}

public struct MCPApprovalClaim: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public let version: Int
    public let subject: DID
    public let toolName: String
    public let argumentDigest: String
    public let nonce: UUID
    public let expiresAt: Date

    public init(
        version: Int = MCPApprovalClaim.currentVersion,
        subject: DID,
        toolName: String,
        argumentDigest: String,
        nonce: UUID,
        expiresAt: Date
    ) {
        self.version = version
        self.subject = subject
        self.toolName = toolName
        self.argumentDigest = argumentDigest
        self.nonce = nonce
        self.expiresAt = expiresAt
    }
}

public struct MCPApprovalInvocation: Equatable, Sendable {
    public let subject: DID
    public let toolName: String
    public let argumentDigest: String

    public init(subject: DID, toolName: String, argumentDigest: String) {
        self.subject = subject
        self.toolName = toolName
        self.argumentDigest = argumentDigest
    }
}

public enum MCPApprovalAuthorizationError: Error, Equatable, Sendable {
    case explicitApprovalRequired
    case invalidApproval
    case subjectMismatch
    case toolMismatch
    case argumentsMismatch
    case expired
    case replayed
    case approvalStoreUnavailable
}

/// Implementations must atomically record a nonce once across every process that can execute
/// sensitive tools. Returning `false` means the nonce was previously consumed.
public protocol MCPSingleUseApprovalStore: Sendable {
    func consume(nonce: UUID, expiresAt: Date) async throws -> Bool
}

public protocol MCPApprovalAuthorizing: Sendable {
    var isConfigured: Bool { get }
    func authorize(token: String?, invocation: MCPApprovalInvocation) async throws
}

public enum MCPTransportContract: Sendable {
    public static let protocolVersion = "2025-06-18"
    public static let endpoint = "/mcp"
    public static let currentContentTypes = ["application/json"]
    public static let targetContentTypes = ["application/json", "text/event-stream"]
    public static let sessionHeader = "Mcp-Session-Id"
}

public enum AtelierMCPTools: Sendable {
    public static let all: [MCPToolDescriptor] = [
        .init(name: "atelier_search", description: "Search user-scoped Atelier content.", risk: .read, requiredScopes: ["atelier.search"]),
        .init(name: "notes_read", description: "Read a note visible to the authenticated user.", risk: .read, requiredScopes: ["notes.read"]),
        .init(name: "notes_create", description: "Create a note after the public-PDS disclosure is acknowledged.", risk: .write, requiredScopes: ["notes.write"]),
        .init(name: "tasks_create", description: "Create a task.", risk: .write, requiredScopes: ["tasks.write"]),
        .init(name: "calendar_update", description: "Update an Atelier-owned event.", risk: .write, requiredScopes: ["calendar.write"]),
        .init(name: "mail_draft", description: "Create a provider draft without sending it.", risk: .write, requiredScopes: ["mail.compose"]),
        .init(name: "mail_send", description: "Send an existing provider draft.", risk: .sensitiveWrite, requiredScopes: ["mail.send"]),
        .init(name: "atelier_delete", description: "Delete an Atelier resource.", risk: .sensitiveWrite, requiredScopes: ["atelier.delete"]),
        .init(name: "atelier_share", description: "Share an Atelier resource with another DID.", risk: .sensitiveWrite, requiredScopes: ["atelier.share"]),
        .init(name: "provider_disconnect", description: "Disconnect and purge a provider account.", risk: .sensitiveWrite, requiredScopes: ["provider.admin"]),
    ]
}
