import AtelierCore
import Foundation

public enum MCPToolRisk: String, Codable, Sendable {
    case read
    case write
    case sensitiveWrite
}

public struct MCPToolDescriptor: Codable, Equatable, Sendable {
    public var name: String
    public var description: String
    public var risk: MCPToolRisk
    public var requiredScopes: [String]

    public init(name: String, description: String, risk: MCPToolRisk, requiredScopes: [String]) {
        self.name = name
        self.description = description
        self.risk = risk
        self.requiredScopes = requiredScopes
    }
}

public struct MCPToolRegistry: Sendable {
    public var tools: [MCPToolDescriptor]

    public init(tools: [MCPToolDescriptor] = []) {
        self.tools = tools
    }

    public func registering(_ tool: MCPToolDescriptor) -> MCPToolRegistry {
        var next = tools
        next.append(tool)
        return MCPToolRegistry(tools: next)
    }
}

public enum MailMCPTools {
    public static let readOnly: [MCPToolDescriptor] = [
        .init(
            name: "mail_search_threads",
            description: "Search synced mail threads visible to the authenticated DID.",
            risk: .read,
            requiredScopes: ["mail.read"]
        ),
        .init(
            name: "mail_read_thread",
            description: "Read a single synced mail thread by Atelier thread id.",
            risk: .read,
            requiredScopes: ["mail.read"]
        ),
        .init(
            name: "mail_list_mailboxes",
            description: "List normalized mailboxes across connected accounts.",
            risk: .read,
            requiredScopes: ["mail.read"]
        ),
        .init(
            name: "mail_summarize_thread_context",
            description: "Return context needed by an agent to summarize a thread without exposing unrelated mailbox data.",
            risk: .read,
            requiredScopes: ["mail.read", "mail.agent"]
        )
    ]

    public static let gatedWrites: [MCPToolDescriptor] = [
        .init(name: "mail_archive_thread", description: "Archive a thread.", risk: .write, requiredScopes: ["mail.write"]),
        .init(name: "mail_mark_read", description: "Mark a thread read or unread.", risk: .write, requiredScopes: ["mail.write"]),
        .init(name: "mail_draft_reply", description: "Create a reply draft.", risk: .write, requiredScopes: ["mail.compose"]),
        .init(name: "mail_send_draft", description: "Send an existing draft.", risk: .sensitiveWrite, requiredScopes: ["mail.send"])
    ]
}
