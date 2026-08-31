package diy.atelier.persistence

import diy.atelier.core.AppProduct
import diy.atelier.core.WorkspaceItem
import org.junit.Assert.assertEquals
import org.junit.Test

class MockLocalWorkspaceRepositoryTest {
    @Test
    fun namedMockStoresLocalDraft() {
        val repository = MockLocalWorkspaceRepository(AppProduct.NOTES)
        val item = WorkspaceItem(
            title = "Draft",
            summary = "Local",
            markdown = "# Draft",
            sectionId = "all-notes",
        )
        repository.save(item)
        assertEquals(item, repository.item(item.id))
    }
}
