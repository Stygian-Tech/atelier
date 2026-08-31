import AtelierCore
import Foundation

public protocol LocalWorkspaceRepository: Sendable {
    func items(in sectionID: String) async -> [WorkspaceItem]
    func item(id: WorkspaceItem.ID) async -> WorkspaceItem?
    func save(_ item: WorkspaceItem) async
}

public actor MockLocalWorkspaceRepository: LocalWorkspaceRepository {
    private var itemsByID: [WorkspaceItem.ID: WorkspaceItem]

    public init(product: AppProduct) {
        let firstSection = product.sections.first?.id ?? "inbox"
        let samples = [
            WorkspaceItem(
                title: "Welcome to \(product.displayName)",
                summary: "A local-only sample for the native foundation.",
                markdown: "# Welcome\n\nThis draft is stored only in the clearly named local mock repository.",
                sectionID: firstSection
            ),
            WorkspaceItem(
                title: "Public data reminder",
                summary: "PDS records are readable and may be mirrored.",
                markdown: "# Public AT Protocol data\n\nDo not publish secrets or private provider content to a standard PDS.",
                sectionID: firstSection
            ),
        ]
        itemsByID = Dictionary(uniqueKeysWithValues: samples.map { ($0.id, $0) })
    }

    public func items(in sectionID: String) -> [WorkspaceItem] {
        itemsByID.values
            .filter { $0.sectionID == sectionID }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    public func item(id: WorkspaceItem.ID) -> WorkspaceItem? {
        itemsByID[id]
    }

    public func save(_ item: WorkspaceItem) {
        itemsByID[item.id] = item
    }
}
