package diy.atelier.contracts

import diy.atelier.contracts.generated.AtMarkpubMarkdown
import diy.atelier.contracts.generated.AtMarkpubText
import diy.atelier.contracts.generated.AtelierGeneratedLexiconCatalog
import diy.atelier.contracts.generated.CommunityLexiconCalendarEventRecord
import diy.atelier.contracts.generated.CommunityLexiconCalendarRsvpRecord
import diy.atelier.contracts.generated.DiyAtelierNotesNoteRecord
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class PublicPdsContractsTest {
    @Test
    fun noteRecordUsesAtelierNamespace() {
        assertEquals("diy.atelier.notes.note", AtelierNoteRecord.NSID)
    }

    @Test
    fun generatedContractsShareIdentifiersRequiredFieldsAndDisclosure() {
        assertEquals("5eb102f6b0da687c6891b40308cebe83123e526eb818d5b16535ed6a2fe98483", AtelierGeneratedLexiconCatalog.SCHEMA_DIGEST)
        assertEquals("e96842a9f9896118fc6f42b474ec5dfa3edf5095c6976063245779b42a3280b4", AtelierGeneratedLexiconCatalog.COMPATIBILITY_DIGEST)
        assertEquals(AtelierNoteRecord.NSID, DiyAtelierNotesNoteRecord.NSID)
        assertEquals(
            listOf("title", "markdown", "createdAt", "updatedAt", "schemaVersion"),
            AtelierGeneratedLexiconCatalog.recordMetadata.getValue(DiyAtelierNotesNoteRecord.NSID).requiredFields,
        )
        assertTrue(AtelierGeneratedLexiconCatalog.recordMetadata.values.all { it.publicData })
        assertEquals(
            listOf("diy.atelier.calendar.event", CommunityLexiconCalendarEventRecord.NSID, CommunityLexiconCalendarRsvpRecord.NSID),
            AtelierGeneratedLexiconCatalog.permissionSets.getValue("diy.atelier.auth.calendar").first().collections,
        )
    }

    @Test
    fun generatedNoteTypeMatchesCanonicalCompatibilityFields() {
        val note = DiyAtelierNotesNoteRecord(
            title = "Compatibility title",
            markdown = AtMarkpubMarkdown(AtMarkpubText("# Compatibility\n")),
            schemaVersion = 1,
            createdAt = "2026-01-02T03:04:05.000Z",
            updatedAt = "2026-01-02T03:04:05.000Z",
        )
        assertEquals("diy.atelier.notes.note", note.recordType)
        assertEquals("# Compatibility\n", note.markdown.text.markdown)
        val expected = """{"${'$'}type":"diy.atelier.notes.note","createdAt":"2026-01-02T03:04:05.000Z","markdown":{"text":{"markdown":"# Compatibility\n"}},"schemaVersion":1,"title":"Compatibility title","updatedAt":"2026-01-02T03:04:05.000Z"}"""
        assertEquals(expected, AtelierGeneratedLexiconCatalog.canonicalRecordJson.getValue(DiyAtelierNotesNoteRecord.NSID))
    }
}
