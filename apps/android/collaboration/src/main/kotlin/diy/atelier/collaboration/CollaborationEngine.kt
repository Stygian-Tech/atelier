package diy.atelier.collaboration

data class CollaborationProtocolVersion(
    val major: UShort,
    val minor: UShort,
) {
    companion object {
        val Foundation = CollaborationProtocolVersion(major = 0u, minor = 1u)
    }
}

data class CollaborationOperation(
    val documentId: String,
    val authorDid: String,
    val sequence: ULong,
    val payload: ByteArray,
    val version: CollaborationProtocolVersion = CollaborationProtocolVersion.Foundation,
)

sealed interface CollaborationAvailability {
    data object NotConfigured : CollaborationAvailability
    data object Available : CollaborationAvailability
    data class Unavailable(val reason: String) : CollaborationAvailability
}

interface CollaborationEngine {
    suspend fun availability(): CollaborationAvailability
    suspend fun apply(operation: CollaborationOperation)
}
