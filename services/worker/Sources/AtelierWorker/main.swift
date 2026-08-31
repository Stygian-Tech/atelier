import AtelierWorkerKit
import Foundation

public enum AtelierWorkerStartupError: Error, Sendable, CustomStringConvertible {
    case notReady([String])

    public var description: String {
        switch self {
        case .notReady(let blockers):
            "atelier-worker is not ready: \(blockers.joined(separator: "; "))"
        }
    }
}

@main
struct AtelierWorker {
    static func main() async throws {
        _ = try WorkerRuntimeConfiguration(environment: ProcessInfo.processInfo.environment)
        let readiness = DurableJobStoreBootstrap.readiness
        guard readiness.isReady else {
            throw AtelierWorkerStartupError.notReady(readiness.blockers)
        }
    }
}
