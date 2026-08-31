import AtelierJobs
import Foundation

public enum CalendarSyncJobKind: String, CaseIterable, Codable, Sendable {
    case icsRefresh = "calendar.ics.refresh"
    case communityRefresh = "calendar.community.refresh"
    case googleInitial = "calendar.google.initial"
    case googleIncremental = "calendar.google.incremental"
    case microsoftInitial = "calendar.microsoft.initial"
    case microsoftIncremental = "calendar.microsoft.incremental"
    case caldavInitial = "calendar.caldav.initial"
    case caldavIncremental = "calendar.caldav.incremental"

    public var source: CalendarSourceKind {
        switch self {
        case .icsRefresh:
            .ics
        case .communityRefresh:
            .community
        case .googleInitial, .googleIncremental:
            .googleCalendar
        case .microsoftInitial, .microsoftIncremental:
            .microsoftCalendar
        case .caldavInitial, .caldavIncremental:
            .caldav
        }
    }
}

/// The durable queue references protected source and cursor records. Event titles, locations,
/// attendee data, and raw iCalendar are intentionally excluded from this envelope.
public struct CalendarSyncJobPayload: Codable, Equatable, Sendable {
    public let protectedSourceID: UUID
    public let protectedStateID: UUID?

    public init(protectedSourceID: UUID, protectedStateID: UUID? = nil) {
        self.protectedSourceID = protectedSourceID
        self.protectedStateID = protectedStateID
    }
}

public struct CalendarSyncExecutionRequest: Equatable, Sendable {
    public let jobID: UUID
    public let tenantID: UUID
    public let kind: CalendarSyncJobKind
    public let payload: CalendarSyncJobPayload
    public let idempotencyKey: String

    public init(
        jobID: UUID,
        tenantID: UUID,
        kind: CalendarSyncJobKind,
        payload: CalendarSyncJobPayload,
        idempotencyKey: String
    ) {
        self.jobID = jobID
        self.tenantID = tenantID
        self.kind = kind
        self.payload = payload
        self.idempotencyKey = idempotencyKey
    }
}

public protocol CalendarSyncExecutor: Sendable {
    var source: CalendarSourceKind { get }
    func execute(_ request: CalendarSyncExecutionRequest) async throws
}

public enum CalendarSyncJobError: Error, Equatable, Sendable {
    case executorSourceMismatch(expected: CalendarSourceKind, actual: CalendarSourceKind)
    case unexpectedJobKind(String)
    case invalidPayload
    case unexpectedPayloadFields(Set<String>)
}

public struct CalendarSyncJobHandler: DurableJobHandler {
    public let jobKind: CalendarSyncJobKind
    private let executor: any CalendarSyncExecutor

    public var kind: String { jobKind.rawValue }

    public init(jobKind: CalendarSyncJobKind, executor: any CalendarSyncExecutor) throws {
        guard executor.source == jobKind.source else {
            throw CalendarSyncJobError.executorSourceMismatch(
                expected: jobKind.source,
                actual: executor.source
            )
        }
        self.jobKind = jobKind
        self.executor = executor
    }

    public func handle(_ job: DurableJob) async throws {
        guard job.kind == jobKind.rawValue else {
            throw CalendarSyncJobError.unexpectedJobKind(job.kind)
        }
        try Self.validatePayloadShape(job.payload)

        let payload: CalendarSyncJobPayload
        do {
            payload = try JSONDecoder().decode(CalendarSyncJobPayload.self, from: job.payload)
        } catch {
            throw CalendarSyncJobError.invalidPayload
        }

        try await executor.execute(CalendarSyncExecutionRequest(
            jobID: job.id,
            tenantID: job.tenantID,
            kind: jobKind,
            payload: payload,
            idempotencyKey: job.idempotencyKey
        ))
    }

    private static func validatePayloadShape(_ data: Data) throws {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw CalendarSyncJobError.invalidPayload
        }
        guard let dictionary = object as? [String: Any] else {
            throw CalendarSyncJobError.invalidPayload
        }
        let allowed = Set(["protectedSourceID", "protectedStateID"])
        let unexpected = Set(dictionary.keys).subtracting(allowed)
        guard unexpected.isEmpty else {
            throw CalendarSyncJobError.unexpectedPayloadFields(unexpected)
        }
    }
}

public enum CalendarSyncExecutorRegistryError: Error, Equatable, Sendable {
    case duplicateSource(CalendarSourceKind)
}

public struct CalendarSyncExecutorRegistry: Sendable {
    private let executors: [CalendarSourceKind: any CalendarSyncExecutor]

    public init(executors: [any CalendarSyncExecutor]) throws {
        var bySource: [CalendarSourceKind: any CalendarSyncExecutor] = [:]
        for executor in executors {
            guard bySource.updateValue(executor, forKey: executor.source) == nil else {
                throw CalendarSyncExecutorRegistryError.duplicateSource(executor.source)
            }
        }
        self.executors = bySource
    }

    public var configuredSources: Set<CalendarSourceKind> { Set(executors.keys) }

    public func handlers(for enabledSources: Set<CalendarSourceKind>) throws -> [any DurableJobHandler] {
        try CalendarSyncJobKind.allCases.compactMap { kind in
            guard enabledSources.contains(kind.source), let executor = executors[kind.source] else {
                return nil
            }
            return try CalendarSyncJobHandler(jobKind: kind, executor: executor)
        }
    }
}
