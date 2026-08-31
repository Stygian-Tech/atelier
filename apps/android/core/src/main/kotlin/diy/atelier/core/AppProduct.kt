package diy.atelier.core

enum class AppProduct(
    val displayName: String,
    val applicationId: String,
    val sections: List<WorkspaceSection>,
) {
    ATELIER(
        displayName = "Atelier",
        applicationId = "diy.atelier",
        sections = listOf(
            WorkspaceSection("today", "Today", "T"),
            WorkspaceSection("inbox", "Inbox", "I"),
            WorkspaceSection("projects", "Projects", "P"),
        ),
    ),
    NOTES(
        displayName = "Atelier Notes",
        applicationId = "diy.atelier.notes",
        sections = listOf(
            WorkspaceSection("all-notes", "All Notes", "N"),
            WorkspaceSection("recent", "Recent", "R"),
            WorkspaceSection("shared", "Shared", "S"),
        ),
    ),
    MAIL(
        displayName = "Atelier Mail",
        applicationId = "diy.atelier.mail",
        sections = listOf(
            WorkspaceSection("inbox", "Inbox", "I"),
            WorkspaceSection("starred", "Starred", "★"),
            WorkspaceSection("sent", "Sent", "S"),
        ),
    ),
    CALENDAR(
        displayName = "Atelier Calendar",
        applicationId = "diy.atelier.calendar",
        sections = listOf(
            WorkspaceSection("upcoming", "Upcoming", "U"),
            WorkspaceSection("invitations", "Invitations", "I"),
            WorkspaceSection("feeds", "Calendar Feeds", "F"),
        ),
    ),
    TASKS(
        displayName = "Atelier Tasks",
        applicationId = "diy.atelier.tasks",
        sections = listOf(
            WorkspaceSection("inbox", "Inbox", "I"),
            WorkspaceSection("today", "Today", "T"),
            WorkspaceSection("projects", "Projects", "P"),
        ),
    ),
}

data class WorkspaceSection(
    val id: String,
    val title: String,
    val shortLabel: String,
)
