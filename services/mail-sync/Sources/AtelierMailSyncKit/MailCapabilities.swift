import AtelierProviders
import Foundation

public enum MailIntegrationRole: String, Codable, Sendable {
    case gmailFirst
    case jmapStandardsBased
    case imapCompatibility
}

public enum MailAdapterAvailability: String, Codable, Sendable {
    case contractOnly
}

public struct MailProviderCapabilityDescriptor: Equatable, Sendable {
    public let provider: MailProviderKind
    public let role: MailIntegrationRole
    public let capabilities: ProviderCapabilities
    public let availability: MailAdapterAvailability

    public init(
        provider: MailProviderKind,
        role: MailIntegrationRole,
        capabilities: ProviderCapabilities,
        availability: MailAdapterAvailability = .contractOnly
    ) {
        self.provider = provider
        self.role = role
        self.capabilities = capabilities
        self.availability = availability
    }
}

public enum MailSyncCapabilities {
    /// Product order is intentional: Gmail is the first implementation target, followed by
    /// standards-based JMAP and then the IMAP/SMTP compatibility surface.
    public static let orderedProviders: [MailProviderCapabilityDescriptor] = [
        .init(provider: .gmail, role: .gmailFirst, capabilities: MailProviderKind.gmail.capabilities),
        .init(provider: .jmap, role: .jmapStandardsBased, capabilities: MailProviderKind.jmap.capabilities),
        .init(provider: .imap, role: .imapCompatibility, capabilities: MailProviderKind.imap.capabilities),
    ]
}
