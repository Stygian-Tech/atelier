import ATProtoPrimitiveKit
import AtelierATProto
import AtelierContracts
import AtelierMCP
import AtelierProviders
import Crypto
import Foundation
import Testing

@Test func pkceMatchesRFC7636ChallengeFixture() throws {
    let fixture = try loadATProtoPrimitiveFixture()
    #expect(fixture.version == 1)
    let pair = PKCEPair(verifier: fixture.pkceVerifier)
    #expect(pair.challenge == fixture.pkceChallenge)
}

@Test func dpopProofBindsMethodTargetTokenAndNonce() throws {
    let fixture = try loadATProtoPrimitiveFixture()
    let key = DPoPKey()
    let proof = try key.proof(
        method: fixture.dpopMethodInput,
        url: #require(URL(string: fixture.dpopTarget)),
        accessToken: fixture.accessToken,
        nonce: fixture.dpopNonce,
        now: Date(timeIntervalSince1970: TimeInterval(fixture.dpopIssuedAtEpochSeconds)),
        identifier: fixture.dpopJti
    )
    let segments = proof.split(separator: ".").map(String.init)
    #expect(segments.count == 3)
    let payloadData = try Base64URL.decode(segments[1])
    let payload = try #require(JSONSerialization.jsonObject(with: payloadData) as? [String: Any])
    #expect(payload["jti"] as? String == fixture.dpopJti)
    #expect(payload["htm"] as? String == fixture.dpopMethod)
    #expect(payload["htu"] as? String == fixture.dpopNormalizedHtu)
    #expect(payload["iat"] as? Int == fixture.dpopIssuedAtEpochSeconds)
    #expect(payload["nonce"] as? String == fixture.dpopNonce)
    #expect(payload["ath"] as? String == fixture.accessTokenSha256Base64Url)

    let rawSignature = try Base64URL.decode(segments[2])
    #expect(rawSignature.count == 64)
    let signature = try P256.Signing.ECDSASignature(rawRepresentation: rawSignature)
    let verificationKey = try P256.Signing.PrivateKey(rawRepresentation: key.rawRepresentation).publicKey
    #expect(verificationKey.isValidSignature(
        signature,
        for: Data("\(segments[0]).\(segments[1])".utf8)
    ))
}

@Test func xrpcTargetUsesValidatedNSIDAndStableQueryEncoding() throws {
    let fixture = try loadATProtoPrimitiveFixture()
    let service = try #require(URL(string: fixture.xrpcService))
    let target = try XRPCRequestTarget.url(
        service: service,
        method: fixture.xrpcMethod,
        queryItems: [URLQueryItem(name: fixture.xrpcQueryName, value: fixture.xrpcQueryValue)]
    )
    #expect(target.absoluteString == fixture.xrpcTarget)
    #expect(throws: AtelierATProtoError.invalidXRPCMethod("invalid")) {
        try XRPCRequestTarget.url(service: service, method: "invalid")
    }
}

@Test func canonicalNamespaceAndDisclosure() {
    #expect(AtelierNamespace.root == "diy.atelier")
    #expect(DataBoundary.publicPDSDisclosure.contains("publicly readable"))
    #expect(!OAuthPermissionSets.scopes(for: .mail).contains(where: { $0.contains("space.atelierwork") }))
}

@Test func opaqueProviderReferenceHasOnlyOpaqueMetadata() throws {
    let reference = try OpaqueProviderReference(
        provider: .gmail,
        opaqueID: "v1_hmac_sha256:abc",
        resourceKind: "thread",
        sourceVersion: "history:1001"
    )
    let encoded = try #require(String(data: JSONEncoder().encode(reference), encoding: .utf8))
    #expect(!encoded.contains("subject"))
    #expect(!encoded.contains("snippet"))
    #expect(!encoded.contains("body"))
}

@Test func mcpScopePolicyDoesNotPretendToValidateSensitiveApproval() throws {
    let subject = try AtelierContracts.DID("did:plc:atelier-test")
    let send = try #require(AtelierMCPTools.all.first(where: { $0.name == "mail_send" }))
    let policy = MCPAuthorizationPolicy()
    #expect(throws: MCPAuthorizationError.missingScopes(["mail.send"])) {
        try policy.authorizeScopes(send, invocation: .init(subject: subject, grantedScopes: []))
    }
    try policy.authorizeScopes(
        send,
        invocation: .init(subject: subject, grantedScopes: ["mail.send"])
    )

    let claim = MCPApprovalClaim(
        subject: subject,
        toolName: send.name,
        argumentDigest: "sha256:fixed",
        nonce: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        expiresAt: Date(timeIntervalSince1970: 1_700_000_060)
    )
    #expect(claim.version == MCPApprovalClaim.currentVersion)
}

@Test func providerDescriptorsDoNotPretendImplementationsExist() {
    let descriptor = ProviderDescriptor(
        name: "Gmail",
        capabilities: MailProviderKind.gmail.capabilities,
        availability: .contractOnly(reason: "OAuth credentials and adapter are not configured")
    )
    #expect(descriptor.capabilities.labels)
    #expect(descriptor.availability != .configured)
    #expect(!CalendarProviderKind.caldav.capabilities.pushNotifications)
}

@Test func generatedLexiconsShareStableIdentifiersAndPublicMetadata() throws {
    #expect(AtelierGeneratedLexiconCatalog.schemaDigest == "5eb102f6b0da687c6891b40308cebe83123e526eb818d5b16535ed6a2fe98483")
    #expect(AtelierGeneratedLexiconCatalog.compatibilityDigest == "e96842a9f9896118fc6f42b474ec5dfa3edf5095c6976063245779b42a3280b4")
    let noteMetadata = try #require(AtelierGeneratedLexiconCatalog.recordMetadata[DiyAtelierNotesNoteRecord.nsid])
    #expect(noteMetadata.requiredFields == ["title", "markdown", "createdAt", "updatedAt", "schemaVersion"])
    #expect(noteMetadata.publicData)
    #expect(AtelierGeneratedLexiconCatalog.recordMetadata.values.allSatisfy { $0.publicData })

    let calendarGrant = try #require(AtelierGeneratedLexiconCatalog.permissionSets["diy.atelier.auth.calendar"]?.first)
    #expect(calendarGrant.collections == [
        "diy.atelier.calendar.event",
        CommunityLexiconCalendarEventRecord.nsid,
        CommunityLexiconCalendarRsvpRecord.nsid,
    ])
}

@Test func generatedNoteCodableMatchesCanonicalCompatibilityJSON() throws {
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
    #expect(try JSONDecoder().decode(DiyAtelierNotesNoteRecord.self, from: encoder.encode(record)) == record)
}

private struct ATProtoPrimitiveFixture: Decodable {
    let version: Int
    let pkceVerifier: String
    let pkceChallenge: String
    let accessToken: String
    let accessTokenSha256Base64Url: String
    let dpopMethodInput: String
    let dpopMethod: String
    let dpopTarget: String
    let dpopNormalizedHtu: String
    let dpopNonce: String
    let dpopIssuedAtEpochSeconds: Int
    let dpopJti: String
    let xrpcService: String
    let xrpcMethod: String
    let xrpcQueryName: String
    let xrpcQueryValue: String
    let xrpcTarget: String
}

private func loadATProtoPrimitiveFixture() throws -> ATProtoPrimitiveFixture {
    let sourceFile = URL(fileURLWithPath: #filePath)
    let packagesDirectory = (0..<4).reduce(sourceFile) { directory, _ in
        directory.deletingLastPathComponent()
    }
    let fixtureURL = packagesDirectory
        .appendingPathComponent("contracts")
        .appendingPathComponent("fixtures")
        .appendingPathComponent("atproto-primitives.json")
    return try JSONDecoder().decode(
        ATProtoPrimitiveFixture.self,
        from: Data(contentsOf: fixtureURL)
    )
}
