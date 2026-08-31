import AtelierMCPBackplaneKit
import Foundation
import Hummingbird

@main
struct AtelierMCPBackplane {
    static func main() async throws {
        let port = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8080") ?? 8080
        let app = Application(
            router: buildMCPRouter(),
            configuration: .init(address: .hostname("0.0.0.0", port: port))
        )
        try await app.runService()
    }
}
