import Foundation
import Testing
@testable import AtelierContracts

@Test func noteRecordUsesAtelierNamespaceAndRoundTrips() throws {
    let date = Date(timeIntervalSince1970: 1_700_000_000)
    let record = AtelierNoteRecord(
        title: "A note",
        markdown: "# A note",
        createdAt: date,
        updatedAt: date
    )
    let data = try JSONEncoder().encode(record)
    #expect(try JSONDecoder().decode(AtelierNoteRecord.self, from: data) == record)
    #expect(AtelierNoteRecord.nsid == "diy.atelier.notes.note")
}

@Test func generatedLexiconContractsPreservePublicDisclosureModel() throws {
    #expect(AtelierGeneratedLexiconCatalog.schemaDigest == "5eb102f6b0da687c6891b40308cebe83123e526eb818d5b16535ed6a2fe98483")
    #expect(AtelierGeneratedLexiconCatalog.compatibilityDigest == "e96842a9f9896118fc6f42b474ec5dfa3edf5095c6976063245779b42a3280b4")
    let metadata = try #require(AtelierGeneratedLexiconCatalog.recordMetadata[DiyAtelierNotesNoteRecord.nsid])
    #expect(metadata.publicData)
    #expect(metadata.requiredFields == ["title", "markdown", "createdAt", "updatedAt", "schemaVersion"])
    #expect(AtelierGeneratedLexiconCatalog.recordMetadata.values.allSatisfy { $0.publicData })
    #expect(AtelierNoteRecord.nsid == DiyAtelierNotesNoteRecord.nsid)
}

@Test func generatedNoteCodableUsesTheCanonicalWireShape() throws {
    let record = DiyAtelierNotesNoteRecord(
        title: "Compatibility title",
        markdown: AtMarkpubMarkdown(text: AtMarkpubText(markdown: "# Compatibility\n")),
        schemaVersion: 1,
        createdAt: "2026-01-02T03:04:05.000Z",
        updatedAt: "2026-01-02T03:04:05.000Z"
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    let encoded = try #require(String(data: encoder.encode(record), encoding: .utf8))
    let expected = ##"{"$type":"diy.atelier.notes.note","createdAt":"2026-01-02T03:04:05.000Z","markdown":{"text":{"markdown":"# Compatibility\n"}},"schemaVersion":1,"title":"Compatibility title","updatedAt":"2026-01-02T03:04:05.000Z"}"##
    #expect(encoded == expected)
    #expect(AtelierGeneratedLexiconCatalog.canonicalRecordJSON[DiyAtelierNotesNoteRecord.nsid] == expected)
}
