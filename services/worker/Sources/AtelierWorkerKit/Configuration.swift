import AtelierJobs
import Foundation

public enum RuntimeConfigurationError: Error, Equatable, Sendable, CustomStringConvertible {
    case missingVariable(String)
    case unresolvedPlaceholder(String)
    case invalidValue(String)

    public var description: String {
        switch self {
        case .missingVariable(let name):
            "Missing required configuration: \(name)"
        case .unresolvedPlaceholder(let name):
            "Required configuration still contains a placeholder: \(name)"
        case .invalidValue(let name):
            "Invalid configuration: \(name)"
        }
    }
}

public struct EnvironmentReader: Sendable {
    private let values: [String: String]

    public init(_ values: [String: String]) {
        self.values = values
    }

    public func require(_ name: String) throws -> String {
        guard let rawValue = values[name] else {
            throw RuntimeConfigurationError.missingVariable(name)
        }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            throw RuntimeConfigurationError.missingVariable(name)
        }
        guard !value.hasPrefix("__SET_") else {
            throw RuntimeConfigurationError.unresolvedPlaceholder(name)
        }
        return value
    }

    public func optional(_ name: String) -> String? {
        guard let rawValue = values[name] else { return nil }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

public enum DeploymentEnvironment: String, Codable, Sendable {
    case development
    case production

    public init(reader: EnvironmentReader) throws {
        let value = try reader.require("ATELIER_ENV")
        guard let environment = Self(rawValue: value) else {
            throw RuntimeConfigurationError.invalidValue("ATELIER_ENV")
        }
        self = environment
    }
}

public enum DurableJobStoreBackend: String, Codable, Sendable {
    case postgres
}

public struct DurableJobStoreConfiguration: Equatable, Sendable {
    public let environment: DeploymentEnvironment
    public let backend: DurableJobStoreBackend
    private let databaseURL: String

    public init(environment values: [String: String]) throws {
        let reader = EnvironmentReader(values)
        environment = try DeploymentEnvironment(reader: reader)
        backend = .postgres

        let databaseURL = try reader.require("DATABASE_URL")
        let lowercasedURL = databaseURL.lowercased()
        guard lowercasedURL.hasPrefix("postgres://") || lowercasedURL.hasPrefix("postgresql://") else {
            throw RuntimeConfigurationError.invalidValue("DATABASE_URL")
        }
        self.databaseURL = databaseURL
    }

    internal var postgresConnectionString: String { databaseURL }
}

/// Configuration proving that protected provider data has durable, encrypted storage references.
/// Secret values are validated but deliberately not exposed by this value type.
public struct ProtectedProviderStorageConfiguration: Equatable, Sendable {
    public let jobStore: DurableJobStoreConfiguration
    public let googleCloudProject: String
    public let kmsKeyResource: String
    public let providerCacheBucket: String
    public let durableBucket: String
    public let workloadIdentityProvider: String
    public let hasProviderIDHMACKey: Bool

    public init(environment values: [String: String]) throws {
        let reader = EnvironmentReader(values)
        jobStore = try DurableJobStoreConfiguration(environment: values)

        _ = try reader.require("ATELIER_PROVIDER_ID_HMAC_KEY")
        hasProviderIDHMACKey = true
        googleCloudProject = try reader.require("GOOGLE_CLOUD_PROJECT")
        kmsKeyResource = try reader.require("GOOGLE_KMS_KEY_RESOURCE")
        providerCacheBucket = try reader.require("GOOGLE_PROVIDER_CACHE_BUCKET")
        durableBucket = try reader.require("GOOGLE_DURABLE_BUCKET")
        workloadIdentityProvider = try reader.require("GOOGLE_WORKLOAD_IDENTITY_PROVIDER")
    }
}

public struct ServiceReadiness: Equatable, Sendable {
    public let blockers: [String]

    public init(blockers: [String]) {
        self.blockers = blockers
    }

    public var isReady: Bool { blockers.isEmpty }
}

public struct WorkerRuntimeConfiguration: Equatable, Sendable {
    public let jobStore: DurableJobStoreConfiguration
    public let workerID: String
    public let leaseDuration: Duration
    public let idlePollInterval: Duration

    public init(environment values: [String: String], workerName: String = "atelier-worker") throws {
        let reader = EnvironmentReader(values)
        jobStore = try DurableJobStoreConfiguration(environment: values)

        let normalizedWorkerName = workerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedWorkerName.isEmpty else {
            throw RuntimeConfigurationError.invalidValue("workerName")
        }

        let instanceID = reader.optional("RAILWAY_REPLICA_ID")
            ?? reader.optional("HOSTNAME")
            ?? UUID().uuidString.lowercased()
        workerID = "\(normalizedWorkerName)-\(instanceID)"
        leaseDuration = .seconds(try Self.positiveInteger("ATELIER_JOB_LEASE_SECONDS", reader: reader, default: 60))
        idlePollInterval = .milliseconds(try Self.positiveInteger("ATELIER_JOB_POLL_MILLISECONDS", reader: reader, default: 1_000))
    }

    private static func positiveInteger(
        _ name: String,
        reader: EnvironmentReader,
        default defaultValue: Int
    ) throws -> Int {
        guard let value = reader.optional(name) else { return defaultValue }
        guard let integer = Int(value), integer > 0 else {
            throw RuntimeConfigurationError.invalidValue(name)
        }
        return integer
    }
}

public enum DurableJobStoreBootstrapError: Error, Equatable, Sendable, CustomStringConvertible {
    case postgresAdapterNotImplemented

    public var description: String {
        "The Postgres durable job-store adapter is not implemented; refusing to claim readiness"
    }
}

public enum DurableJobStoreBootstrap {
    public static var readiness: ServiceReadiness {
        ServiceReadiness(blockers: [
            "Postgres durable job-store adapter is not implemented",
        ])
    }

    public static func makeStore(
        configuration: DurableJobStoreConfiguration
    ) throws -> any DurableJobStore {
        _ = configuration.postgresConnectionString
        throw DurableJobStoreBootstrapError.postgresAdapterNotImplemented
    }
}
