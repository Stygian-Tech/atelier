import AtelierCalendarSyncKit
import AtelierWorkerKit
import Foundation

@main
struct AtelierCalendarSync {
    static func main() async throws {
        let environment = ProcessInfo.processInfo.environment
        let configuration = try CalendarSyncServiceConfiguration(environment: environment)
        let executorRegistry = try CalendarSyncExecutorRegistry(executors: [])
        let readiness = CalendarSyncService.readiness(
            configuration: configuration,
            jobStoreAdapterAvailable: false,
            executorRegistry: executorRegistry
        )
        guard readiness.isReady else {
            throw CalendarSyncStartupError.notReady(readiness.blockers)
        }

        let store = try DurableJobStoreBootstrap.makeStore(configuration: configuration.protectedStorage.jobStore)
        let handlers = try executorRegistry.handlers(for: configuration.enabledSources)
        let processor = try DurableJobProcessor(store: store, handlers: handlers)
        let workerConfiguration = try WorkerRuntimeConfiguration(
            environment: environment,
            workerName: "atelier-calendar-sync"
        )
        try await processor.run(configuration: workerConfiguration)
    }
}
