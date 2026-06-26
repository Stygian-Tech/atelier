import AtelierCore
import AtelierMCP
import AtelierMail
import AtelierPlatform
import Foundation

struct AtelierAPIEntrypoint {
    static func run() async throws {
        if CommandLine.arguments.contains("--summary") {
            try writeSummary()
            return
        }

        try await AtelierHTTPServer().run()
    }

    private static func writeSummary() throws {
        let registry = MCPToolRegistry(tools: MailMCPTools.readOnly)
        let router = MailAPIRouter()
        let summary = APISummary(
            serviceName: "Atelier Mail API",
            namespace: AtelierNamespace.root,
            mcpTools: registry.tools.map(\.name),
            providerOrder: MailProviderKind.allCases.map(\.rawValue),
            routes: router.routes
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(summary)
        FileHandle.standardOutput.write(data)
        FileHandle.standardOutput.write(Data("\n".utf8))
    }
}

try await AtelierAPIEntrypoint.run()

public struct APISummary: Codable, Equatable, Sendable {
    public var serviceName: String
    public var namespace: String
    public var mcpTools: [String]
    public var providerOrder: [String]
    public var routes: [RouteDescriptor]

    public init(serviceName: String, namespace: String, mcpTools: [String], providerOrder: [String], routes: [RouteDescriptor] = []) {
        self.serviceName = serviceName
        self.namespace = namespace
        self.mcpTools = mcpTools
        self.providerOrder = providerOrder
        self.routes = routes
    }
}
