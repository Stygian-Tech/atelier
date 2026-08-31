import Observation
import SwiftUI

public struct MarkdownDocument: Codable, Equatable, Sendable {
    public var source: String
    public var revision: UInt64

    public init(source: String = "", revision: UInt64 = 0) {
        self.source = source
        self.revision = revision
    }

    public func replacingSource(with source: String) -> MarkdownDocument {
        MarkdownDocument(source: source, revision: revision + 1)
    }
}

@MainActor
@Observable
public final class MarkdownEditorModel {
    public var document: MarkdownDocument
    public private(set) var isDirty: Bool

    public init(document: MarkdownDocument = MarkdownDocument()) {
        self.document = document
        isDirty = false
    }

    public var source: String {
        get { document.source }
        set {
            guard newValue != document.source else { return }
            document = document.replacingSource(with: newValue)
            isDirty = true
        }
    }

    public func markSaved() {
        isDirty = false
    }
}

/// The initial platform-native Markdown surface. `TextEditor` is backed by the
/// system text stack and leaves a narrow seam for a richer TextKit editor.
public struct NativeMarkdownEditor: View {
    @Bindable private var model: MarkdownEditorModel

    public init(model: MarkdownEditorModel) {
        self.model = model
    }

    public var body: some View {
        TextEditor(text: $model.source)
            .font(.body.monospaced())
            .scrollContentBackground(.hidden)
            .padding(8)
            .accessibilityLabel(Text("Markdown editor", bundle: .module))
            .accessibilityHint(Text("Edit the canonical Markdown source.", bundle: .module))
    }
}
