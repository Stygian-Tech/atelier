import AtelierJobs
import AtelierProviders
import Foundation

public enum MailSyncJobKind: String, CaseIterable, Codable, Sendable {
    case gmailInitial = "mail.gmail.initial"
    case gmailIncremental = "mail.gmail.incremental"
    case gmailReconcile = "mail.gmail.reconcile"
    case gmailRenewWatch = "mail.gmail.renew-watch"
    case jmapInitial = "mail.jmap.initial"
    case jmapIncremental = "mail.jmap.incremental"
    case imapInitial = "mail.imap.initial"
    case imapIncremental = "mail.imap.incremental"

    public var provider: MailProviderKind {
        switch self {
        case .gmailInitial, .gmailIncremental, .gmailReconcile, .gmailRenewWatch:
            .gmail
        case .jmapInitial, .jmapIncremental:
            .jmap
        case .imapInitial, .imapIncremental:
            .imap
        }
    }
}

/// The durable queue carries identifiers for protected provider state, never message content.
public struct MailSyncJobPayload: Codable, Equatable, Sendable {
    public let accountID: UUID
    public let protectedStateID: UUID?

    public init(accountID: UUID, protectedStateID: UUID? = nil) {
        self.accountID = accountID
        self.protectedStateID = protectedStateID
    }
}

public struct MailSyncExecutionRequest: Equatable, Sendable {
    public let jobID: UUID
    public let tenantID: UUID
    public let kind: MailSyncJobKind
    public let payload: MailSyncJobPayload
    public let idempotencyKey: String

    public init(
        jobID: UUID,
        tenantID: UUID,
        kind: MailSyncJobKind,
        payload: MailSyncJobPayload,
        idempotencyKey: String
    ) {
        self.jobID = jobID
        self.tenantID = tenantID
        self.kind = kind
        self.payload = payload
        self.idempotencyKey = idempotencyKey
    }
}

public protocol MailSyncExecutor: Sendable {
    var provider: MailProviderKind { get }
    func execute(_ request: MailSyncExecutionRequest) async throws
}

public enum MailSyncJobError: Error, Equatable, Sendable {
    case executorProviderMismatch(expected: MailProviderKind, actual: MailProviderKind)
    case unexpectedJobKind(String)
    case invalidPayload
    case unexpectedPayloadFields(Set<String>)
}

public struct MailSyncJobHandler: DurableJobHandler {
    public let jobKind: MailSyncJobKind
    private let executor: any MailSyncExecutor

    public var kind: String { jobKind.rawValue }

    public init(jobKind: MailSyncJobKind, executor: any MailSyncExecutor) throws {
        guard executor.provider == jobKind.provider else {
            throw MailSyncJobError.executorProviderMismatch(
                expected: jobKind.provider,
                actual: executor.provider
            )
        }
        self.jobKind = jobKind
        self.executor = executor
    }

    public func handle(_ job: DurableJob) async throws {
        guard job.kind == jobKind.rawValue else {
            throw MailSyncJobError.unexpectedJobKind(job.kind)
        }
        try Self.validatePayloadShape(job.payload)

        let payload: MailSyncJobPayload
        do {
            payload = try JSONDecoder().decode(MailSyncJobPayload.self, from: job.payload)
        } catch {
            throw MailSyncJobError.invalidPayload
        }

        try await executor.execute(MailSyncExecutionRequest(
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
            throw MailSyncJobError.invalidPayload
        }
        guard let dictionary = object as? [String: Any] else {
            throw MailSyncJobError.invalidPayload
        }
        let allowed = Set(["accountID", "protectedStateID"])
        let unexpected = Set(dictionary.keys).subtracting(allowed)
        guard unexpected.isEmpty else {
            throw MailSyncJobError.unexpectedPayloadFields(unexpected)
        }
    }
}

public enum MailSyncExecutorRegistryError: Error, Equatable, Sendable {
    case duplicateProvider(MailProviderKind)
}

public struct MailSyncExecutorRegistry: Sendable {
    private let executors: [MailProviderKind: any MailSyncExecutor]

    public init(executors: [any MailSyncExecutor]) throws {
        var byProvider: [MailProviderKind: any MailSyncExecutor] = [:]
        for executor in executors {
            guard byProvider.updateValue(executor, forKey: executor.provider) == nil else {
                throw MailSyncExecutorRegistryError.duplicateProvider(executor.provider)
            }
        }
        self.executors = byProvider
    }

    public var configuredProviders: Set<MailProviderKind> { Set(executors.keys) }

    public func handlers(for enabledProviders: Set<MailProviderKind>) throws -> [any DurableJobHandler] {
        try MailSyncJobKind.allCases.compactMap { kind in
            guard enabledProviders.contains(kind.provider), let executor = executors[kind.provider] else {
                return nil
            }
            return try MailSyncJobHandler(jobKind: kind, executor: executor)
        }
    }
}
