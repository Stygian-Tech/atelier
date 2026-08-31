import AtelierCore
import AtelierEditor
import AtelierPersistence
import Foundation
import Observation

@MainActor
@Observable
public final class WorkspaceModel {
    public let product: AppProduct
    public var selectedSectionID: WorkspaceSection.ID?
    public var selectedItemID: WorkspaceItem.ID? {
        didSet {
            guard oldValue != selectedItemID else { return }
            loadSelectedItemIntoEditor()
        }
    }
    public private(set) var items: [WorkspaceItem]
    public private(set) var offlineStatus: OfflineStatus
    public private(set) var isLoading: Bool
    public let editor: MarkdownEditorModel

    private let repository: any LocalWorkspaceRepository

    public init(
        product: AppProduct,
        repository: (any LocalWorkspaceRepository)? = nil
    ) {
        self.product = product
        selectedSectionID = product.sections.first?.id
        items = []
        offlineStatus = .localOnly
        isLoading = false
        editor = MarkdownEditorModel()
        self.repository = repository ?? MockLocalWorkspaceRepository(product: product)
    }

    public var selectedItem: WorkspaceItem? {
        guard let selectedItemID else { return nil }
        return items.first { $0.id == selectedItemID }
    }

    public var activeSectionID: WorkspaceSection.ID {
        selectedSectionID ?? product.sections.first?.id ?? "inbox"
    }

    public func loadSelectedSection() async {
        isLoading = true
        let loadedItems = await repository.items(in: activeSectionID)
        items = loadedItems
        isLoading = false

        if let selectedItemID, loadedItems.contains(where: { $0.id == selectedItemID }) {
            loadSelectedItemIntoEditor()
        } else {
            self.selectedItemID = loadedItems.first?.id
        }
    }

    public func createLocalDraft() async {
        let draft = WorkspaceItem(
            title: "Untitled",
            summary: "Local draft",
            markdown: "# Untitled\n",
            sectionID: activeSectionID
        )
        await repository.save(draft)
        items.insert(draft, at: 0)
        selectedItemID = draft.id
    }

    public func saveEditorDraftLocally() async {
        guard var selectedItem else { return }
        selectedItem.markdown = editor.source
        selectedItem.summary = editor.source
            .split(separator: "\n")
            .drop(while: { $0.hasPrefix("#") })
            .first
            .map(String.init) ?? "Local draft"
        selectedItem.updatedAt = Date()
        await repository.save(selectedItem)

        if let index = items.firstIndex(where: { $0.id == selectedItem.id }) {
            items[index] = selectedItem
        }
        editor.markSaved()
        offlineStatus = .localOnly
    }

    private func loadSelectedItemIntoEditor() {
        guard let selectedItem else {
            editor.document = MarkdownDocument()
            editor.markSaved()
            return
        }
        editor.document = MarkdownDocument(source: selectedItem.markdown)
        editor.markSaved()
    }
}
