import Foundation

public struct GmailHistoryID: RawRepresentable, Codable, Comparable, Hashable, Sendable {
    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    public init(_ decimalString: String) throws {
        guard !decimalString.isEmpty,
              decimalString.allSatisfy({ $0.isASCII && $0.isNumber }),
              let value = UInt64(decimalString) else {
            throw GmailHistoryModelError.invalidHistoryID
        }
        rawValue = value
    }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try GmailHistoryID(container.decode(String.self))
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(String(rawValue))
    }
}

public enum GmailHistoryModelError: Error, Equatable, Sendable {
    case invalidHistoryID
}

/// Opaque mutation vocabulary only. Provider message bodies, headers, and recipient data are
/// not accepted by this state machine and cannot be projected into a public PDS record here.
public struct GmailHistoryMutation: Codable, Equatable, Hashable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case messageAdded
        case messageDeleted
        case labelAdded
        case labelRemoved
    }

    public let historyID: GmailHistoryID
    public let kind: Kind
    public let opaqueResourceID: String

    public init(historyID: GmailHistoryID, kind: Kind, opaqueResourceID: String) {
        self.historyID = historyID
        self.kind = kind
        self.opaqueResourceID = opaqueResourceID
    }
}

/// A fully collected Gmail History response. A future adapter must finish pagination before
/// handing the batch to this reducer; the reducer itself performs no network calls.
public struct GmailHistoryBatch: Codable, Equatable, Sendable {
    public let requestedStartHistoryID: GmailHistoryID
    public let mailboxHistoryID: GmailHistoryID
    public let mutations: [GmailHistoryMutation]

    public init(
        requestedStartHistoryID: GmailHistoryID,
        mailboxHistoryID: GmailHistoryID,
        mutations: [GmailHistoryMutation]
    ) {
        self.requestedStartHistoryID = requestedStartHistoryID
        self.mailboxHistoryID = mailboxHistoryID
        self.mutations = mutations
    }
}

public struct GmailFullSyncRequest: Codable, Equatable, Sendable {
    public let generation: UInt64
    public let reason: GmailFullSyncReason

    public init(generation: UInt64, reason: GmailFullSyncReason) {
        self.generation = generation
        self.reason = reason
    }

    /// Stable key for a durable queue's unique constraint. Replayed transitions ask for the
    /// same work rather than generating a second full-sync job.
    public var idempotencyKey: String { "gmail-full-sync-v1-\(generation)" }
}

public enum GmailFullSyncReason: Codable, Equatable, Sendable {
    case cursorNotInitialized
    case staleHistoryID(GmailHistoryID)
    case cursorGap(expected: GmailHistoryID, requested: GmailHistoryID)
    case inconsistentBatch(mailbox: GmailHistoryID, newestMutation: GmailHistoryID)
}

public enum GmailHistoryState: Codable, Equatable, Sendable {
    case fullSyncRequired(GmailFullSyncRequest)
    case incremental(cursor: GmailHistoryID, generation: UInt64)

    public static var initial: Self {
        .fullSyncRequired(.init(generation: 0, reason: .cursorNotInitialized))
    }
}

public enum GmailHistoryInput: Equatable, Sendable {
    /// A complete, already-fetched History response.
    case historyBatch(GmailHistoryBatch)
    /// A future adapter maps Gmail's expired/invalid startHistoryId response to this input.
    case historyUnavailable(requestedStartHistoryID: GmailHistoryID)
    /// Protected storage reports that the specified generation's full snapshot is durable.
    case fullSyncCompleted(generation: UInt64, snapshotHistoryID: GmailHistoryID)
}

public enum GmailHistoryAction: Equatable, Sendable {
    case requestFullSync(GmailFullSyncRequest)
    case applyMutations([GmailHistoryMutation])
    case persistCursor(GmailHistoryID)
}

public struct GmailHistoryTransition: Equatable, Sendable {
    public let state: GmailHistoryState
    public let actions: [GmailHistoryAction]

    public init(state: GmailHistoryState, actions: [GmailHistoryAction]) {
        self.state = state
        self.actions = actions
    }
}

/// Pure, idempotent Gmail History reducer. The caller must apply its actions and persist the
/// returned state in one protected-storage transaction. This is the durable seam that prevents
/// an advanced cursor from hiding unapplied mutations after a crash.
public enum GmailHistoryReconciler {
    public static func reduce(
        state: GmailHistoryState,
        input: GmailHistoryInput
    ) -> GmailHistoryTransition {
        switch (state, input) {
        case (.fullSyncRequired(let request), .fullSyncCompleted(let generation, let snapshotHistoryID)):
            guard request.generation == generation else {
                return .init(state: state, actions: [.requestFullSync(request)])
            }
            return .init(
                state: .incremental(cursor: snapshotHistoryID, generation: generation),
                actions: [.persistCursor(snapshotHistoryID)]
            )

        case (.fullSyncRequired(let request), _):
            return .init(state: state, actions: [.requestFullSync(request)])

        case (.incremental, .fullSyncCompleted):
            // Late or duplicate completion from a full sync must never overwrite a newer cursor.
            return .init(state: state, actions: [])

        case (
            .incremental(let cursor, let generation),
            .historyUnavailable(let requestedStartHistoryID)
        ):
            guard requestedStartHistoryID >= cursor else {
                // A late stale-cursor response from an older, already-applied request is harmless.
                return .init(state: state, actions: [])
            }
            let reason: GmailFullSyncReason = requestedStartHistoryID == cursor
                ? .staleHistoryID(requestedStartHistoryID)
                : .cursorGap(expected: cursor, requested: requestedStartHistoryID)
            return requireFullSync(generation: generation, reason: reason)

        case (.incremental(let cursor, let generation), .historyBatch(let batch)):
            guard batch.requestedStartHistoryID <= cursor else {
                return requireFullSync(
                    generation: generation,
                    reason: .cursorGap(expected: cursor, requested: batch.requestedStartHistoryID)
                )
            }

            // A complete response older than the durable cursor is a replay, not evidence that
            // Gmail lost data. Ignore it without moving the cursor backwards.
            guard batch.mailboxHistoryID >= cursor else {
                return .init(state: state, actions: [])
            }

            if let newest = batch.mutations.map(\.historyID).max(), newest > batch.mailboxHistoryID {
                return requireFullSync(
                    generation: generation,
                    reason: .inconsistentBatch(mailbox: batch.mailboxHistoryID, newestMutation: newest)
                )
            }

            let mutations = canonicalMutations(batch.mutations.filter { $0.historyID > cursor })
            var actions: [GmailHistoryAction] = []
            if !mutations.isEmpty {
                actions.append(.applyMutations(mutations))
            }
            if batch.mailboxHistoryID > cursor {
                actions.append(.persistCursor(batch.mailboxHistoryID))
            }

            let nextState: GmailHistoryState = batch.mailboxHistoryID > cursor
                ? .incremental(cursor: batch.mailboxHistoryID, generation: generation)
                : state
            return .init(state: nextState, actions: actions)
        }
    }

    private static func requireFullSync(
        generation: UInt64,
        reason: GmailFullSyncReason
    ) -> GmailHistoryTransition {
        let nextGeneration = generation == .max ? generation : generation + 1
        let request = GmailFullSyncRequest(generation: nextGeneration, reason: reason)
        return .init(
            state: .fullSyncRequired(request),
            actions: [.requestFullSync(request)]
        )
    }

    private static func canonicalMutations(
        _ mutations: [GmailHistoryMutation]
    ) -> [GmailHistoryMutation] {
        Array(Set(mutations)).sorted { lhs, rhs in
            if lhs.historyID != rhs.historyID { return lhs.historyID < rhs.historyID }
            if lhs.kind != rhs.kind { return lhs.kind.rawValue < rhs.kind.rawValue }
            return lhs.opaqueResourceID < rhs.opaqueResourceID
        }
    }
}
