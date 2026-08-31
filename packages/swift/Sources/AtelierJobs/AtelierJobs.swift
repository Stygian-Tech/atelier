import AtelierContracts
import Foundation

public enum DurableJobState: String, Codable, Sendable {
    case pending, leased, succeeded, dead
}

public struct DurableJob: Codable, Equatable, Sendable {
    public let id: UUID
    public let tenantID: UUID
    public let kind: String
    public let idempotencyKey: String
    public let payload: Data
    public let attempts: Int
    public let maxAttempts: Int
    public let state: DurableJobState
    public let notBefore: Date
    public let leaseOwner: String?
    public let leaseExpiresAt: Date?

    public init(
        id: UUID = UUID(),
        tenantID: UUID,
        kind: String,
        idempotencyKey: String,
        payload: Data,
        attempts: Int = 0,
        maxAttempts: Int = 10,
        state: DurableJobState = .pending,
        notBefore: Date = Date(),
        leaseOwner: String? = nil,
        leaseExpiresAt: Date? = nil
    ) {
        self.id = id
        self.tenantID = tenantID
        self.kind = kind
        self.idempotencyKey = idempotencyKey
        self.payload = payload
        self.attempts = attempts
        self.maxAttempts = maxAttempts
        self.state = state
        self.notBefore = notBefore
        self.leaseOwner = leaseOwner
        self.leaseExpiresAt = leaseExpiresAt
    }
}

public struct EnqueueResult: Codable, Equatable, Sendable {
    public let id: UUID
    public let inserted: Bool

    public init(id: UUID, inserted: Bool) {
        self.id = id
        self.inserted = inserted
    }
}

public protocol DurableJobStore: Sendable {
    func enqueue(_ job: DurableJob) async throws -> EnqueueResult
    func lease(workerID: String, kinds: Set<String>, duration: Duration) async throws -> DurableJob?
    func complete(jobID: UUID, workerID: String) async throws
    func retry(jobID: UUID, workerID: String, notBefore: Date, errorCode: String) async throws
    func deadLetter(jobID: UUID, workerID: String, errorCode: String) async throws
}

public protocol DurableJobHandler: Sendable {
    var kind: String { get }
    func handle(_ job: DurableJob) async throws
}
