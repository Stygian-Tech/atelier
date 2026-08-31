import Foundation
import Testing
@testable import AtelierCollaboration

@Test func collaborationOperationRoundTripsWithProtocolVersion() throws {
    let operation = CollaborationOperation(
        documentID: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
        authorDID: "did:example:alice",
        sequence: 7,
        payload: Data([0, 1, 2])
    )
    let data = try JSONEncoder().encode(operation)
    #expect(try JSONDecoder().decode(CollaborationOperation.self, from: data) == operation)
    #expect(operation.version == .foundation)
}
