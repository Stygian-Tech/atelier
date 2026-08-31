import Crypto
import Foundation

public enum JSONValue: Codable, Equatable, Sendable {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Decimal)
    case bool(Bool)
    case null

    public init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Decimal.self) {
            self = .number(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let value):
            try container.encode(value)
        case .array(let value):
            try container.encode(value)
        case .string(let value):
            try container.encode(value)
        case .number(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

public enum MCPCanonicalArgumentsError: Error, Equatable, Sendable {
    case argumentsMustBeObject
}

public enum MCPCanonicalArguments {
    public static func canonicalData(for arguments: JSONValue) throws -> Data {
        guard case .object = arguments else {
            throw MCPCanonicalArgumentsError.argumentsMustBeObject
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(arguments)
    }

    public static func digest(for arguments: JSONValue) throws -> String {
        let digest = SHA256.hash(data: try canonicalData(for: arguments))
        let hexadecimal = digest.map { byte -> String in
            let digits = Array("0123456789abcdef".utf8)
            return String(bytes: [digits[Int(byte >> 4)], digits[Int(byte & 0x0f)]], encoding: .utf8)!
        }.joined()
        return "sha256:\(hexadecimal)"
    }
}
