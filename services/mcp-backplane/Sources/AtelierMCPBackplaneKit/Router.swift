import AtelierContracts
import AtelierMCP
import Foundation
import Hummingbird
import HTTPTypes

public struct JSONRPCRequest: Codable, Equatable, Sendable {
    public struct Parameters: Codable, Equatable, Sendable {
        public let name: String?
        public let arguments: JSONValue?

        public init(name: String? = nil, arguments: JSONValue? = nil) {
            self.name = name
            self.arguments = arguments
        }
    }

    public let jsonrpc: String
    public let id: Int?
    public let method: String
    public let params: Parameters?

    public init(jsonrpc: String = "2.0", id: Int? = nil, method: String, params: Parameters? = nil) {
        self.jsonrpc = jsonrpc
        self.id = id
        self.method = method
        self.params = params
    }
}

public struct MCPResponse: Codable, Equatable, Sendable {
    public struct Result: Codable, Equatable, Sendable {
        public struct ServerInfo: Codable, Equatable, Sendable {
            public let name: String
            public let version: String
        }
        public struct Tool: Codable, Equatable, Sendable {
            public struct InputSchema: Codable, Equatable, Sendable {
                public let type: String
            }
            public let name: String
            public let description: String
            public let inputSchema: InputSchema
            public let risk: String
            public let requiredScopes: [String]
        }
        public struct Content: Codable, Equatable, Sendable {
            public let type: String
            public let text: String
        }

        public let protocolVersion: String?
        public let serverInfo: ServerInfo?
        public let tools: [Tool]?
        public let content: [Content]?
        public let isError: Bool?

        public init(
            protocolVersion: String? = nil,
            serverInfo: ServerInfo? = nil,
            tools: [Tool]? = nil,
            content: [Content]? = nil,
            isError: Bool? = nil
        ) {
            self.protocolVersion = protocolVersion
            self.serverInfo = serverInfo
            self.tools = tools
            self.content = content
            self.isError = isError
        }
    }

    public struct RPCError: Codable, Equatable, Sendable {
        public let code: Int
        public let message: String
    }

    public let jsonrpc: String
    public let id: Int?
    public let result: Result?
    public let error: RPCError?

    public init(id: Int?, result: Result) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = result
        self.error = nil
    }

    public init(id: Int?, error: RPCError) {
        self.jsonrpc = "2.0"
        self.id = id
        self.result = nil
        self.error = error
    }
}

public protocol MCPAuthVerifier: Sendable {
    var isConfigured: Bool { get }
    func verify(bearerToken: String) -> MCPInvocationAuthorization?
}

public struct RejectingMCPAuthVerifier: MCPAuthVerifier {
    public init() {}
    public let isConfigured = false
    public func verify(bearerToken: String) -> MCPInvocationAuthorization? { nil }
}

public struct BearerTokenMCPAuthVerifier: MCPAuthVerifier {
    private let resolver: @Sendable (String) -> MCPInvocationAuthorization?
    public let isConfigured = true

    public init(resolver: @escaping @Sendable (String) -> MCPInvocationAuthorization?) {
        self.resolver = resolver
    }

    public func verify(bearerToken: String) -> MCPInvocationAuthorization? {
        resolver(bearerToken)
    }
}

public struct MCPToolExecutionResult: Equatable, Sendable {
    public let text: String
    public let isError: Bool

    public init(text: String, isError: Bool = false) {
        self.text = text
        self.isError = isError
    }
}

public protocol MCPToolExecutor: Sendable {
    var isConfigured: Bool { get }
    func execute(
        tool: MCPToolDescriptor,
        authorization: MCPInvocationAuthorization,
        arguments: JSONValue
    ) async throws -> MCPToolExecutionResult
}

public struct UnavailableMCPToolExecutor: MCPToolExecutor {
    public init() {}
    public let isConfigured = false

    public func execute(
        tool: MCPToolDescriptor,
        authorization: MCPInvocationAuthorization,
        arguments: JSONValue
    ) async throws -> MCPToolExecutionResult {
        .init(
            text: "Tool contract is authorized, but its domain executor is not configured in the bootstrap foundation.",
            isError: true
        )
    }
}

public func buildMCPRouter(
    authVerifier: any MCPAuthVerifier = RejectingMCPAuthVerifier(),
    executor: any MCPToolExecutor = UnavailableMCPToolExecutor(),
    approvalAuthorizer: any MCPApprovalAuthorizing = RejectingMCPApprovalAuthorizer()
) -> Router<BasicRequestContext> {
    let router = Router(context: BasicRequestContext.self)
    router.get("healthz") { _, _ in
        try jsonResponse(["service": "atelier-mcp-backplane", "status": "ok"])
    }
    router.get("readyz") { _, _ in
        let isReady = authVerifier.isConfigured
            && executor.isConfigured
            && approvalAuthorizer.isConfigured
        return try jsonResponse(
            ["service": "atelier-mcp-backplane", "status": isReady ? "ready" : "not-ready"],
            status: isReady ? .ok : .serviceUnavailable
        )
    }
    router.post("mcp") { request, _ in
        let body: JSONRPCRequest
        do {
            body = try await decodeBody(request)
        } catch {
            return try jsonResponse(
                MCPResponse(id: nil, error: .init(code: -32700, message: "Parse error")),
                status: .badRequest
            )
        }

        switch body.method {
        case "initialize":
            return try jsonResponse(MCPResponse(
                id: body.id,
                result: .init(
                    protocolVersion: MCPTransportContract.protocolVersion,
                    serverInfo: .init(name: "Atelier", version: "0.0.0")
                )
            ))
        case "tools/list":
            let tools = AtelierMCPTools.all.map {
                MCPResponse.Result.Tool(
                    name: $0.name,
                    description: $0.description,
                    inputSchema: .init(type: "object"),
                    risk: $0.risk.rawValue,
                    requiredScopes: $0.requiredScopes.sorted()
                )
            }
            return try jsonResponse(MCPResponse(id: body.id, result: .init(tools: tools)))
        case "tools/call":
            return try await authorizeToolCall(
                body,
                request: request,
                authVerifier: authVerifier,
                executor: executor,
                approvalAuthorizer: approvalAuthorizer
            )
        default:
            return try jsonResponse(MCPResponse(
                id: body.id,
                error: .init(code: -32601, message: "Method not found")
            ))
        }
    }
    return router
}

private func authorizeToolCall(
    _ rpc: JSONRPCRequest,
    request: Request,
    authVerifier: any MCPAuthVerifier,
    executor: any MCPToolExecutor,
    approvalAuthorizer: any MCPApprovalAuthorizing
) async throws -> Response {
    guard let toolName = rpc.params?.name,
          let tool = AtelierMCPTools.all.first(where: { $0.name == toolName }) else {
        return try jsonResponse(MCPResponse(id: rpc.id, error: .init(code: -32602, message: "Unknown or missing tool")))
    }
    let arguments = rpc.params?.arguments ?? .object([:])
    guard case .object = arguments else {
        return try jsonResponse(MCPResponse(
            id: rpc.id,
            error: .init(code: -32602, message: "Tool arguments must be an object")
        ))
    }
    guard let authorization = request.headers[.authorization],
          authorization.hasPrefix("Bearer "),
          let invocation = authVerifier.verify(bearerToken: String(authorization.dropFirst("Bearer ".count))) else {
        return try jsonResponse(
            MCPResponse(id: rpc.id, error: .init(code: -32000, message: "Valid bearer authorization required")),
            status: .unauthorized
        )
    }
    do {
        try MCPAuthorizationPolicy().authorizeScopes(tool, invocation: invocation)
    } catch MCPAuthorizationError.missingScopes(let missing) {
        return try jsonResponse(
            MCPResponse(id: rpc.id, error: .init(code: -32001, message: "Missing scopes: \(missing.sorted().joined(separator: " "))")),
            status: .forbidden
        )
    }

    if tool.risk == .sensitiveWrite {
        let argumentDigest = try MCPCanonicalArguments.digest(for: arguments)
        do {
            try await approvalAuthorizer.authorize(
                token: invocation.approvalToken,
                invocation: MCPApprovalInvocation(
                    subject: invocation.subject,
                    toolName: tool.name,
                    argumentDigest: argumentDigest
                )
            )
        } catch {
            return try jsonResponse(
                MCPResponse(
                    id: rpc.id,
                    error: .init(
                        code: -32002,
                        message: "Valid matching unconsumed approval required"
                    )
                ),
                status: .forbidden
            )
        }
    }

    let execution = try await executor.execute(
        tool: tool,
        authorization: invocation,
        arguments: arguments
    )
    return try jsonResponse(MCPResponse(
        id: rpc.id,
        result: .init(
            content: [.init(type: "text", text: execution.text)],
            isError: execution.isError
        )
    ))
}

private func decodeBody(_ request: Request) async throws -> JSONRPCRequest {
    let buffer = try await request.body.collect(upTo: 1_048_576)
    return try JSONDecoder().decode(JSONRPCRequest.self, from: Data(buffer: buffer))
}

private func jsonResponse<T: Encodable>(_ value: T, status: HTTPResponse.Status = .ok) throws -> Response {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(value)
    var buffer = ByteBuffer()
    buffer.writeBytes(data)
    var headers = HTTPFields()
    headers[.contentType] = "application/json; charset=utf-8"
    return Response(status: status, headers: headers, body: .init(byteBuffer: buffer))
}
