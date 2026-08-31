import Testing
@testable import AtelierCore

@Test func productIdentifiersAreStableAndUnique() {
    let identifiers = AppProduct.allCases.map(\.bundleIdentifier)
    #expect(Set(identifiers).count == 5)
    #expect(AppProduct.atelier.bundleIdentifier == "diy.atelier")
    #expect(AppProduct.notes.bundleIdentifier == "diy.atelier.notes")
    #expect(AppProduct.mail.bundleIdentifier == "diy.atelier.mail")
    #expect(AppProduct.calendar.bundleIdentifier == "diy.atelier.calendar")
    #expect(AppProduct.tasks.bundleIdentifier == "diy.atelier.tasks")
}

@Test func offlineStatusDoesNotClaimRemoteDurability() {
    #expect(OfflineStatus.localOnly.phase == .localOnly)
    #expect(OfflineStatus.localOnly.lastDurableAt == nil)
}
