import AtelierJobs
import AtelierMailSyncKit
import AtelierProviders
import AtelierWorkerKit
import Foundation
import Testing

private actor RecordingMailExecutor: MailSyncExecutor {
    nonisolated let provider: MailProviderKind
    private var requests: [MailSyncExecutionRequest] = []

    init(provider: MailProviderKind) {
        self.provider = provider
    }

    func execute(_ request: MailSyncExecutionRequest) async throws {
        requests.append(request)
    }

    func recordedRequests() -> [MailSyncExecutionRequest] { requests }
}

private let mailEnvironment = [
    "ATELIER_ENV": "development",
    "DATABASE_URL": "postgresql://private.invalid/atelier",
    "ATELIER_PROVIDER_ID_HMAC_KEY": "test-only-secret",
    "GOOGLE_CLOUD_PROJECT": "atelier-test",
    "GOOGLE_KMS_KEY_RESOURCE": "projects/test/locations/test/keyRings/test/cryptoKeys/test",
    "GOOGLE_PROVIDER_CACHE_BUCKET": "atelier-provider-test",
    "GOOGLE_DURABLE_BUCKET": "atelier-durable-test",
    "GOOGLE_WORKLOAD_IDENTITY_PROVIDER": "projects/1/locations/global/workloadIdentityPools/test/providers/test",
    "GMAIL_PUBSUB_TOPIC": "projects/test/topics/gmail",
]

@Test func capabilityVocabularyIsGmailFirstAndDoesNotClaimAdapters() {
    #expect(MailSyncCapabilities.orderedProviders.map(\.provider) == [.gmail, .jmap, .imap])
    #expect(MailSyncCapabilities.orderedProviders.map(\.role) == [
        .gmailFirst, .jmapStandardsBased, .imapCompatibility,
    ])
    #expect(MailSyncCapabilities.orderedProviders.allSatisfy { $0.availability == .contractOnly })
    #expect(MailSyncCapabilities.orderedProviders[0].capabilities.labels)
    #expect(MailSyncCapabilities.orderedProviders[1].capabilities.folders)
    #expect(MailSyncCapabilities.orderedProviders[2].capabilities.incrementalSync)
}

@Test func configurationAndReadinessFailClosed() throws {
    var missingTopic = mailEnvironment
    missingTopic.removeValue(forKey: "GMAIL_PUBSUB_TOPIC")
    #expect(throws: RuntimeConfigurationError.missingVariable("GMAIL_PUBSUB_TOPIC")) {
        try MailSyncServiceConfiguration(environment: missingTopic)
    }

    let configuration = try MailSyncServiceConfiguration(environment: mailEnvironment)
    let registry = try MailSyncExecutorRegistry(executors: [])
    let readiness = MailSyncService.readiness(
        configuration: configuration,
        jobStoreAdapterAvailable: false,
        executorRegistry: registry
    )
    #expect(!readiness.isReady)
    #expect(readiness.blockers == [
        "Postgres durable job-store adapter is not implemented",
        "gmail mail provider adapter is not implemented",
    ])
}

@Test func typedHandlerRoutesOnlyMinimalProtectedStateIdentifiers() async throws {
    let executor = RecordingMailExecutor(provider: .gmail)
    let handler = try MailSyncJobHandler(jobKind: .gmailIncremental, executor: executor)
    let payload = MailSyncJobPayload(accountID: UUID(), protectedStateID: UUID())
    let job = DurableJob(
        tenantID: UUID(),
        kind: MailSyncJobKind.gmailIncremental.rawValue,
        idempotencyKey: "gmail-history-opaque-key",
        payload: try JSONEncoder().encode(payload),
        attempts: 1,
        state: .leased
    )

    try await handler.handle(job)

    let request = try #require(await executor.recordedRequests().first)
    #expect(request.jobID == job.id)
    #expect(request.kind == .gmailIncremental)
    #expect(request.payload == payload)
}

@Test func typedHandlerRejectsProviderContentInTheQueueEnvelope() async throws {
    let executor = RecordingMailExecutor(provider: .gmail)
    let handler = try MailSyncJobHandler(jobKind: .gmailInitial, executor: executor)
    let accountID = UUID().uuidString
    let payload = Data(#"{"accountID":"\#(accountID)","subject":"must-not-cross-this-seam"}"#.utf8)
    let job = DurableJob(
        tenantID: UUID(),
        kind: MailSyncJobKind.gmailInitial.rawValue,
        idempotencyKey: "opaque-key",
        payload: payload,
        attempts: 1,
        state: .leased
    )

    await #expect(throws: MailSyncJobError.unexpectedPayloadFields(["subject"])) {
        try await handler.handle(job)
    }
    #expect(await executor.recordedRequests().isEmpty)
}

@Test func providerAndJobKindMustAgreeBeforeExecution() {
    let executor = RecordingMailExecutor(provider: .jmap)
    #expect(throws: MailSyncJobError.executorProviderMismatch(expected: .gmail, actual: .jmap)) {
        _ = try MailSyncJobHandler(jobKind: .gmailInitial, executor: executor)
    }
}
