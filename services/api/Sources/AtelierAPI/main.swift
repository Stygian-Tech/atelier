import AtelierAPIKit
import Foundation
import Hummingbird

@main
struct AtelierAPI {
    static func main() async throws {
        let port = Int(ProcessInfo.processInfo.environment["PORT"] ?? "8080") ?? 8080
        let application = Application(
            router: buildRouter(),
            configuration: .init(address: .hostname("0.0.0.0", port: port))
        )
        try await application.runService()
    }
}
