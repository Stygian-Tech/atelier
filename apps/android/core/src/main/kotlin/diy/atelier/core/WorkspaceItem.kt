package diy.atelier.core

import java.time.Instant
import java.util.UUID

data class WorkspaceItem(
    val id: String = UUID.randomUUID().toString(),
    val title: String,
    val summary: String,
    val markdown: String,
    val updatedAt: Instant = Instant.now(),
    val sectionId: String,
)
