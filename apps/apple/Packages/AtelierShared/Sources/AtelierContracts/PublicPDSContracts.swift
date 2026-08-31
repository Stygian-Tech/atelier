import AtelierCore
import Foundation

public enum PDSVisibility: String, Codable, Sendable {
    case publicRepository
    case permissionedSpace
}

public struct PublicPDSRecordReference: Codable, Equatable, Sendable {
    public let uri: String
    public let cid: String?
    public let visibility: PDSVisibility

    public init(uri: String, cid: String? = nil, visibility: PDSVisibility) {
        self.uri = uri
        self.cid = cid
        self.visibility = visibility
    }
}

public struct AtelierNoteRecord: Codable, Equatable, Sendable {
    public static let nsid = "diy.atelier.notes.note"

    public let title: String
    public let markdown: String
    public let createdAt: Date
    public let updatedAt: Date

    public init(title: String, markdown: String, createdAt: Date, updatedAt: Date) {
        self.title = title
        self.markdown = markdown
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
