import ATProtoPrimitiveKit
import Crypto
import Foundation

public enum AtelierATProtoError: Error, Equatable, Sendable {
    case invalidPKCEByteCount
    case invalidXRPCBaseURL
    case invalidXRPCMethod(String)
}

/// RFC 7636 primitives extracted from AnyPub's server implementation. The
/// authorization lifecycle, PAR, token storage, and callback validation remain
/// service/client responsibilities rather than being implied by this type.
public struct PKCEPair: Equatable, Sendable {
    public let verifier: String
    public let challenge: String

    public init(verifier: String) {
        self.verifier = verifier
        challenge = Base64URL.encodeNoPadding(
            digest: SHA256.hash(data: Data(verifier.utf8))
        )
    }

    public static func generate(byteCount: Int = 48) throws -> PKCEPair {
        guard (32...96).contains(byteCount) else {
            throw AtelierATProtoError.invalidPKCEByteCount
        }
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<byteCount).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        return PKCEPair(verifier: Base64URL.encodeNoPadding(data: Data(bytes)))
    }
}

public struct DPoPKey: @unchecked Sendable {
    private let privateKey: P256.Signing.PrivateKey

    public init() {
        privateKey = P256.Signing.PrivateKey()
    }

    public init(rawRepresentation: Data) throws {
        privateKey = try P256.Signing.PrivateKey(rawRepresentation: rawRepresentation)
    }

    /// Raw key material must be persisted only by a platform secure store or
    /// server-side envelope-encrypted credential store.
    public var rawRepresentation: Data {
        privateKey.rawRepresentation
    }

    public func proof(
        method: String,
        url: URL,
        accessToken: String? = nil,
        nonce: String? = nil,
        now: Date = Date(),
        identifier: String = UUID().uuidString
    ) throws -> String {
        let publicKey = privateKey.publicKey.x963Representation
        let jwk = PublicJWK(
            x: Base64URL.encodeNoPadding(data: Data(publicKey[1...32])),
            y: Base64URL.encodeNoPadding(data: Data(publicKey[33...64]))
        )
        let header = DPoPHeader(jwk: jwk)
        let payload = DPoPPayload(
            identifier: identifier,
            method: method.uppercased(),
            targetURL: Self.normalizedTargetURL(url).absoluteString,
            issuedAt: Int(now.timeIntervalSince1970),
            accessTokenHash: accessToken.map {
                Base64URL.encodeNoPadding(digest: SHA256.hash(data: Data($0.utf8)))
            },
            nonce: nonce
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let encodedHeader = Base64URL.encodeNoPadding(data: try encoder.encode(header))
        let encodedPayload = Base64URL.encodeNoPadding(data: try encoder.encode(payload))
        let signingInput = "\(encodedHeader).\(encodedPayload)"
        let signature = try privateKey.signature(for: Data(signingInput.utf8))
        return "\(signingInput).\(Base64URL.encodeNoPadding(data: signature.rawRepresentation))"
    }

    private static func normalizedTargetURL(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        components.query = nil
        components.fragment = nil
        return components.url ?? url
    }
}

/// Deterministic construction for the intentionally explicit XRPC transport
/// boundary. Callers still own OAuth, DPoP nonce retry, response decoding, and
/// typed error handling.
public enum XRPCRequestTarget: Sendable {
    public static func url(
        service: URL,
        method: String,
        queryItems: [URLQueryItem] = []
    ) throws -> URL {
        let trimmedMethod = method.trimmingCharacters(in: .whitespacesAndNewlines)
        guard NSID(trimmedMethod) != nil else {
            throw AtelierATProtoError.invalidXRPCMethod(method)
        }
        guard var components = URLComponents(
            // Preserve the method's case. Lexicon method names conventionally
            // contain camelCase even though the pinned primitive validator
            // currently exposes a lowercased `absoluteString`.
            url: service.appending(path: "xrpc").appending(path: trimmedMethod),
            resolvingAgainstBaseURL: false
        ) else {
            throw AtelierATProtoError.invalidXRPCBaseURL
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components.url else {
            throw AtelierATProtoError.invalidXRPCBaseURL
        }
        return url
    }
}

private struct PublicJWK: Codable, Sendable {
    let keyType = "EC"
    let curve = "P-256"
    let x: String
    let y: String

    enum CodingKeys: String, CodingKey {
        case keyType = "kty"
        case curve = "crv"
        case x, y
    }
}

private struct DPoPHeader: Codable, Sendable {
    let type = "dpop+jwt"
    let algorithm = "ES256"
    let jwk: PublicJWK

    enum CodingKeys: String, CodingKey {
        case type = "typ"
        case algorithm = "alg"
        case jwk
    }
}

private struct DPoPPayload: Codable, Sendable {
    let identifier: String
    let method: String
    let targetURL: String
    let issuedAt: Int
    let accessTokenHash: String?
    let nonce: String?

    enum CodingKeys: String, CodingKey {
        case identifier = "jti"
        case method = "htm"
        case targetURL = "htu"
        case issuedAt = "iat"
        case accessTokenHash = "ath"
        case nonce
    }
}
