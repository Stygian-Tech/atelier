import AtelierJobs
import Foundation

public enum WorkerJobKind: String, CaseIterable, Sendable {
    case pdsIndex = "pds.index"
    case pdsWrite = "pds.write"
    case searchReindex = "search.reindex"
    case notificationDeliver = "notification.deliver"
    case providerPurge = "provider.purge"
    case auditExpire = "audit.expire"
}

public protocol DurableJobFailure: Error, Sendable {
    var durableJobErrorCode: String { get }
}

public protocol DurableJobFailureClassifying: Sendable {
    func errorCode(for error: any Error) -> String
}

public struct DefaultDurableJobFailureClassifier: DurableJobFailureClassifying {
    public init() {}

    public func errorCode(for error: any Error) -> String {
        guard let failure = error as? any DurableJobFailure else {
            return "handler.failed"
        }

        let code = failure.durableJobErrorCode
        let isStableCode = !code.isEmpty
            && code.count <= 64
            && code == code.lowercased()
            && code.allSatisfy {
                $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "_" || $0 == "-")
            }
        // Never transform arbitrary provider error text into a durable code. Transformation can
        // preserve account identifiers or message fragments even after punctuation is stripped.
        return isStableCode ? code : "handler.failed"
    }
}

public struct DurableJobRetryPolicy: Equatable, Sendable {
    public let baseDelaySeconds: TimeInterval
    public let maximumDelaySeconds: TimeInterval

    public init(baseDelaySeconds: TimeInterval = 5, maximumDelaySeconds: TimeInterval = 300) {
        self.baseDelaySeconds = max(0, baseDelaySeconds)
        self.maximumDelaySeconds = max(0, maximumDelaySeconds)
    }

    public func shouldDeadLetter(_ job: DurableJob) -> Bool {
        job.attempts >= job.maxAttempts
    }

    public func delaySeconds(after job: DurableJob) -> TimeInterval {
        let exponent = max(0, min(job.attempts - 1, 10))
        return min(maximumDelaySeconds, baseDelaySeconds * pow(2, Double(exponent)))
    }
}

public enum DurableJobProcessorError: Error, Equatable, Sendable {
    case noHandlers
    case duplicateHandler(String)
    case leasedUnhandledKind(String)
}

public enum DurableJobProcessingOutcome: Equatable, Sendable {
    case idle
    case completed(UUID)
    case scheduledRetry(jobID: UUID, notBefore: Date, errorCode: String)
    case deadLettered(jobID: UUID, errorCode: String)
}

public struct DurableJobProcessor: Sendable {
    private let store: any DurableJobStore
    private let handlers: [String: any DurableJobHandler]
    private let retryPolicy: DurableJobRetryPolicy
    private let failureClassifier: any DurableJobFailureClassifying
    private let now: @Sendable () -> Date

    public init(
        store: any DurableJobStore,
        handlers: [any DurableJobHandler],
        retryPolicy: DurableJobRetryPolicy = .init(),
        failureClassifier: any DurableJobFailureClassifying = DefaultDurableJobFailureClassifier(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) throws {
        guard !handlers.isEmpty else { throw DurableJobProcessorError.noHandlers }

        var handlersByKind: [String: any DurableJobHandler] = [:]
        for handler in handlers {
            guard handlersByKind.updateValue(handler, forKey: handler.kind) == nil else {
                throw DurableJobProcessorError.duplicateHandler(handler.kind)
            }
        }

        self.store = store
        self.handlers = handlersByKind
        self.retryPolicy = retryPolicy
        self.failureClassifier = failureClassifier
        self.now = now
    }

    public var handledKinds: Set<String> { Set(handlers.keys) }

    public func processNext(
        workerID: String,
        leaseDuration: Duration
    ) async throws -> DurableJobProcessingOutcome {
        guard let job = try await store.lease(
            workerID: workerID,
            kinds: handledKinds,
            duration: leaseDuration
        ) else {
            return .idle
        }
        guard let handler = handlers[job.kind] else {
            throw DurableJobProcessorError.leasedUnhandledKind(job.kind)
        }

        do {
            try await handler.handle(job)
            try await store.complete(jobID: job.id, workerID: workerID)
            return .completed(job.id)
        } catch is CancellationError {
            // Leave the lease untouched. The durable store can reclaim it after expiry.
            throw CancellationError()
        } catch {
            let errorCode = failureClassifier.errorCode(for: error)
            if retryPolicy.shouldDeadLetter(job) {
                try await store.deadLetter(jobID: job.id, workerID: workerID, errorCode: errorCode)
                return .deadLettered(jobID: job.id, errorCode: errorCode)
            }

            let notBefore = now().addingTimeInterval(retryPolicy.delaySeconds(after: job))
            try await store.retry(
                jobID: job.id,
                workerID: workerID,
                notBefore: notBefore,
                errorCode: errorCode
            )
            return .scheduledRetry(jobID: job.id, notBefore: notBefore, errorCode: errorCode)
        }
    }

    public func run(configuration: WorkerRuntimeConfiguration) async throws {
        while !Task.isCancelled {
            let outcome = try await processNext(
                workerID: configuration.workerID,
                leaseDuration: configuration.leaseDuration
            )
            if outcome == .idle {
                try await Task<Never, Never>.sleep(for: configuration.idlePollInterval)
            }
        }
        throw CancellationError()
    }
}
