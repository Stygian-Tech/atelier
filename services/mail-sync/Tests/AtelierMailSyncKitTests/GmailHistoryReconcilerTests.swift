import AtelierMailSyncKit
import Foundation
import Testing

private func historyID(_ value: UInt64) -> GmailHistoryID {
    GmailHistoryID(rawValue: value)
}

private func incrementalState(
    cursor: UInt64,
    generation: UInt64 = 0
) -> GmailHistoryState {
    .incremental(cursor: historyID(cursor), generation: generation)
}

private func mutation(
    _ history: UInt64,
    _ kind: GmailHistoryMutation.Kind,
    _ resource: String
) -> GmailHistoryMutation {
    .init(historyID: historyID(history), kind: kind, opaqueResourceID: resource)
}

@Test func historyIDsUseLosslessDecimalStringCoding() throws {
    let maximum = try GmailHistoryID(String(UInt64.max))
    #expect(maximum == historyID(.max))
    #expect(try String(decoding: JSONEncoder().encode(maximum), as: UTF8.self) == "\"18446744073709551615\"")
    #expect(throws: GmailHistoryModelError.invalidHistoryID) {
        _ = try GmailHistoryID("12.5")
    }
    #expect(throws: GmailHistoryModelError.invalidHistoryID) {
        _ = try GmailHistoryID("-1")
    }
}

@Test func initialAndStaleHistoryDeterministicallyRequestFullSync() {
    let initial = GmailHistoryState.initial
    let initialRequest = GmailFullSyncRequest(generation: 0, reason: .cursorNotInitialized)
    let whileInitial = GmailHistoryReconciler.reduce(
        state: initial,
        input: .historyBatch(.init(
            requestedStartHistoryID: historyID(1),
            mailboxHistoryID: historyID(2),
            mutations: []
        ))
    )
    #expect(whileInitial == .init(
        state: initial,
        actions: [.requestFullSync(initialRequest)]
    ))
    #expect(initialRequest.idempotencyKey == "gmail-full-sync-v1-0")

    let started = GmailHistoryReconciler.reduce(
        state: initial,
        input: .fullSyncCompleted(generation: 0, snapshotHistoryID: historyID(100))
    )
    #expect(started == .init(
        state: incrementalState(cursor: 100),
        actions: [.persistCursor(historyID(100))]
    ))

    let stale = GmailHistoryReconciler.reduce(
        state: started.state,
        input: .historyUnavailable(requestedStartHistoryID: historyID(100))
    )
    let staleRequest = GmailFullSyncRequest(
        generation: 1,
        reason: .staleHistoryID(historyID(100))
    )
    #expect(stale == .init(
        state: .fullSyncRequired(staleRequest),
        actions: [.requestFullSync(staleRequest)]
    ))

    // Replaying the stale result emits the same durable request and idempotency key.
    #expect(GmailHistoryReconciler.reduce(
        state: stale.state,
        input: .historyUnavailable(requestedStartHistoryID: historyID(100))
    ) == stale)
}

@Test func duplicateAndReplayedHistoryApplyExactlyOnceInCanonicalOrder() throws {
    let duplicate = mutation(105, .messageAdded, "opaque-message-b")
    let batch = GmailHistoryBatch(
        requestedStartHistoryID: historyID(100),
        mailboxHistoryID: historyID(120),
        mutations: [
            duplicate,
            mutation(103, .labelRemoved, "opaque-message-a"),
            duplicate,
            mutation(105, .labelAdded, "opaque-message-a"),
            mutation(99, .messageDeleted, "already-applied"),
        ]
    )
    let first = GmailHistoryReconciler.reduce(
        state: incrementalState(cursor: 100),
        input: .historyBatch(batch)
    )
    let applied = try #require(first.actions.first)
    #expect(applied == .applyMutations([
        mutation(103, .labelRemoved, "opaque-message-a"),
        mutation(105, .labelAdded, "opaque-message-a"),
        duplicate,
    ]))
    #expect(first.actions.last == .persistCursor(historyID(120)))
    #expect(first.state == incrementalState(cursor: 120))

    let replay = GmailHistoryReconciler.reduce(state: first.state, input: .historyBatch(batch))
    #expect(replay == .init(state: first.state, actions: []))

    let encoded = try String(decoding: JSONEncoder().encode(batch), as: UTF8.self)
    #expect(!encoded.contains("subject"))
    #expect(!encoded.contains("body"))
    #expect(encoded.contains("opaqueResourceID"))
}

@Test func nonContiguousGmailHistoryIDsAreValidButRequestCursorGapsFailClosed() {
    // Gmail history IDs are increasing but not contiguous; 201 -> 900 is not itself a gap.
    let valid = GmailHistoryReconciler.reduce(
        state: incrementalState(cursor: 200, generation: 7),
        input: .historyBatch(.init(
            requestedStartHistoryID: historyID(200),
            mailboxHistoryID: historyID(1_000),
            mutations: [
                mutation(201, .messageAdded, "one"),
                mutation(900, .messageDeleted, "two"),
            ]
        ))
    )
    #expect(valid.state == incrementalState(cursor: 1_000, generation: 7))
    #expect(valid.actions.last == .persistCursor(historyID(1_000)))

    // Starting after the durable cursor could omit changes and therefore requires reconciliation.
    let gap = GmailHistoryReconciler.reduce(
        state: incrementalState(cursor: 200, generation: 7),
        input: .historyBatch(.init(
            requestedStartHistoryID: historyID(250),
            mailboxHistoryID: historyID(300),
            mutations: []
        ))
    )
    let request = GmailFullSyncRequest(
        generation: 8,
        reason: .cursorGap(expected: historyID(200), requested: historyID(250))
    )
    #expect(gap == .init(
        state: .fullSyncRequired(request),
        actions: [.requestFullSync(request)]
    ))
}

@Test func staleResponsesAndLateFullSyncCompletionsNeverMoveCursorBackward() {
    let current = incrementalState(cursor: 500, generation: 3)
    let staleFixtures: [GmailHistoryInput] = [
        .historyBatch(.init(
            requestedStartHistoryID: historyID(400),
            mailboxHistoryID: historyID(499),
            mutations: [mutation(450, .messageAdded, "old")]
        )),
        .historyUnavailable(requestedStartHistoryID: historyID(499)),
        .fullSyncCompleted(generation: 2, snapshotHistoryID: historyID(600)),
        .fullSyncCompleted(generation: 3, snapshotHistoryID: historyID(400)),
    ]

    for fixture in staleFixtures {
        #expect(GmailHistoryReconciler.reduce(state: current, input: fixture) == .init(
            state: current,
            actions: []
        ))
    }
}

@Test func inconsistentBatchFailsClosedAndWrongGenerationCannotCompleteReconciliation() {
    let inconsistent = GmailHistoryReconciler.reduce(
        state: incrementalState(cursor: 10, generation: 2),
        input: .historyBatch(.init(
            requestedStartHistoryID: historyID(10),
            mailboxHistoryID: historyID(20),
            mutations: [mutation(21, .messageAdded, "future")]
        ))
    )
    let request = GmailFullSyncRequest(
        generation: 3,
        reason: .inconsistentBatch(mailbox: historyID(20), newestMutation: historyID(21))
    )
    #expect(inconsistent == .init(
        state: .fullSyncRequired(request),
        actions: [.requestFullSync(request)]
    ))

    let wrongGeneration = GmailHistoryReconciler.reduce(
        state: inconsistent.state,
        input: .fullSyncCompleted(generation: 2, snapshotHistoryID: historyID(30))
    )
    #expect(wrongGeneration == .init(
        state: inconsistent.state,
        actions: [.requestFullSync(request)]
    ))
}
