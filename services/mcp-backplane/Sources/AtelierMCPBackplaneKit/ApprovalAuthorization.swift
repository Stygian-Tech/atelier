import AtelierMCP
import Crypto
import Foundation

public enum MCPApprovalTokenError: Error, Equatable, Sendable {
    case weakKey
    case malformedToken
    case invalidSignature
    case invalidClaim
}

/// Authenticated approval token codec. The payload is readable JSON; HMAC-SHA256 protects every
/// claim field from alteration. Production key material must come from a secret manager.
public struct MCPApprovalTokenCodec: Sendable {
    private let keyData: Data

    public init(keyData: Data) throws {
        guard keyData.count >= 32 else { throw MCPApprovalTokenError.weakKey }
        self.keyData = keyData
    }

    public func sign(_ claim: MCPApprovalClaim) throws -> String {
        guard Self.isValidClaimShape(claim) else { throw MCPApprovalTokenError.invalidClaim }
        let payload = try Self.makeEncoder().encode(claim)
        let code = HMAC<SHA256>.authenticationCode(
            for: Self.authenticatedData(payload),
            using: SymmetricKey(data: keyData)
        )
        return "\(Self.base64URLEncode(payload)).\(Self.base64URLEncode(Data(code)))"
    }

    public func verify(_ token: String) throws -> MCPApprovalClaim {
        guard token.utf8.count <= 8_192 else { throw MCPApprovalTokenError.malformedToken }
        let components = token.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 2,
              let payload = Self.base64URLDecode(components[0]),
              payload.count <= 4_096,
              let suppliedCode = Self.base64URLDecode(components[1]) else {
            throw MCPApprovalTokenError.malformedToken
        }

        guard HMAC<SHA256>.isValidAuthenticationCode(
            suppliedCode,
            authenticating: Self.authenticatedData(payload),
            using: SymmetricKey(data: keyData)
        ) else {
            throw MCPApprovalTokenError.invalidSignature
        }

        let claim: MCPApprovalClaim
        do {
            claim = try Self.makeDecoder().decode(MCPApprovalClaim.self, from: payload)
        } catch {
            throw MCPApprovalTokenError.invalidClaim
        }
        guard Self.isValidClaimShape(claim) else { throw MCPApprovalTokenError.invalidClaim }
        return claim
    }

    private static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return encoder
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }

    private static func authenticatedData(_ payload: Data) -> Data {
        var data = Data("atelier.mcp.approval.v1\0".utf8)
        data.append(payload)
        return data
    }

    private static func isValidClaimShape(_ claim: MCPApprovalClaim) -> Bool {
        guard claim.version == MCPApprovalClaim.currentVersion,
              !claim.toolName.isEmpty,
              claim.argumentDigest.hasPrefix("sha256:") else {
            return false
        }
        let hexadecimal = claim.argumentDigest.dropFirst("sha256:".count)
        return hexadecimal.count == 64 && hexadecimal.allSatisfy {
            $0.isASCII && ($0.isNumber || ("a"..."f").contains($0))
        }
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func base64URLDecode<S: StringProtocol>(_ value: S) -> Data? {
        var base64 = String(value)
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.utf8.count % 4
        if remainder != 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }
}

public struct RejectingMCPApprovalAuthorizer: MCPApprovalAuthorizing {
    public init() {}
    public let isConfigured = false

    public func authorize(token: String?, invocation: MCPApprovalInvocation) async throws {
        throw MCPApprovalAuthorizationError.explicitApprovalRequired
    }
}

public struct SignedMCPApprovalAuthorizer: MCPApprovalAuthorizing {
    public let isConfigured = true
    private let codec: MCPApprovalTokenCodec
    private let store: any MCPSingleUseApprovalStore
    private let now: @Sendable () -> Date

    public init(
        codec: MCPApprovalTokenCodec,
        store: any MCPSingleUseApprovalStore,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.codec = codec
        self.store = store
        self.now = now
    }

    public func authorize(token: String?, invocation: MCPApprovalInvocation) async throws {
        guard let token, !token.isEmpty else {
            throw MCPApprovalAuthorizationError.explicitApprovalRequired
        }

        let claim: MCPApprovalClaim
        do {
            claim = try codec.verify(token)
        } catch {
            throw MCPApprovalAuthorizationError.invalidApproval
        }

        guard claim.subject == invocation.subject else {
            throw MCPApprovalAuthorizationError.subjectMismatch
        }
        guard claim.toolName == invocation.toolName else {
            throw MCPApprovalAuthorizationError.toolMismatch
        }
        guard claim.argumentDigest == invocation.argumentDigest else {
            throw MCPApprovalAuthorizationError.argumentsMismatch
        }
        guard claim.expiresAt > now() else {
            throw MCPApprovalAuthorizationError.expired
        }

        let consumed: Bool
        do {
            consumed = try await store.consume(nonce: claim.nonce, expiresAt: claim.expiresAt)
        } catch {
            throw MCPApprovalAuthorizationError.approvalStoreUnavailable
        }
        guard consumed else { throw MCPApprovalAuthorizationError.replayed }
    }
}
