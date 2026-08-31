import AtelierContracts
import AtelierProviders
import Foundation
import Hummingbird
import HTTPTypes

public struct ServiceStatus: Codable, Equatable, Sendable {
    public let status: String
    public let service: String
    public let mode: String

    public init(status: String, service: String = "atelier-api", mode: String = "foundation") {
        self.status = status
        self.service = service
        self.mode = mode
    }
}

public protocol APIStorageDependency: Sendable {
    var isReady: Bool { get }
}

public protocol APIAuthDependency: Sendable {
    var isReady: Bool { get }
}

public struct APIDependencies: Sendable {
    public let storage: (any APIStorageDependency)?
    public let auth: (any APIAuthDependency)?

    public init(
        storage: (any APIStorageDependency)? = nil,
        auth: (any APIAuthDependency)? = nil
    ) {
        self.storage = storage
        self.auth = auth
    }

    public var isReady: Bool {
        storage?.isReady == true && auth?.isReady == true
    }
}

public struct ProviderStatus: Codable, Equatable, Sendable {
    public let name: String
    public let availability: String

    public init(name: String, availability: String) {
        self.name = name
        self.availability = availability
    }
}

public struct CapabilitiesOutput: Codable, Equatable, Sendable {
    public let service: String
    public let mode: String
    public let publicPdsDisclosure: String
    public let providers: [ProviderStatus]

    public init(
        service: String = "atelier-api",
        mode: String = "foundation",
        publicPdsDisclosure: String = DataBoundary.publicPDSDisclosure,
        providers: [ProviderStatus] = [
            .init(name: "gmail", availability: "contractOnly"),
            .init(name: "jmap", availability: "contractOnly"),
            .init(name: "imap", availability: "contractOnly"),
            .init(name: "googleCalendar", availability: "contractOnly"),
            .init(name: "microsoftCalendar", availability: "contractOnly"),
            .init(name: "caldav", availability: "contractOnly"),
        ]
    ) {
        self.service = service
        self.mode = mode
        self.publicPdsDisclosure = publicPdsDisclosure
        self.providers = providers
    }
}

public enum AtelierXRPCMethod: String, CaseIterable, Sendable {
    case getCapabilities = "diy.atelier.actor.getCapabilities"

    public var path: String { "/xrpc/\(rawValue)" }
}

public func buildRouter(dependencies: APIDependencies = .init()) -> Router<BasicRequestContext> {
    let router = Router(context: BasicRequestContext.self)

    router.get("healthz") { _, _ in
        try jsonResponse(ServiceStatus(status: "ok"))
    }
    router.get("readyz") { _, _ in
        try jsonResponse(
            ServiceStatus(status: dependencies.isReady ? "ready" : "not-ready"),
            status: dependencies.isReady ? .ok : .serviceUnavailable
        )
    }
    router.get("xrpc/diy.atelier.actor.getCapabilities") { _, _ in
        try jsonResponse(CapabilitiesOutput())
    }

    return router
}

private func jsonResponse<T: Encodable>(
    _ value: T,
    status: HTTPResponse.Status = .ok
) throws -> Response {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(value)
    var buffer = ByteBuffer()
    buffer.writeBytes(data)
    var headers = HTTPFields()
    headers[.contentType] = "application/json; charset=utf-8"
    return Response(status: status, headers: headers, body: .init(byteBuffer: buffer))
}
