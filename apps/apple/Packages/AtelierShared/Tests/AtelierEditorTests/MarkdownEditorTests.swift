import Testing
@testable import AtelierEditor

@MainActor
@Test func editingAdvancesRevisionAndTracksDirtyState() {
    let model = MarkdownEditorModel(document: MarkdownDocument(source: "Before", revision: 2))
    model.source = "After"
    #expect(model.document.revision == 3)
    #expect(model.isDirty)
    model.markSaved()
    #expect(!model.isDirty)
}
