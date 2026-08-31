import AtelierProviders
import AtelierWorkerKit
import Foundation

public struct MailSyncServiceConfiguration: Equatable, Sendable {
    public let protectedStorage: ProtectedProviderStorageConfiguration
    public let enabledProviders: Set<MailProviderKind>
    public let gmailPubSubTopic: String?
    public let jmapConfigurationReference: String?
    public let imapConfigurationReference: String?

    public init(environment values: [String: String]) throws {
        let reader = EnvironmentReader(values)
        protectedStorage = try ProtectedProviderStorageConfiguration(environment: values)

        let providerList = reader.optional("ATELIER_MAIL_SYNC_PROVIDERS") ?? MailProviderKind.gmail.rawValue
        let providerNames = providerList.split(separator: ",", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !providerNames.isEmpty, providerNames.allSatisfy({ !$0.isEmpty }) else {
            throw RuntimeConfigurationError.invalidValue("ATELIER_MAIL_SYNC_PROVIDERS")
        }

        var providers: Set<MailProviderKind> = []
        for name in providerNames {
            guard let provider = MailProviderKind(rawValue: name) else {
                throw RuntimeConfigurationError.invalidValue("ATELIER_MAIL_SYNC_PROVIDERS")
            }
            providers.insert(provider)
        }
        enabledProviders = providers

        gmailPubSubTopic = try Self.providerReference(
            "GMAIL_PUBSUB_TOPIC",
            required: providers.contains(.gmail),
            reader: reader
        )
        jmapConfigurationReference = try Self.providerReference(
            "ATELIER_JMAP_CONFIGURATION_REF",
            required: providers.contains(.jmap),
            reader: reader
        )
        imapConfigurationReference = try Self.providerReference(
            "ATELIER_IMAP_CONFIGURATION_REF",
            required: providers.contains(.imap),
            reader: reader
        )
    }

    private static func providerReference(
        _ name: String,
        required: Bool,
        reader: EnvironmentReader
    ) throws -> String? {
        required ? try reader.require(name) : reader.optional(name)
    }
}

public enum MailSyncService {
    public static func readiness(
        configuration: MailSyncServiceConfiguration,
        jobStoreAdapterAvailable: Bool,
        executorRegistry: MailSyncExecutorRegistry
    ) -> ServiceReadiness {
        var blockers: [String] = []
        if !jobStoreAdapterAvailable {
            blockers.append("Postgres durable job-store adapter is not implemented")
        }

        let configured = executorRegistry.configuredProviders
        for descriptor in MailSyncCapabilities.orderedProviders
        where configuration.enabledProviders.contains(descriptor.provider)
            && !configured.contains(descriptor.provider) {
            blockers.append("\(descriptor.provider.rawValue) mail provider adapter is not implemented")
        }
        return ServiceReadiness(blockers: blockers)
    }
}

public enum MailSyncStartupError: Error, Sendable, CustomStringConvertible {
    case notReady([String])

    public var description: String {
        switch self {
        case .notReady(let blockers):
            "atelier-mail-sync is not ready: \(blockers.joined(separator: "; "))"
        }
    }
}
