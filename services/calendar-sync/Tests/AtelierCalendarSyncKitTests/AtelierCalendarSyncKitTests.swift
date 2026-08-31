import AtelierCalendarSyncKit
import AtelierJobs
import AtelierProviders
import AtelierWorkerKit
import Foundation
import Testing

private actor RecordingCalendarExecutor: CalendarSyncExecutor {
    nonisolated let source: CalendarSourceKind
    private var requests: [CalendarSyncExecutionRequest] = []

    init(source: CalendarSourceKind) {
        self.source = source
    }

    func execute(_ request: CalendarSyncExecutionRequest) async throws {
        requests.append(request)
    }

    func recordedRequests() -> [CalendarSyncExecutionRequest] { requests }
}

private let calendarEnvironment = [
    "ATELIER_ENV": "development",
    "DATABASE_URL": "postgresql://private.invalid/atelier",
    "ATELIER_PROVIDER_ID_HMAC_KEY": "test-only-secret",
    "GOOGLE_CLOUD_PROJECT": "atelier-test",
    "GOOGLE_KMS_KEY_RESOURCE": "projects/test/locations/test/keyRings/test/cryptoKeys/test",
    "GOOGLE_PROVIDER_CACHE_BUCKET": "atelier-provider-test",
    "GOOGLE_DURABLE_BUCKET": "atelier-durable-test",
    "GOOGLE_WORKLOAD_IDENTITY_PROVIDER": "projects/1/locations/global/workloadIdentityPools/test/providers/test",
]

@Test func sourceVocabularyIsExplicitAndOwnershipAware() {
    #expect(CalendarSyncCapabilities.orderedSources.map(\.source) == [
        .ics, .community, .googleCalendar, .microsoftCalendar, .caldav,
    ])
    #expect(CalendarSyncCapabilities.orderedSources.map(\.transport) == [
        .iCalendarFeed, .communityFeed, .googleCalendarAPI, .microsoftGraph, .calDAV,
    ])
    #expect(CalendarSyncCapabilities.orderedSources.prefix(2).allSatisfy {
        $0.sourceAuthority == .subscribedFeed && !$0.writeback
    })
    #expect(CalendarSyncCapabilities.orderedSources.dropFirst(2).allSatisfy {
        $0.sourceAuthority == .provider && $0.writeback
    })
    #expect(CalendarSyncCapabilities.orderedSources.allSatisfy {
        $0.availability == .contractOnly && $0.preservesCompleteICalendar
    })
    #expect(!CalendarSyncCapabilities.orderedSources.last!.pushNotifications)
}

@Test func configurationAndReadinessFailClosed() throws {
    var missingEncryptionBoundary = calendarEnvironment
    missingEncryptionBoundary.removeValue(forKey: "ATELIER_PROVIDER_ID_HMAC_KEY")
    #expect(throws: RuntimeConfigurationError.missingVariable("ATELIER_PROVIDER_ID_HMAC_KEY")) {
        try CalendarSyncServiceConfiguration(environment: missingEncryptionBoundary)
    }

    let configuration = try CalendarSyncServiceConfiguration(environment: calendarEnvironment)
    let registry = try CalendarSyncExecutorRegistry(executors: [])
    let readiness = CalendarSyncService.readiness(
        configuration: configuration,
        jobStoreAdapterAvailable: false,
        executorRegistry: registry
    )
    #expect(!readiness.isReady)
    #expect(readiness.blockers == [
        "Postgres durable job-store adapter is not implemented",
        "ics calendar source adapter is not implemented",
        "community calendar source adapter is not implemented",
        "googleCalendar calendar source adapter is not implemented",
        "microsoftCalendar calendar source adapter is not implemented",
        "caldav calendar source adapter is not implemented",
    ])
}

@Test func typedHandlerRoutesOnlyProtectedCalendarIdentifiers() async throws {
    let executor = RecordingCalendarExecutor(source: .caldav)
    let handler = try CalendarSyncJobHandler(jobKind: .caldavIncremental, executor: executor)
    let payload = CalendarSyncJobPayload(protectedSourceID: UUID(), protectedStateID: UUID())
    let job = DurableJob(
        tenantID: UUID(),
        kind: CalendarSyncJobKind.caldavIncremental.rawValue,
        idempotencyKey: "caldav-etag-opaque-key",
        payload: try JSONEncoder().encode(payload),
        attempts: 1,
        state: .leased
    )

    try await handler.handle(job)

    let request = try #require(await executor.recordedRequests().first)
    #expect(request.jobID == job.id)
    #expect(request.kind == .caldavIncremental)
    #expect(request.payload == payload)
}

@Test func typedHandlerRejectsCalendarContentInTheQueueEnvelope() async throws {
    let executor = RecordingCalendarExecutor(source: .ics)
    let handler = try CalendarSyncJobHandler(jobKind: .icsRefresh, executor: executor)
    let sourceID = UUID().uuidString
    let payload = Data(#"{"protectedSourceID":"\#(sourceID)","title":"must-not-cross-this-seam"}"#.utf8)
    let job = DurableJob(
        tenantID: UUID(),
        kind: CalendarSyncJobKind.icsRefresh.rawValue,
        idempotencyKey: "feed-etag-opaque-key",
        payload: payload,
        attempts: 1,
        state: .leased
    )

    await #expect(throws: CalendarSyncJobError.unexpectedPayloadFields(["title"])) {
        try await handler.handle(job)
    }
    #expect(await executor.recordedRequests().isEmpty)
}

@Test func sourceAndJobKindMustAgreeBeforeExecution() {
    let executor = RecordingCalendarExecutor(source: .community)
    #expect(throws: CalendarSyncJobError.executorSourceMismatch(expected: .ics, actual: .community)) {
        _ = try CalendarSyncJobHandler(jobKind: .icsRefresh, executor: executor)
    }
}
