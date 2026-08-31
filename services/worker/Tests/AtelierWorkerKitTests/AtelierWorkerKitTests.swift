import AtelierJobs
import AtelierWorkerKit
import Foundation
import Testing

private actor RecordingStore: DurableJobStore {
    struct Snapshot: Equatable, Sendable {
        var completed: [UUID] = []
        var retries: [(UUID, Date, String)] = []
        var deadLetters: [(UUID, String)] = []

        static func == (lhs: Snapshot, rhs: Snapshot) -> Bool {
            lhs.completed == rhs.completed
                && lhs.retries.elementsEqual(rhs.retries, by: ==)
                && lhs.deadLetters.elementsEqual(rhs.deadLetters, by: ==)
        }
    }

    private var nextJob: DurableJob?
    private var completed: [UUID] = []
    private var retries: [(UUID, Date, String)] = []
    private var deadLetters: [(UUID, String)] = []

    init(nextJob: DurableJob?) {
        self.nextJob = nextJob
    }

    func enqueue(_ job: DurableJob) async throws -> EnqueueResult {
        nextJob = job
        return EnqueueResult(id: job.id, inserted: true)
    }

    func lease(workerID: String, kinds: Set<String>, duration: Duration) async throws -> DurableJob? {
        guard let job = nextJob, kinds.contains(job.kind) else { return nil }
        nextJob = nil
        return job
    }

    func complete(jobID: UUID, workerID: String) async throws {
        completed.append(jobID)
    }

    func retry(jobID: UUID, workerID: String, notBefore: Date, errorCode: String) async throws {
        retries.append((jobID, notBefore, errorCode))
    }

    func deadLetter(jobID: UUID, workerID: String, errorCode: String) async throws {
        deadLetters.append((jobID, errorCode))
    }

    func snapshot() -> Snapshot {
        Snapshot(completed: completed, retries: retries, deadLetters: deadLetters)
    }
}

private actor HandledJobRecorder {
    private var ids: [UUID] = []

    func record(_ id: UUID) { ids.append(id) }
    func recordedIDs() -> [UUID] { ids }
}

private struct RecordingHandler: DurableJobHandler {
    let kind: String
    let recorder: HandledJobRecorder

    func handle(_ job: DurableJob) async throws {
        await recorder.record(job.id)
    }
}

private struct ExpectedFailure: DurableJobFailure {
    let durableJobErrorCode: String
}

private struct FailingHandler: DurableJobHandler {
    let kind: String
    let errorCode: String

    func handle(_ job: DurableJob) async throws {
        throw ExpectedFailure(durableJobErrorCode: errorCode)
    }
}

private let configuredEnvironment = [
    "ATELIER_ENV": "development",
    "DATABASE_URL": "postgresql://private.invalid/atelier",
]

@Test func configurationFailsClosedWithoutDurableStorage() {
    #expect(throws: RuntimeConfigurationError.missingVariable("DATABASE_URL")) {
        try WorkerRuntimeConfiguration(environment: ["ATELIER_ENV": "development"])
    }
    #expect(throws: RuntimeConfigurationError.unresolvedPlaceholder("DATABASE_URL")) {
        try WorkerRuntimeConfiguration(environment: [
            "ATELIER_ENV": "development",
            "DATABASE_URL": "__SET_FROM_RAILWAY_POSTGRES_REFERENCE__",
        ])
    }
    #expect(!DurableJobStoreBootstrap.readiness.isReady)
}

@Test func processorCompletesAHandledLease() async throws {
    let job = DurableJob(
        tenantID: UUID(),
        kind: WorkerJobKind.pdsIndex.rawValue,
        idempotencyKey: "tenant-safe-key",
        payload: Data(),
        attempts: 1,
        state: .leased
    )
    let store = RecordingStore(nextJob: job)
    let recorder = HandledJobRecorder()
    let processor = try DurableJobProcessor(
        store: store,
        handlers: [RecordingHandler(kind: job.kind, recorder: recorder)]
    )

    let outcome = try await processor.processNext(workerID: "worker-1", leaseDuration: .seconds(60))

    #expect(outcome == .completed(job.id))
    #expect(await recorder.recordedIDs() == [job.id])
    #expect(await store.snapshot().completed == [job.id])
}

@Test func processorUsesStableRetryAndDeadLetterTransitions() async throws {
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let retryJob = DurableJob(
        tenantID: UUID(),
        kind: "mail.gmail.incremental",
        idempotencyKey: "retry-key",
        payload: Data(),
        attempts: 2,
        maxAttempts: 3,
        state: .leased
    )
    let retryStore = RecordingStore(nextJob: retryJob)
    let retryProcessor = try DurableJobProcessor(
        store: retryStore,
        handlers: [FailingHandler(kind: retryJob.kind, errorCode: "Provider Timeout: account@example.com")],
        retryPolicy: .init(baseDelaySeconds: 5, maximumDelaySeconds: 60),
        now: { now }
    )

    let retryOutcome = try await retryProcessor.processNext(workerID: "worker-1", leaseDuration: .seconds(60))
    let expectedRetryDate = now.addingTimeInterval(10)
    #expect(retryOutcome == .scheduledRetry(
        jobID: retryJob.id,
        notBefore: expectedRetryDate,
        errorCode: "handler.failed"
    ))
    #expect(await retryStore.snapshot().retries.count == 1)

    let deadJob = DurableJob(
        tenantID: UUID(),
        kind: "mail.gmail.incremental",
        idempotencyKey: "dead-key",
        payload: Data(),
        attempts: 3,
        maxAttempts: 3,
        state: .leased
    )
    let deadStore = RecordingStore(nextJob: deadJob)
    let deadProcessor = try DurableJobProcessor(
        store: deadStore,
        handlers: [FailingHandler(kind: deadJob.kind, errorCode: "provider.timeout")]
    )

    let deadOutcome = try await deadProcessor.processNext(workerID: "worker-1", leaseDuration: .seconds(60))
    #expect(deadOutcome == .deadLettered(jobID: deadJob.id, errorCode: "provider.timeout"))
    let deadLetters = await deadStore.snapshot().deadLetters
    #expect(deadLetters.count == 1)
    #expect(deadLetters.first?.0 == deadJob.id)
    #expect(deadLetters.first?.1 == "provider.timeout")
}

@Test func genericWorkerJobVocabularyMatchesTheDurableQueueContract() throws {
    #expect(Set(WorkerJobKind.allCases.map(\.rawValue)) == [
        "pds.index", "pds.write", "search.reindex",
        "notification.deliver", "provider.purge", "audit.expire",
    ])
    #expect(throws: DurableJobProcessorError.noHandlers) {
        _ = try DurableJobProcessor(
            store: RecordingStore(nextJob: nil),
            handlers: []
        )
    }
    _ = try WorkerRuntimeConfiguration(environment: configuredEnvironment)
}
