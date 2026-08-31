package diy.atelier.persistence

import diy.atelier.core.AppProduct
import diy.atelier.core.WorkspaceItem

interface LocalWorkspaceRepository {
    fun items(sectionId: String): List<WorkspaceItem>
    fun item(id: String): WorkspaceItem?
    fun save(item: WorkspaceItem)
}

class MockLocalWorkspaceRepository(product: AppProduct) : LocalWorkspaceRepository {
    private val itemsById = linkedMapOf<String, WorkspaceItem>()

    init {
        val sectionId = product.sections.firstOrNull()?.id ?: "inbox"
        listOf(
            WorkspaceItem(
                title = "Welcome to ${product.displayName}",
                summary = "A local-only sample for the native foundation.",
                markdown = "# Welcome\n\nThis draft is stored only in the clearly named local mock repository.",
                sectionId = sectionId,
            ),
            WorkspaceItem(
                title = "Public data reminder",
                summary = "PDS records are readable and may be mirrored.",
                markdown = "# Public AT Protocol data\n\nDo not publish secrets or private provider content to a standard PDS.",
                sectionId = sectionId,
            ),
        ).forEach(::save)
    }

    override fun items(sectionId: String): List<WorkspaceItem> = itemsById.values
        .filter { it.sectionId == sectionId }
        .sortedByDescending(WorkspaceItem::updatedAt)

    override fun item(id: String): WorkspaceItem? = itemsById[id]

    override fun save(item: WorkspaceItem) {
        itemsById[item.id] = item
    }
}
