import AtelierWorkerKit
import Foundation

public struct CalendarSyncServiceConfiguration: Equatable, Sendable {
    public let protectedStorage: ProtectedProviderStorageConfiguration
    public let enabledSources: Set<CalendarSourceKind>

    public init(environment values: [String: String]) throws {
        let reader = EnvironmentReader(values)
        protectedStorage = try ProtectedProviderStorageConfiguration(environment: values)

        let defaultSources = CalendarSyncCapabilities.orderedSources.map(\.source.rawValue).joined(separator: ",")
        let sourceList = reader.optional("ATELIER_CALENDAR_SYNC_SOURCES") ?? defaultSources
        let sourceNames = sourceList.split(separator: ",", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !sourceNames.isEmpty, sourceNames.allSatisfy({ !$0.isEmpty }) else {
            throw RuntimeConfigurationError.invalidValue("ATELIER_CALENDAR_SYNC_SOURCES")
        }

        var sources: Set<CalendarSourceKind> = []
        for name in sourceNames {
            guard let source = CalendarSourceKind(rawValue: name) else {
                throw RuntimeConfigurationError.invalidValue("ATELIER_CALENDAR_SYNC_SOURCES")
            }
            sources.insert(source)
        }
        enabledSources = sources
    }
}

public enum CalendarSyncService {
    public static func readiness(
        configuration: CalendarSyncServiceConfiguration,
        jobStoreAdapterAvailable: Bool,
        executorRegistry: CalendarSyncExecutorRegistry
    ) -> ServiceReadiness {
        var blockers: [String] = []
        if !jobStoreAdapterAvailable {
            blockers.append("Postgres durable job-store adapter is not implemented")
        }

        let configured = executorRegistry.configuredSources
        for descriptor in CalendarSyncCapabilities.orderedSources
        where configuration.enabledSources.contains(descriptor.source)
            && !configured.contains(descriptor.source) {
            blockers.append("\(descriptor.source.rawValue) calendar source adapter is not implemented")
        }
        return ServiceReadiness(blockers: blockers)
    }
}

public enum CalendarSyncStartupError: Error, Sendable, CustomStringConvertible {
    case notReady([String])

    public var description: String {
        switch self {
        case .notReady(let blockers):
            "atelier-calendar-sync is not ready: \(blockers.joined(separator: "; "))"
        }
    }
}
