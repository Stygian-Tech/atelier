import AtelierCore
import AtelierMail
import AtelierSync
import Foundation

public enum HTTPMethod: String, Codable, Sendable {
    case get = "GET"
    case post = "POST"
}

public struct APIRequest: Sendable {
    public var method: HTTPMethod
    public var path: String
    public var query: [String: String]
    public var body: Data?

    public init(method: HTTPMethod, path: String, query: [String: String] = [:], body: Data? = nil) {
        self.method = method
        self.path = path
        self.query = query
        self.body = body
    }
}

public struct APIResponse: Sendable {
    public var status: Int
    public var body: Data

    public init(status: Int, body: Data) {
        self.status = status
        self.body = body
    }
}

public struct APIErrorResponse: Codable, Equatable, Sendable {
    public var error: String
    public var detail: String?

    public init(error: String, detail: String? = nil) {
        self.error = error
        self.detail = detail
    }
}

public struct RouteDescriptor: Codable, Equatable, Sendable {
    public var method: String
    public var path: String
    public var description: String

    public init(_ method: HTTPMethod, _ path: String, _ description: String) {
        self.method = method.rawValue
        self.path = path
        self.description = description
    }
}

public struct ProviderDescriptor: Codable, Equatable, Sendable {
    public var provider: MailProviderKind
    public var status: String
    public var oauthStartPath: String?
    public var scopes: [String]

    public init(provider: MailProviderKind, status: String, oauthStartPath: String? = nil, scopes: [String] = []) {
        self.provider = provider
        self.status = status
        self.oauthStartPath = oauthStartPath
        self.scopes = scopes
    }
}

public struct GmailOAuthConfig: Codable, Equatable, Sendable {
    public static let defaultScopes = [
        "openid",
        "email",
        "profile",
        "https://www.googleapis.com/auth/gmail.modify",
        "https://www.googleapis.com/auth/gmail.send"
    ]

    public var clientID: String
    public var redirectURI: String
    public var scopes: [String]

    public init(clientID: String, redirectURI: String, scopes: [String] = Self.defaultScopes) {
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.scopes = scopes
    }
}

public struct GmailOAuthStartRequest: Codable, Equatable, Sendable {
    public var ownerDID: DID
    public var loginHint: String?

    public init(ownerDID: DID, loginHint: String? = nil) {
        self.ownerDID = ownerDID
        self.loginHint = loginHint
    }
}

public struct GmailOAuthStartResponse: Codable, Equatable, Sendable {
    public var provider: MailProviderKind
    public var authorizationURL: String
    public var state: String
    public var scopes: [String]
}

public struct GmailOAuthCallbackRequest: Codable, Equatable, Sendable {
    public var ownerDID: DID
    public var code: String
    public var state: String
    public var emailAddress: String
    public var displayName: String

    public init(ownerDID: DID, code: String, state: String, emailAddress: String, displayName: String) {
        self.ownerDID = ownerDID
        self.code = code
        self.state = state
        self.emailAddress = emailAddress
        self.displayName = displayName
    }
}

public struct MailActionRequest: Codable, Equatable, Sendable {
    public enum Action: String, Codable, Sendable {
        case archive
        case trash
        case markRead
        case star
    }

    public var action: Action
    public var isRead: Bool?
    public var isStarred: Bool?

    public init(action: Action, isRead: Bool? = nil, isStarred: Bool? = nil) {
        self.action = action
        self.isRead = isRead
        self.isStarred = isStarred
    }
}

public struct CreateDraftRequest: Codable, Equatable, Sendable {
    public var accountID: AtelierID
    public var threadID: AtelierID?
    public var to: [MailAddress]
    public var subject: String
    public var textBody: String

    public init(accountID: AtelierID, threadID: AtelierID? = nil, to: [MailAddress], subject: String, textBody: String) {
        self.accountID = accountID
        self.threadID = threadID
        self.to = to
        self.subject = subject
        self.textBody = textBody
    }
}

public struct SendDraftRequest: Codable, Equatable, Sendable {
    public var draftID: AtelierID

    public init(draftID: AtelierID) {
        self.draftID = draftID
    }
}

public struct GmailWebhookRequest: Codable, Equatable, Sendable {
    public var accountID: AtelierID
    public var historyID: String

    public init(accountID: AtelierID, historyID: String) {
        self.accountID = accountID
        self.historyID = historyID
    }
}

public struct HealthResponse: Codable, Equatable, Sendable {
    public var ok: Bool
    public var gmail: String

    public init(ok: Bool, gmail: String) {
        self.ok = ok
        self.gmail = gmail
    }
}

public struct SyncResponse: Codable, Equatable, Sendable {
    public var cursor: SyncCursor
    public var mailboxCount: Int
    public var threadCount: Int
    public var messageCount: Int
}

public struct ThreadDetail: Codable, Equatable, Sendable {
    public var thread: MailThread
    public var messages: [MailMessage]
}

public actor InMemoryMailStore {
    private var accounts: [AtelierID: MailAccount] = [:]
    private var mailboxesByAccount: [AtelierID: [Mailbox]] = [:]
    private var threads: [AtelierID: MailThread] = [:]
    private var messagesByThread: [AtelierID: [MailMessage]] = [:]
    private var cursors: [AtelierID: SyncCursor] = [:]
    private var drafts: [AtelierID: MailDraft] = [:]
    private var oauthStates: [String: DID] = [:]

    public init() {}

    public func rememberOAuthState(_ state: String, ownerDID: DID) {
        oauthStates[state] = ownerDID
    }

    public func consumeOAuthState(_ state: String, ownerDID: DID) -> Bool {
        guard oauthStates[state] == ownerDID else { return false }
        oauthStates[state] = nil
        return true
    }

    public func upsertAccount(_ account: MailAccount) {
        accounts[account.id] = account
    }

    public func account(_ id: AtelierID) -> MailAccount? {
        accounts[id]
    }

    public func accounts(ownerDID: DID?) -> [MailAccount] {
        accounts.values
            .filter { ownerDID == nil || $0.ownerDID == ownerDID }
            .sorted { $0.displayName < $1.displayName }
    }

    public func apply(snapshot: MailSyncSnapshot) {
        mailboxesByAccount[snapshot.cursor.accountID] = snapshot.mailboxes
        cursors[snapshot.cursor.accountID] = snapshot.cursor

        for thread in snapshot.threads {
            threads[thread.id] = thread
        }
        for message in snapshot.messages {
            messagesByThread[message.threadID, default: []].append(message)
        }
    }

    public func cursor(accountID: AtelierID) -> SyncCursor? {
        cursors[accountID]
    }

    public func mailboxes(accountID: AtelierID?) -> [Mailbox] {
        if let accountID {
            return mailboxesByAccount[accountID] ?? []
        }
        return mailboxesByAccount.values.flatMap { $0 }
    }

    public func searchThreads(accountID: AtelierID?, query: String?) -> [MailThread] {
        let normalizedQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return threads.values
            .filter { accountID == nil || $0.accountID == accountID }
            .filter { thread in
                guard let normalizedQuery, !normalizedQuery.isEmpty else { return true }
                return "\(thread.subject) \(thread.participantsSummary) \(thread.snippet)".lowercased().contains(normalizedQuery)
            }
            .sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

    public func threadDetail(threadID: AtelierID) -> ThreadDetail? {
        guard let thread = threads[threadID] else { return nil }
        return ThreadDetail(thread: thread, messages: messagesByThread[threadID] ?? [])
    }

    public func updateThread(_ threadID: AtelierID, _ update: (inout MailThread) -> Void) -> MailThread? {
        guard var thread = threads[threadID] else { return nil }
        update(&thread)
        threads[threadID] = thread
        return thread
    }

    public func saveDraft(_ draft: MailDraft) {
        drafts[draft.id] = draft
    }

    public func draft(_ id: AtelierID) -> MailDraft? {
        drafts[id]
    }
}

public struct MailProviderRegistry: Sendable {
    private let adapters: [MailProviderKind: any SnapshotMailProviderAdapter]

    public init(adapters: [any SnapshotMailProviderAdapter] = [GmailProviderAdapter()]) {
        self.adapters = Dictionary(uniqueKeysWithValues: adapters.map { ($0.kind, $0) })
    }

    public func adapter(for provider: MailProviderKind) throws -> any SnapshotMailProviderAdapter {
        guard let adapter = adapters[provider] else {
            throw MailProviderError.unsupportedProvider(provider)
        }
        return adapter
    }
}

public final class MailAPIRouter: Sendable {
    public let routes: [RouteDescriptor] = [
        RouteDescriptor(.get, "/health", "Service health and Gmail wiring status."),
        RouteDescriptor(.get, "/v0/providers", "List provider adapters and connection entry points."),
        RouteDescriptor(.post, "/v0/providers/gmail/oauth/start", "Create a Gmail OAuth authorization URL."),
        RouteDescriptor(.post, "/v0/providers/gmail/oauth/callback", "Exchange Gmail OAuth callback data for a connected account record."),
        RouteDescriptor(.get, "/v0/mail/accounts", "List connected mail accounts."),
        RouteDescriptor(.post, "/v0/mail/accounts/{accountID}/sync", "Run initial or incremental provider sync."),
        RouteDescriptor(.get, "/v0/mail/mailboxes", "List normalized mailboxes."),
        RouteDescriptor(.get, "/v0/mail/threads", "Search normalized mail threads."),
        RouteDescriptor(.get, "/v0/mail/threads/{threadID}", "Read a normalized mail thread and messages."),
        RouteDescriptor(.post, "/v0/mail/threads/{threadID}/actions", "Apply archive/trash/read/star actions through the provider adapter."),
        RouteDescriptor(.post, "/v0/mail/drafts", "Create a local draft envelope."),
        RouteDescriptor(.post, "/v0/mail/send", "Send a draft through the account provider adapter."),
        RouteDescriptor(.post, "/v0/gmail/webhook", "Accept Gmail history notifications and enqueue incremental sync.")
    ]

    private let store: InMemoryMailStore
    private let providers: MailProviderRegistry
    private let gmailOAuth: GmailOAuthConfig
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        store: InMemoryMailStore = InMemoryMailStore(),
        providers: MailProviderRegistry = MailProviderRegistry(),
        gmailOAuth: GmailOAuthConfig = GmailOAuthConfig(clientID: "local-dev-client", redirectURI: "http://localhost:8080/v0/providers/gmail/oauth/callback")
    ) {
        self.store = store
        self.providers = providers
        self.gmailOAuth = gmailOAuth
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        self.encoder.outputFormatting = [.sortedKeys]
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func handle(_ request: APIRequest) async -> APIResponse {
        do {
            switch (request.method, request.path) {
            case (.get, "/health"):
                return try json(HealthResponse(ok: true, gmail: "wired"))
            case (.get, "/v0/providers"):
                return try json(providerDescriptors())
            case (.post, "/v0/providers/gmail/oauth/start"):
                return try await startGmailOAuth(request)
            case (.post, "/v0/providers/gmail/oauth/callback"):
                return try await completeGmailOAuth(request)
            case (.get, "/v0/mail/accounts"):
                let ownerDID = request.query["ownerDID"].map { DID(rawValue: $0) }
                return try await json(store.accounts(ownerDID: ownerDID))
            case (.get, "/v0/mail/mailboxes"):
                let accountID = request.query["accountID"].map { AtelierID($0) }
                return try await json(store.mailboxes(accountID: accountID))
            case (.get, "/v0/mail/threads"):
                let accountID = request.query["accountID"].map { AtelierID($0) }
                return try await json(store.searchThreads(accountID: accountID, query: request.query["q"]))
            case (.post, "/v0/mail/drafts"):
                return try await createDraft(request)
            case (.post, "/v0/mail/send"):
                return try await sendDraft(request)
            case (.post, "/v0/gmail/webhook"):
                return try await handleGmailWebhook(request)
            default:
                return try await handleParameterized(request)
            }
        } catch {
            return errorResponse(status: 400, error: "bad_request", detail: String(describing: error))
        }
    }

    private func providerDescriptors() -> [ProviderDescriptor] {
        [
            ProviderDescriptor(provider: .gmail, status: "wired", oauthStartPath: "/v0/providers/gmail/oauth/start", scopes: gmailOAuth.scopes),
            ProviderDescriptor(provider: .jmap, status: "planned"),
            ProviderDescriptor(provider: .imap, status: "planned")
        ]
    }

    private func startGmailOAuth(_ request: APIRequest) async throws -> APIResponse {
        let payload: GmailOAuthStartRequest = try decode(request)
        let state = "gmail-\(UUID().uuidString.lowercased())"
        await store.rememberOAuthState(state, ownerDID: payload.ownerDID)

        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: gmailOAuth.clientID),
            URLQueryItem(name: "redirect_uri", value: gmailOAuth.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "scope", value: gmailOAuth.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "login_hint", value: payload.loginHint)
        ].compactMap { $0.value == nil ? nil : $0 }

        return try json(GmailOAuthStartResponse(
            provider: .gmail,
            authorizationURL: components.url!.absoluteString,
            state: state,
            scopes: gmailOAuth.scopes
        ))
    }

    private func completeGmailOAuth(_ request: APIRequest) async throws -> APIResponse {
        let payload: GmailOAuthCallbackRequest = try decode(request)
        guard await store.consumeOAuthState(payload.state, ownerDID: payload.ownerDID) else {
            return errorResponse(status: 401, error: "invalid_oauth_state", detail: "Gmail OAuth state did not match the requesting DID.")
        }

        let account = MailAccount(
            ownerDID: payload.ownerDID,
            provider: .gmail,
            displayName: payload.displayName,
            emailAddress: payload.emailAddress,
            providerDescriptorKey: "gmail-\(payload.emailAddress.lowercased())"
        )
        await store.upsertAccount(account)
        return try json(account, status: 201)
    }

    private func handleParameterized(_ request: APIRequest) async throws -> APIResponse {
        let segments = request.path.split(separator: "/").map(String.init)

        if request.method == .post, segments.count == 5, Array(segments[0...2]) == ["v0", "mail", "accounts"], segments[4] == "sync" {
            return try await syncAccount(AtelierID(segments[3]))
        }

        if request.method == .get, segments.count == 4, Array(segments[0...2]) == ["v0", "mail", "threads"] {
            guard let detail = await store.threadDetail(threadID: AtelierID(segments[3])) else {
                return errorResponse(status: 404, error: "thread_not_found")
            }
            return try json(detail)
        }

        if request.method == .post, segments.count == 5, Array(segments[0...2]) == ["v0", "mail", "threads"], segments[4] == "actions" {
            return try await applyThreadAction(threadID: AtelierID(segments[3]), request: request)
        }

        return errorResponse(status: 404, error: "not_found")
    }

    private func syncAccount(_ accountID: AtelierID) async throws -> APIResponse {
        guard let account = await store.account(accountID) else {
            return errorResponse(status: 404, error: "account_not_found")
        }
        let adapter = try providers.adapter(for: account.provider)
        let snapshot: MailSyncSnapshot
        if let cursor = await store.cursor(accountID: accountID) {
            snapshot = try await adapter.incrementalSnapshot(account: account, cursor: cursor)
        } else {
            snapshot = try await adapter.initialSnapshot(account: account)
        }
        await store.apply(snapshot: snapshot)
        return try json(SyncResponse(
            cursor: snapshot.cursor,
            mailboxCount: snapshot.mailboxes.count,
            threadCount: snapshot.threads.count,
            messageCount: snapshot.messages.count
        ))
    }

    private func applyThreadAction(threadID: AtelierID, request: APIRequest) async throws -> APIResponse {
        guard let detail = await store.threadDetail(threadID: threadID) else {
            return errorResponse(status: 404, error: "thread_not_found")
        }
        guard let account = await store.account(detail.thread.accountID) else {
            return errorResponse(status: 404, error: "account_not_found")
        }

        let payload: MailActionRequest = try decode(request)
        let action: MailAction
        switch payload.action {
        case .archive:
            action = .archive(threadID: threadID)
        case .trash:
            action = .trash(threadID: threadID)
        case .markRead:
            action = .markRead(threadID: threadID, isRead: payload.isRead ?? true)
        case .star:
            action = .star(threadID: threadID, isStarred: payload.isStarred ?? true)
        }

        let adapter = try providers.adapter(for: account.provider)
        try await adapter.apply(action: action, account: account)

        let updated = await store.updateThread(threadID) { thread in
            switch action {
            case .archive, .trash:
                thread.unreadCount = 0
            case .markRead(_, let isRead):
                thread.unreadCount = isRead ? 0 : max(thread.unreadCount, 1)
            case .star(_, let isStarred):
                thread.isStarred = isStarred
            }
        }

        return try json(updated)
    }

    private func createDraft(_ request: APIRequest) async throws -> APIResponse {
        let payload: CreateDraftRequest = try decode(request)
        guard await store.account(payload.accountID) != nil else {
            return errorResponse(status: 404, error: "account_not_found")
        }
        let draft = MailDraft(
            accountID: payload.accountID,
            threadID: payload.threadID,
            to: payload.to,
            subject: payload.subject,
            textBody: payload.textBody
        )
        await store.saveDraft(draft)
        return try json(draft, status: 201)
    }

    private func sendDraft(_ request: APIRequest) async throws -> APIResponse {
        let payload: SendDraftRequest = try decode(request)
        guard let draft = await store.draft(payload.draftID) else {
            return errorResponse(status: 404, error: "draft_not_found")
        }
        guard let account = await store.account(draft.accountID) else {
            return errorResponse(status: 404, error: "account_not_found")
        }

        let adapter = try providers.adapter(for: account.provider)
        let receipt = try await adapter.send(account: account, draft: draft)
        return try json(receipt)
    }

    private func handleGmailWebhook(_ request: APIRequest) async throws -> APIResponse {
        let payload: GmailWebhookRequest = try decode(request)
        guard let account = await store.account(payload.accountID), account.provider == .gmail else {
            return errorResponse(status: 404, error: "gmail_account_not_found")
        }
        return try await syncAccount(payload.accountID)
    }

    private func decode<T: Decodable>(_ request: APIRequest) throws -> T {
        try decoder.decode(T.self, from: request.body ?? Data())
    }

    private func json<T: Encodable>(_ value: T, status: Int = 200) throws -> APIResponse {
        APIResponse(status: status, body: try encoder.encode(value))
    }

    private func errorResponse(status: Int, error: String, detail: String? = nil) -> APIResponse {
        APIResponse(status: status, body: try! encoder.encode(APIErrorResponse(error: error, detail: detail)))
    }
}
