import AtelierAPIKit
import Foundation
import Hummingbird
import HummingbirdTesting
import HTTPTypes
import Testing

private struct ReadyStorage: APIStorageDependency {
    let isReady = true
}

private struct ReadyAuth: APIAuthDependency {
    let isReady = true
}

@Test func foundationHealthIsLiveButReadinessFailsClosed() async throws {
    let app = Application(router: buildRouter())
    try await app.test(.router) { client in
        try await client.execute(uri: "/healthz", method: .get) { response in
            #expect(response.status == .ok)
            let body = try JSONDecoder().decode(ServiceStatus.self, from: Data(buffer: response.body))
            #expect(body.status == "ok")
            #expect(body.mode == "foundation")
        }
        try await client.execute(uri: "/readyz", method: .get) { response in
            #expect(response.status == .serviceUnavailable)
            let body = try JSONDecoder().decode(ServiceStatus.self, from: Data(buffer: response.body))
            #expect(body.status == "not-ready")
        }
    }
}

@Test func readinessCanOnlyBeEnabledExplicitly() async throws {
    let app = Application(router: buildRouter(dependencies: .init(storage: ReadyStorage(), auth: ReadyAuth())))
    try await app.test(.router) { client in
        try await client.execute(uri: "/readyz", method: .get) { response in
            #expect(response.status == .ok)
            let body = try JSONDecoder().decode(ServiceStatus.self, from: Data(buffer: response.body))
            #expect(body.status == "ready")
        }
    }
}

@Test func aPartialDependencyGraphNeverReportsReady() async throws {
    let app = Application(router: buildRouter(dependencies: .init(storage: ReadyStorage())))
    try await app.test(.router) { client in
        try await client.execute(uri: "/readyz", method: .get) { response in
            #expect(response.status == .serviceUnavailable)
        }
    }
}

@Test func xrpcCapabilityRouteDoesNotClaimProviderConfiguration() async throws {
    let app = Application(router: buildRouter())
    try await app.test(.router) { client in
        try await client.execute(uri: AtelierXRPCMethod.getCapabilities.path, method: .get) { response in
            #expect(response.status == .ok)
            let output = try JSONDecoder().decode(CapabilitiesOutput.self, from: Data(buffer: response.body))
            #expect(output.providers.count == 6)
            #expect(output.providers.allSatisfy { $0.availability == "contractOnly" })
            #expect(output.publicPdsDisclosure.contains("publicly readable"))
        }
    }
}
