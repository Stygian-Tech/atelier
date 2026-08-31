package diy.atelier.contracts

import java.time.Instant

enum class PdsVisibility {
    PUBLIC_REPOSITORY,
    PERMISSIONED_SPACE,
}

data class PublicPdsRecordReference(
    val uri: String,
    val cid: String?,
    val visibility: PdsVisibility,
)

data class AtelierNoteRecord(
    val title: String,
    val markdown: String,
    val createdAt: Instant,
    val updatedAt: Instant,
) {
    companion object {
        const val NSID = "diy.atelier.notes.note"
    }
}
