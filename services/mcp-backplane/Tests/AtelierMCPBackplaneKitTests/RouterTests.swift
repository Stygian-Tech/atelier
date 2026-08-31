import AtelierContracts
import AtelierMCP
import AtelierMCPBackplaneKit
import Foundation
import Hummingbird
import HummingbirdTesting
import HTTPTypes
import Testing

private actor ExecutionRecorder {
    private var arguments: [JSONValue] = []

    func record(_ value: JSONValue) { arguments.append(value) }
    func count() -> Int { arguments.count }
}

private struct ReadyExecutor: MCPToolExecutor {
    let isConfigured = true
    let recorder: ExecutionRecorder?

    init(recorder: ExecutionRecorder? = nil) {
        self.recorder = recorder
    }

    func execute(
        tool: MCPToolDescriptor,
        authorization: MCPInvocationAuthorization,
        arguments: JSONValue
    ) async throws -> MCPToolExecutionResult {
        await recorder?.record(arguments)
        return .init(text: "executed")
    }
}

private actor TestSingleUseApprovalStore: MCPSingleUseApprovalStore {
    private var nonces: Set<UUID> = []

    func consume(nonce: UUID, expiresAt: Date) async throws -> Bool {
        nonces.insert(nonce).inserted
    }

    func consumedCount() -> Int { nonces.count }
}

private struct FailingApprovalStore: MCPSingleUseApprovalStore {
    struct StoreError: Error, Sendable {}

    func consume(nonce: UUID, expiresAt: Date) async throws -> Bool {
        throw StoreError()
    }
}

private let approvalKey = Data((0..<32).map(UInt8.init))
private let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

private func makeCodec() throws -> MCPApprovalTokenCodec {
    try MCPApprovalTokenCodec(keyData: approvalKey)
}

private func makeClaim(
    subject: DID,
    toolName: String = "mail_send",
    arguments: JSONValue,
    nonce: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
    expiresAt: Date = fixedNow.addingTimeInterval(60)
) throws -> MCPApprovalClaim {
    MCPApprovalClaim(
        subject: subject,
        toolName: toolName,
        argumentDigest: try MCPCanonicalArguments.digest(for: arguments),
        nonce: nonce,
        expiresAt: expiresAt
    )
}

private func requestHeaders(bearerToken: String) -> HTTPFields {
    var headers = HTTPFields()
    headers[.contentType] = "application/json"
    headers[.authorization] = "Bearer \(bearerToken)"
    return headers
}

@Test func readinessFailsClosedUntilAuthExecutorsAndApprovalAreConfigured() async throws {
    let foundationApp = Application(router: buildMCPRouter())
    try await foundationApp.test(.router) { client in
        try await client.execute(uri: "/readyz", method: .get) { response in
            #expect(response.status == .serviceUnavailable)
        }
    }

    let did = try DID("did:plc:readiness")
    let verifier = BearerTokenMCPAuthVerifier { _ in
        .init(subject: did, grantedScopes: [])
    }
    let partialApp = Application(router: buildMCPRouter(
        authVerifier: verifier,
        executor: ReadyExecutor()
    ))
    try await partialApp.test(.router) { client in
        try await client.execute(uri: "/readyz", method: .get) { response in
            #expect(response.status == .serviceUnavailable)
        }
    }

    let readyApp = Application(router: buildMCPRouter(
        authVerifier: verifier,
        executor: ReadyExecutor(),
        approvalAuthorizer: SignedMCPApprovalAuthorizer(
            codec: try makeCodec(),
            store: TestSingleUseApprovalStore(),
            now: { fixedNow }
        )
    ))
    try await readyApp.test(.router) { client in
        try await client.execute(uri: "/readyz", method: .get) { response in
            #expect(response.status == .ok)
        }
    }
}

@Test func listsRiskAndScopeMetadataWithoutClaimingStreamableHTTP() async throws {
    #expect(MCPTransportContract.currentContentTypes == ["application/json"])
    #expect(MCPTransportContract.targetContentTypes.contains("text/event-stream"))

    let app = Application(router: buildMCPRouter())
    try await app.test(.router) { client in
        try await client.execute(
            uri: "/mcp",
            method: .post,
            headers: [.contentType: "application/json"],
            body: ByteBuffer(string: #"{"jsonrpc":"2.0","id":1,"method":"tools/list"}"#)
        ) { response in
            #expect(response.status == .ok)
            let value = try JSONDecoder().decode(MCPResponse.self, from: Data(buffer: response.body))
            let send = try #require(value.result?.tools?.first(where: { $0.name == "mail_send" }))
            #expect(send.risk == "sensitiveWrite")
            #expect(send.requiredScopes == ["mail.send"])
        }
    }
}

@Test func sensitiveWriteFailsClosedWithoutApproval() async throws {
    let did = try DID("did:plc:test")
    let verifier = BearerTokenMCPAuthVerifier { token in
        token == "no-approval" ? .init(subject: did, grantedScopes: ["mail.send"]) : nil
    }
    let app = Application(router: buildMCPRouter(
        authVerifier: verifier,
        executor: ReadyExecutor()
    ))
    let body = ByteBuffer(string: #"{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"mail_send","arguments":{"draftID":"draft-1"}}}"#)
    try await app.test(.router) { client in
        try await client.execute(
            uri: "/mcp",
            method: .post,
            headers: requestHeaders(bearerToken: "no-approval"),
            body: body
        ) { response in
            #expect(response.status == .forbidden)
            let value = try JSONDecoder().decode(MCPResponse.self, from: Data(buffer: response.body))
            #expect(value.error?.code == -32002)
            #expect(value.error?.message == "Valid matching unconsumed approval required")
        }
    }
}

@Test func nonSensitiveToolDoesNotRequireApprovalSubsystem() async throws {
    let did = try DID("did:plc:reader")
    let verifier = BearerTokenMCPAuthVerifier { token in
        token == "read-access" ? .init(subject: did, grantedScopes: ["atelier.search"]) : nil
    }
    let app = Application(router: buildMCPRouter(
        authVerifier: verifier,
        executor: ReadyExecutor()
    ))
    let body = ByteBuffer(string: #"{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"atelier_search","arguments":{"query":"notes"}}}"#)
    try await app.test(.router) { client in
        try await client.execute(
            uri: "/mcp",
            method: .post,
            headers: requestHeaders(bearerToken: "read-access"),
            body: body
        ) { response in
            #expect(response.status == .ok)
            let value = try JSONDecoder().decode(MCPResponse.self, from: Data(buffer: response.body))
            #expect(value.result?.content?.first?.text == "executed")
        }
    }
}

@Test func approvalRejectsMismatchedSubject() async throws {
    let approvedSubject = try DID("did:plc:approved")
    let invokingSubject = try DID("did:plc:different")
    let arguments = JSONValue.object(["draftID": .string("draft-1")])
    let codec = try makeCodec()
    let token = try codec.sign(makeClaim(subject: approvedSubject, arguments: arguments))
    let authorizer = SignedMCPApprovalAuthorizer(
        codec: codec,
        store: TestSingleUseApprovalStore(),
        now: { fixedNow }
    )

    await #expect(throws: MCPApprovalAuthorizationError.subjectMismatch) {
        try await authorizer.authorize(
            token: token,
            invocation: MCPApprovalInvocation(
                subject: invokingSubject,
                toolName: "mail_send",
                argumentDigest: try MCPCanonicalArguments.digest(for: arguments)
            )
        )
    }
}

@Test func approvalRejectsMismatchedExactToolName() async throws {
    let subject = try DID("did:plc:approved")
    let arguments = JSONValue.object(["resource": .string("at://did:plc:test/item/1")])
    let codec = try makeCodec()
    let token = try codec.sign(makeClaim(
        subject: subject,
        toolName: "atelier_delete",
        arguments: arguments
    ))
    let authorizer = SignedMCPApprovalAuthorizer(
        codec: codec,
        store: TestSingleUseApprovalStore(),
        now: { fixedNow }
    )

    await #expect(throws: MCPApprovalAuthorizationError.toolMismatch) {
        try await authorizer.authorize(
            token: token,
            invocation: MCPApprovalInvocation(
                subject: subject,
                toolName: "atelier_share",
                argumentDigest: try MCPCanonicalArguments.digest(for: arguments)
            )
        )
    }
}

@Test func approvalRejectsMismatchedCanonicalArguments() async throws {
    let subject = try DID("did:plc:approved")
    let approvedArguments = JSONValue.object([
        "draftID": .string("draft-1"),
        "options": .object(["archive": .bool(false), "priority": .number(1)]),
    ])
    let reorderedArguments = JSONValue.object([
        "options": .object(["priority": .number(1), "archive": .bool(false)]),
        "draftID": .string("draft-1"),
    ])
    let changedArguments = JSONValue.object([
        "draftID": .string("draft-2"),
        "options": .object(["archive": .bool(false), "priority": .number(1)]),
    ])
    #expect(try MCPCanonicalArguments.digest(for: approvedArguments) == MCPCanonicalArguments.digest(for: reorderedArguments))

    let codec = try makeCodec()
    let token = try codec.sign(makeClaim(subject: subject, arguments: approvedArguments))
    let authorizer = SignedMCPApprovalAuthorizer(
        codec: codec,
        store: TestSingleUseApprovalStore(),
        now: { fixedNow }
    )

    await #expect(throws: MCPApprovalAuthorizationError.argumentsMismatch) {
        try await authorizer.authorize(
            token: token,
            invocation: MCPApprovalInvocation(
                subject: subject,
                toolName: "mail_send",
                argumentDigest: try MCPCanonicalArguments.digest(for: changedArguments)
            )
        )
    }
}

@Test func approvalRejectsExpiryAtBoundary() async throws {
    let subject = try DID("did:plc:approved")
    let arguments = JSONValue.object([:])
    let codec = try makeCodec()
    let token = try codec.sign(makeClaim(
        subject: subject,
        arguments: arguments,
        expiresAt: fixedNow
    ))
    let authorizer = SignedMCPApprovalAuthorizer(
        codec: codec,
        store: TestSingleUseApprovalStore(),
        now: { fixedNow }
    )

    await #expect(throws: MCPApprovalAuthorizationError.expired) {
        try await authorizer.authorize(
            token: token,
            invocation: MCPApprovalInvocation(
                subject: subject,
                toolName: "mail_send",
                argumentDigest: try MCPCanonicalArguments.digest(for: arguments)
            )
        )
    }
}

@Test func approvalFailsClosedWhenReplayStoreIsUnavailable() async throws {
    let subject = try DID("did:plc:approved")
    let arguments = JSONValue.object(["draftID": .string("draft-1")])
    let codec = try makeCodec()
    let token = try codec.sign(makeClaim(subject: subject, arguments: arguments))
    let authorizer = SignedMCPApprovalAuthorizer(
        codec: codec,
        store: FailingApprovalStore(),
        now: { fixedNow }
    )

    await #expect(throws: MCPApprovalAuthorizationError.approvalStoreUnavailable) {
        try await authorizer.authorize(
            token: token,
            invocation: MCPApprovalInvocation(
                subject: subject,
                toolName: "mail_send",
                argumentDigest: try MCPCanonicalArguments.digest(for: arguments)
            )
        )
    }
}

@Test func signedApprovalExecutesExactlyOnceAndReplayFails() async throws {
    let subject = try DID("did:plc:approved")
    let arguments = JSONValue.object(["draftID": .string("draft-1")])
    let codec = try makeCodec()
    let claim = try makeClaim(subject: subject, arguments: arguments)
    let approvalToken = try codec.sign(claim)
    #expect(try codec.sign(claim) == approvalToken)

    let store = TestSingleUseApprovalStore()
    let authorizer = SignedMCPApprovalAuthorizer(
        codec: codec,
        store: store,
        now: { fixedNow }
    )
    let verifier = BearerTokenMCPAuthVerifier { token in
        token == "approved-access"
            ? .init(
                subject: subject,
                grantedScopes: ["mail.send"],
                approvalToken: approvalToken
            )
            : nil
    }
    let recorder = ExecutionRecorder()
    let app = Application(router: buildMCPRouter(
        authVerifier: verifier,
        executor: ReadyExecutor(recorder: recorder),
        approvalAuthorizer: authorizer
    ))
    let headers = requestHeaders(bearerToken: "approved-access")
    let requestBody = #"{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"mail_send","arguments":{"draftID":"draft-1"}}}"#

    try await app.test(.router) { client in
        try await client.execute(
            uri: "/mcp",
            method: .post,
            headers: headers,
            body: ByteBuffer(string: requestBody)
        ) { response in
            #expect(response.status == .ok)
            let value = try JSONDecoder().decode(MCPResponse.self, from: Data(buffer: response.body))
            #expect(value.result?.content?.first?.text == "executed")
        }
        try await client.execute(
            uri: "/mcp",
            method: .post,
            headers: headers,
            body: ByteBuffer(string: requestBody)
        ) { response in
            #expect(response.status == .forbidden)
            let value = try JSONDecoder().decode(MCPResponse.self, from: Data(buffer: response.body))
            #expect(value.error?.code == -32002)
        }
    }

    #expect(await store.consumedCount() == 1)
    #expect(await recorder.count() == 1)
}

@Test func modifiedApprovalTokenFailsCryptographicVerification() async throws {
    let subject = try DID("did:plc:approved")
    let arguments = JSONValue.object([:])
    let codec = try makeCodec()
    let token = try codec.sign(makeClaim(subject: subject, arguments: arguments)) + "a"
    let authorizer = SignedMCPApprovalAuthorizer(
        codec: codec,
        store: TestSingleUseApprovalStore(),
        now: { fixedNow }
    )

    await #expect(throws: MCPApprovalAuthorizationError.invalidApproval) {
        try await authorizer.authorize(
            token: token,
            invocation: MCPApprovalInvocation(
                subject: subject,
                toolName: "mail_send",
                argumentDigest: try MCPCanonicalArguments.digest(for: arguments)
            )
        )
    }
}
