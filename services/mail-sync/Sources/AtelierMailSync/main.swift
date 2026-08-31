import AtelierMailSyncKit
import AtelierWorkerKit
import Foundation

@main
struct AtelierMailSync {
    static func main() async throws {
        let environment = ProcessInfo.processInfo.environment
        let configuration = try MailSyncServiceConfiguration(environment: environment)
        let executorRegistry = try MailSyncExecutorRegistry(executors: [])
        let readiness = MailSyncService.readiness(
            configuration: configuration,
            jobStoreAdapterAvailable: false,
            executorRegistry: executorRegistry
        )
        guard readiness.isReady else {
            throw MailSyncStartupError.notReady(readiness.blockers)
        }

        let store = try DurableJobStoreBootstrap.makeStore(configuration: configuration.protectedStorage.jobStore)
        let handlers = try executorRegistry.handlers(for: configuration.enabledProviders)
        let processor = try DurableJobProcessor(store: store, handlers: handlers)
        let workerConfiguration = try WorkerRuntimeConfiguration(
            environment: environment,
            workerName: "atelier-mail-sync"
        )
        try await processor.run(configuration: workerConfiguration)
    }
}
