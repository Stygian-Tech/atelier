import Foundation

public struct WorkspaceItem: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var summary: String
    public var markdown: String
    public var updatedAt: Date
    public var sectionID: String

    public init(
        id: UUID = UUID(),
        title: String,
        summary: String,
        markdown: String,
        updatedAt: Date = Date(),
        sectionID: String
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.markdown = markdown
        self.updatedAt = updatedAt
        self.sectionID = sectionID
    }
}
