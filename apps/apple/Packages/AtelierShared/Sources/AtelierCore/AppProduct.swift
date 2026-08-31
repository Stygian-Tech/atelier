import Foundation

public enum AppProduct: String, CaseIterable, Codable, Identifiable, Sendable {
    case atelier
    case notes
    case mail
    case calendar
    case tasks

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .atelier: "Atelier"
        case .notes: "Atelier Notes"
        case .mail: "Atelier Mail"
        case .calendar: "Atelier Calendar"
        case .tasks: "Atelier Tasks"
        }
    }

    public var bundleIdentifier: String {
        switch self {
        case .atelier: "diy.atelier"
        case .notes: "diy.atelier.notes"
        case .mail: "diy.atelier.mail"
        case .calendar: "diy.atelier.calendar"
        case .tasks: "diy.atelier.tasks"
        }
    }

    public var systemImage: String {
        switch self {
        case .atelier: "square.grid.2x2"
        case .notes: "note.text"
        case .mail: "envelope"
        case .calendar: "calendar"
        case .tasks: "checkmark.circle"
        }
    }

    public var sections: [WorkspaceSection] {
        switch self {
        case .atelier:
            [
                .init(id: "today", title: "Today", systemImage: "sun.max"),
                .init(id: "inbox", title: "Inbox", systemImage: "tray"),
                .init(id: "projects", title: "Projects", systemImage: "folder"),
            ]
        case .notes:
            [
                .init(id: "all-notes", title: "All Notes", systemImage: "note.text"),
                .init(id: "recent", title: "Recent", systemImage: "clock"),
                .init(id: "shared", title: "Shared", systemImage: "person.2"),
            ]
        case .mail:
            [
                .init(id: "inbox", title: "Inbox", systemImage: "tray"),
                .init(id: "starred", title: "Starred", systemImage: "star"),
                .init(id: "sent", title: "Sent", systemImage: "paperplane"),
            ]
        case .calendar:
            [
                .init(id: "upcoming", title: "Upcoming", systemImage: "calendar"),
                .init(id: "invitations", title: "Invitations", systemImage: "envelope.open"),
                .init(id: "feeds", title: "Calendar Feeds", systemImage: "dot.radiowaves.left.and.right"),
            ]
        case .tasks:
            [
                .init(id: "inbox", title: "Inbox", systemImage: "tray"),
                .init(id: "today", title: "Today", systemImage: "sun.max"),
                .init(id: "projects", title: "Projects", systemImage: "list.bullet.rectangle"),
            ]
        }
    }
}

public struct WorkspaceSection: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String

    public init(id: String, title: String, systemImage: String) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }
}
