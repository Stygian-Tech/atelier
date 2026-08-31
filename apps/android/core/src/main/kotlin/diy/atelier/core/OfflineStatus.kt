package diy.atelier.core

import java.time.Instant

enum class PersistencePhase {
    LOCAL_ONLY,
    QUEUED,
    SYNCING,
    DURABLE,
    NEEDS_ATTENTION,
}

data class OfflineStatus(
    val phase: PersistencePhase,
    val pendingChangeCount: Int = 0,
    val lastDurableAt: Instant? = null,
) {
    init {
        require(pendingChangeCount >= 0)
    }

    companion object {
        val LocalOnly = OfflineStatus(PersistencePhase.LOCAL_ONLY)
    }
}
