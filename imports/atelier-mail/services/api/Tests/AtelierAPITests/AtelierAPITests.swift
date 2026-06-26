import AtelierCore
import AtelierAPI
import AtelierMCP
import AtelierMail
import AtelierPlatform
import Foundation
import Testing

@Test func namespaceUsesAtelierWorkSpace() {
    #expect(AtelierNamespace.root == "space.atelierwork")
    #expect(AtelierNamespace.mail == "space.atelierwork.mail")
}

@Test func permissionedRecordsDefaultToAtelierKV() throws {
    let did = try DID("did:plc:atelierdemo")
    let key = try PermissionedRecordKey(
        ownerDID: did,
        namespace: "space.atelierwork.mail.providerDescriptor",
        key: "gmail-primary"
    )
    let envelope = PermissionedRecordEnvelope(
        key: key,
        schemaVersion: 1,
        encryptedPayload: Data("{}".utf8),
        encryptionKeyRef: "local-dev"
    )

    #expect(envelope.storageTarget == PermissionedStorageTarget.atelierKV)
}

@Test func mailMCPToolsStartReadOnly() {
    let toolNames = Set(MailMCPTools.readOnly.map(\.name))

    #expect(toolNames.contains("mail_search_threads"))
    #expect(toolNames.contains("mail_read_thread"))
    #expect(MailMCPTools.readOnly.allSatisfy { $0.risk == .read })
}

@Test func mailThreadURIsUseAtelierScheme() {
    let uri = MailThreadURI.make(AtelierID("thread_01"))

    #expect(uri.rawValue == "atelier://mail/thread/thread_01")
}

@Test func apiAdvertisesGmailProviderAndRoutes() async throws {
    let router = MailAPIRouter()
    let response = await router.handle(APIRequest(method: .get, path: "/v0/providers"))
    let providers = try decode([ProviderDescriptor].self, from: response)

    #expect(response.status == 200)
    #expect(providers.first(where: { $0.provider == .gmail })?.status == "wired")
    #expect(providers.first(where: { $0.provider == .gmail })?.oauthStartPath == "/v0/providers/gmail/oauth/start")
    #expect(router.routes.contains { $0.path == "/v0/mail/accounts/{accountID}/sync" })
}

@Test func gmailOAuthConnectsAccountAndInitialSyncWritesNormalizedMail() async throws {
    let router = MailAPIRouter()
    let ownerDID = try DID("did:plc:gmaildemo")
    let start = await router.handle(try jsonRequest(
        .post,
        "/v0/providers/gmail/oauth/start",
        GmailOAuthStartRequest(ownerDID: ownerDID, loginHint: "sam@atelierwork.space")
    ))
    let startPayload = try decode(GmailOAuthStartResponse.self, from: start)

    #expect(startPayload.authorizationURL.contains("accounts.google.com"))
    #expect(startPayload.scopes.contains("https://www.googleapis.com/auth/gmail.modify"))

    let callback = await router.handle(try jsonRequest(
        .post,
        "/v0/providers/gmail/oauth/callback",
        GmailOAuthCallbackRequest(
            ownerDID: ownerDID,
            code: "oauth-code",
            state: startPayload.state,
            emailAddress: "sam@atelierwork.space",
            displayName: "Sam"
        )
    ))
    let account = try decode(MailAccount.self, from: callback)

    #expect(callback.status == 201)
    #expect(account.provider == .gmail)
    #expect(account.emailAddress == "sam@atelierwork.space")

    let sync = await router.handle(APIRequest(method: .post, path: "/v0/mail/accounts/\(account.id.rawValue)/sync"))
    let syncPayload = try decode(SyncResponse.self, from: sync)

    #expect(sync.status == 200)
    #expect(syncPayload.mailboxCount == 2)
    #expect(syncPayload.threadCount == 1)
    #expect(syncPayload.messageCount == 1)
    #expect(syncPayload.cursor.providerCursor == "gmail-history-1001")

    let threadsResponse = await router.handle(APIRequest(method: .get, path: "/v0/mail/threads", query: ["accountID": account.id.rawValue, "q": "gmail api"]))
    let threads = try decode([MailThread].self, from: threadsResponse)

    #expect(threads.count == 1)
    #expect(threads[0].providerThreadID == "gmail-thread-atelier-001")
}

@Test func gmailThreadActionsAndDraftSendUseProviderBoundary() async throws {
    let router = MailAPIRouter()
    let account = try await connectedSyncedGmailAccount(router: router)
    let threads = try decode([MailThread].self, from: await router.handle(APIRequest(method: .get, path: "/v0/mail/threads")))
    let thread = try #require(threads.first)

    let starResponse = await router.handle(try jsonRequest(.post, "/v0/mail/threads/\(thread.id.rawValue)/actions", MailActionRequest(action: .star, isStarred: true)))
    let starred = try decode(MailThread?.self, from: starResponse)

    #expect(starResponse.status == 200)
    #expect(starred?.isStarred == true)

    let draftResponse = await router.handle(try jsonRequest(
        .post,
        "/v0/mail/drafts",
        CreateDraftRequest(
            accountID: account.id,
            threadID: thread.id,
            to: [MailAddress(name: "Mira", address: "mira@example.com")],
            subject: "Re: \(thread.subject)",
            textBody: "Thanks, this Gmail route is wired."
        )
    ))
    let draft = try decode(MailDraft.self, from: draftResponse)

    #expect(draftResponse.status == 201)
    #expect(draft.accountID == account.id)

    let sendResponse = await router.handle(try jsonRequest(.post, "/v0/mail/send", SendDraftRequest(draftID: draft.id)))
    let receipt = try decode(MailSendReceipt.self, from: sendResponse)

    #expect(sendResponse.status == 200)
    #expect(receipt.providerMessageID.hasPrefix("gmail-sent-"))
}

@Test func gmailWebhookTriggersIncrementalSync() async throws {
    let router = MailAPIRouter()
    let account = try await connectedSyncedGmailAccount(router: router)

    let webhook = await router.handle(try jsonRequest(
        .post,
        "/v0/gmail/webhook",
        GmailWebhookRequest(accountID: account.id, historyID: "1001")
    ))
    let sync = try decode(SyncResponse.self, from: webhook)

    #expect(webhook.status == 200)
    #expect(sync.cursor.providerCursor == "gmail-history-1002")
}

private func connectedSyncedGmailAccount(router: MailAPIRouter) async throws -> MailAccount {
    let ownerDID = try DID("did:plc:gmaildemo")
    let startPayload = try decode(
        GmailOAuthStartResponse.self,
        from: await router.handle(try jsonRequest(.post, "/v0/providers/gmail/oauth/start", GmailOAuthStartRequest(ownerDID: ownerDID)))
    )
    let account = try decode(
        MailAccount.self,
        from: await router.handle(try jsonRequest(
            .post,
            "/v0/providers/gmail/oauth/callback",
            GmailOAuthCallbackRequest(
                ownerDID: ownerDID,
                code: "oauth-code",
                state: startPayload.state,
                emailAddress: "sam@atelierwork.space",
                displayName: "Sam"
            )
        ))
    )
    _ = await router.handle(APIRequest(method: .post, path: "/v0/mail/accounts/\(account.id.rawValue)/sync"))
    return account
}

private func jsonRequest<T: Encodable>(_ method: HTTPMethod, _ path: String, _ payload: T) throws -> APIRequest {
    APIRequest(method: method, path: path, body: try testEncoder.encode(payload))
}

private func decode<T: Decodable>(_ type: T.Type, from response: APIResponse) throws -> T {
    try testDecoder.decode(T.self, from: response.body)
}

private let testEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}()

private let testDecoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()
