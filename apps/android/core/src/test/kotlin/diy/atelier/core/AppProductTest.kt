package diy.atelier.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AppProductTest {
    @Test
    fun applicationIdsAreStableAndUnique() {
        val ids = AppProduct.entries.map(AppProduct::applicationId)
        assertEquals(5, ids.toSet().size)
        assertEquals("diy.atelier", AppProduct.ATELIER.applicationId)
        assertEquals("diy.atelier.notes", AppProduct.NOTES.applicationId)
        assertEquals("diy.atelier.mail", AppProduct.MAIL.applicationId)
        assertEquals("diy.atelier.calendar", AppProduct.CALENDAR.applicationId)
        assertEquals("diy.atelier.tasks", AppProduct.TASKS.applicationId)
    }

    @Test
    fun localOnlyStatusDoesNotClaimRemoteDurability() {
        assertEquals(PersistencePhase.LOCAL_ONLY, OfflineStatus.LocalOnly.phase)
        assertNull(OfflineStatus.LocalOnly.lastDurableAt)
    }
}
