import AtelierCore
import Testing
@testable import AtelierPersistence

@Test func namedMockRepositoryStoresLocalDrafts() async {
    let repository = MockLocalWorkspaceRepository(product: .notes)
    let draft = WorkspaceItem(
        title: "Draft",
        summary: "Local",
        markdown: "# Draft",
        sectionID: "all-notes"
    )
    await repository.save(draft)
    #expect(await repository.item(id: draft.id) == draft)
}
