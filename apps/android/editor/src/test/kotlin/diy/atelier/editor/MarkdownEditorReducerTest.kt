package diy.atelier.editor

import org.junit.Assert.assertEquals
import org.junit.Test

class MarkdownEditorReducerTest {
    @Test
    fun changedSourceAdvancesRevision() {
        val initial = MarkdownDocument(source = "Before", revision = 2u)
        val changed = MarkdownEditorReducer.replaceSource(initial, "After")
        assertEquals("After", changed.source)
        assertEquals(3uL, changed.revision)
    }

    @Test
    fun unchangedSourcePreservesRevision() {
        val initial = MarkdownDocument(source = "Same", revision = 2u)
        assertEquals(initial, MarkdownEditorReducer.replaceSource(initial, "Same"))
    }
}
