import Crypto
import Foundation

/// Service-local protected mail content. It deliberately has no dependency on Atelier's
/// public PDS record models; callers must keep both this value and the resulting MIME bytes
/// in protected provider storage.
public struct MarkdownMailDraft: Equatable, Sendable {
    public let from: Mailbox
    public let to: [Mailbox]
    public let subject: String
    public let markdown: String

    public init(from: Mailbox, to: [Mailbox], subject: String, markdown: String) {
        self.from = from
        self.to = to
        self.subject = subject
        self.markdown = markdown
    }
}

public struct Mailbox: Equatable, Sendable {
    public let displayName: String?
    public let address: String

    public init(displayName: String? = nil, address: String) {
        self.displayName = displayName
        self.address = address
    }
}

public struct MIMEAttachment: Equatable, Sendable {
    public let filename: String
    public let mediaType: String
    public let data: Data

    public init(filename: String, mediaType: String, data: Data) {
        self.filename = filename
        self.mediaType = mediaType
        self.data = data
    }
}

public struct RenderedMarkdown: Equatable, Sendable {
    public let plainText: String
    public let sanitizedHTML: String

    public init(plainText: String, sanitizedHTML: String) {
        self.plainText = plainText
        self.sanitizedHTML = sanitizedHTML
    }
}

public enum MarkdownMIMEError: Error, Equatable, Sendable {
    case missingRecipient
    case invalidHeaderValue(String)
    case invalidMailboxAddress(String)
    case invalidAttachmentFilename
    case invalidMediaType
    case boundaryGenerationFailed
}

/// Builds deterministic RFC 5322/MIME bytes. Deliberately omitted headers such as Date and
/// Message-ID are expected to be supplied by a future provider adapter because inventing them
/// here would make identical drafts produce different bytes.
public struct MarkdownMIMEBuilder: Sendable {
    public init() {}

    public func render(markdown: String) -> RenderedMarkdown {
        MarkdownRenderer.render(markdown)
    }

    public func build(draft: MarkdownMailDraft, attachments: [MIMEAttachment] = []) throws -> Data {
        try validate(draft: draft, attachments: attachments)

        let rendered = render(markdown: draft.markdown)
        let orderedAttachments = canonicalAttachments(attachments)
        let seed = canonicalSeed(draft: draft, rendered: rendered, attachments: orderedAttachments)
        let encodedPlainText = Self.wrappedBase64(Data(rendered.plainText.utf8))
        let encodedHTML = Self.wrappedBase64(Data(rendered.sanitizedHTML.utf8))
        let encodedAttachments = orderedAttachments.map {
            ($0, Self.wrappedBase64($0.data))
        }
        let collisionSurfaces = [encodedPlainText, encodedHTML] + encodedAttachments.map(\.1)

        let alternativeBoundary = try Self.boundary(
            kind: "alternative",
            seed: seed,
            collisionSurfaces: collisionSurfaces
        )
        let mixedBoundary = orderedAttachments.isEmpty ? nil : try Self.boundary(
            kind: "mixed",
            seed: seed,
            collisionSurfaces: collisionSurfaces + [alternativeBoundary]
        )

        var lines: [String] = []
        lines.append(contentsOf: Self.singleValueHeader("From", Self.render(draft.from)))
        lines.append(contentsOf: Self.mailboxListHeader("To", draft.to.map(Self.render)))
        lines.append(contentsOf: Self.encodedWordHeader("Subject", draft.subject))
        lines.append("MIME-Version: 1.0")

        if let mixedBoundary {
            lines.append("Content-Type: multipart/mixed; boundary=\"\(mixedBoundary)\"")
            lines.append("")
            lines.append("--\(mixedBoundary)")
            lines.append("Content-Type: multipart/alternative; boundary=\"\(alternativeBoundary)\"")
            lines.append("")
            Self.appendAlternativeBody(
                to: &lines,
                boundary: alternativeBoundary,
                encodedPlainText: encodedPlainText,
                encodedHTML: encodedHTML
            )

            for (attachment, encodedData) in encodedAttachments {
                let encodedFilename = Self.rfc2231Value(attachment.filename)
                lines.append("--\(mixedBoundary)")
                lines.append("Content-Type: \(attachment.mediaType); name*=UTF-8''\(encodedFilename)")
                lines.append("Content-Disposition: attachment; filename*=UTF-8''\(encodedFilename)")
                lines.append("Content-Transfer-Encoding: base64")
                lines.append("")
                lines.append(encodedData)
            }
            lines.append("--\(mixedBoundary)--")
        } else {
            lines.append("Content-Type: multipart/alternative; boundary=\"\(alternativeBoundary)\"")
            lines.append("")
            Self.appendAlternativeBody(
                to: &lines,
                boundary: alternativeBoundary,
                encodedPlainText: encodedPlainText,
                encodedHTML: encodedHTML
            )
        }

        lines.append("")
        return Data(lines.joined(separator: "\r\n").utf8)
    }

    private func validate(draft: MarkdownMailDraft, attachments: [MIMEAttachment]) throws {
        guard !draft.to.isEmpty else {
            throw MarkdownMIMEError.missingRecipient
        }
        try Self.validateMailbox(draft.from, field: "from")
        for mailbox in draft.to {
            try Self.validateMailbox(mailbox, field: "to")
        }
        try Self.validateHeaderText(draft.subject, field: "subject")

        for attachment in attachments {
            guard !attachment.filename.isEmpty, attachment.filename.utf8.count <= 180 else {
                throw MarkdownMIMEError.invalidAttachmentFilename
            }
            do {
                try Self.validateHeaderText(attachment.filename, field: "attachment.filename")
            } catch {
                throw MarkdownMIMEError.invalidAttachmentFilename
            }
            guard Self.isMediaType(attachment.mediaType) else {
                throw MarkdownMIMEError.invalidMediaType
            }
        }
    }

    private static func validateMailbox(_ mailbox: Mailbox, field: String) throws {
        if let displayName = mailbox.displayName {
            guard displayName.utf8.count <= 256 else {
                throw MarkdownMIMEError.invalidHeaderValue("\(field).displayName")
            }
            try validateHeaderText(displayName, field: "\(field).displayName")
        }
        guard mailbox.address.utf8.count <= 254, isMailboxAddress(mailbox.address) else {
            throw MarkdownMIMEError.invalidMailboxAddress(field)
        }
    }

    private static func validateHeaderText(_ value: String, field: String) throws {
        guard value.unicodeScalars.allSatisfy({ scalar in
            let value = scalar.value
            return value >= 0x20 && value != 0x7f && value != 0x2028 && value != 0x2029
        }) else {
            throw MarkdownMIMEError.invalidHeaderValue(field)
        }
    }

    private static func isMailboxAddress(_ value: String) -> Bool {
        guard value.unicodeScalars.allSatisfy({ $0.isASCII }),
              !value.contains(where: { $0.isWhitespace }) else {
            return false
        }
        let pieces = value.split(separator: "@", omittingEmptySubsequences: false)
        guard pieces.count == 2 else { return false }
        let local = String(pieces[0])
        let domain = String(pieces[1])
        guard !local.isEmpty, !domain.isEmpty,
              local.first != ".", local.last != ".", !local.contains("..") else {
            return false
        }
        let localAllowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.!#$%&'*+-/=?^_`{|}~")
        guard local.allSatisfy(localAllowed.contains) else { return false }

        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.allSatisfy({ label in
            !label.isEmpty
                && label.first != "-"
                && label.last != "-"
                && label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
        }) else {
            return false
        }
        return true
    }

    private static func isMediaType(_ value: String) -> Bool {
        guard value.utf8.count <= 127,
              value.unicodeScalars.allSatisfy({ $0.isASCII }) else {
            return false
        }
        let pieces = value.split(separator: "/", omittingEmptySubsequences: false)
        guard pieces.count == 2 else { return false }
        let tokenCharacters = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$%&'*+-.^_`|~")
        return pieces.allSatisfy { !$0.isEmpty && $0.allSatisfy(tokenCharacters.contains) }
    }

    private func canonicalAttachments(_ attachments: [MIMEAttachment]) -> [MIMEAttachment] {
        attachments.sorted { lhs, rhs in
            let lhsFilename = Data(lhs.filename.utf8)
            let rhsFilename = Data(rhs.filename.utf8)
            if lhsFilename != rhsFilename {
                return lhsFilename.lexicographicallyPrecedes(rhsFilename)
            }
            let lhsMediaType = Data(lhs.mediaType.utf8)
            let rhsMediaType = Data(rhs.mediaType.utf8)
            if lhsMediaType != rhsMediaType {
                return lhsMediaType.lexicographicallyPrecedes(rhsMediaType)
            }
            let lhsDigest = Data(SHA256.hash(data: lhs.data))
            let rhsDigest = Data(SHA256.hash(data: rhs.data))
            if lhsDigest != rhsDigest {
                return lhsDigest.lexicographicallyPrecedes(rhsDigest)
            }
            return lhs.data.lexicographicallyPrecedes(rhs.data)
        }
    }

    private func canonicalSeed(
        draft: MarkdownMailDraft,
        rendered: RenderedMarkdown,
        attachments: [MIMEAttachment]
    ) -> Data {
        var data = Data()
        Self.appendLengthPrefixed(Self.render(draft.from), to: &data)
        for recipient in draft.to {
            Self.appendLengthPrefixed(Self.render(recipient), to: &data)
        }
        Self.appendLengthPrefixed(draft.subject, to: &data)
        Self.appendLengthPrefixed(rendered.plainText, to: &data)
        Self.appendLengthPrefixed(rendered.sanitizedHTML, to: &data)
        for attachment in attachments {
            Self.appendLengthPrefixed(attachment.filename, to: &data)
            Self.appendLengthPrefixed(attachment.mediaType, to: &data)
            Self.appendLengthPrefixed(attachment.data, to: &data)
        }
        return data
    }

    private static func appendLengthPrefixed(_ string: String, to data: inout Data) {
        appendLengthPrefixed(Data(string.utf8), to: &data)
    }

    private static func appendLengthPrefixed(_ value: Data, to data: inout Data) {
        var count = UInt64(value.count).bigEndian
        withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }
        data.append(value)
    }

    private static func boundary(
        kind: String,
        seed: Data,
        collisionSurfaces: [String]
    ) throws -> String {
        for counter in 0..<1_024 {
            var material = seed
            appendLengthPrefixed(kind, to: &material)
            var bigEndianCounter = UInt64(counter).bigEndian
            withUnsafeBytes(of: &bigEndianCounter) { material.append(contentsOf: $0) }
            let digest = SHA256.hash(data: material)
            let suffix = digest.prefix(18).map { String(format: "%02x", $0) }.joined()
            let candidate = "=_atelier_\(kind)_\(suffix)"
            if collisionSurfaces.allSatisfy({ !$0.contains(candidate) }) {
                return candidate
            }
        }
        throw MarkdownMIMEError.boundaryGenerationFailed
    }

    private static func appendAlternativeBody(
        to lines: inout [String],
        boundary: String,
        encodedPlainText: String,
        encodedHTML: String
    ) {
        lines.append("--\(boundary)")
        lines.append("Content-Type: text/plain; charset=utf-8")
        lines.append("Content-Transfer-Encoding: base64")
        lines.append("")
        lines.append(encodedPlainText)
        lines.append("--\(boundary)")
        lines.append("Content-Type: text/html; charset=utf-8")
        lines.append("Content-Transfer-Encoding: base64")
        lines.append("")
        lines.append(encodedHTML)
        lines.append("--\(boundary)--")
    }

    private static func wrappedBase64(_ data: Data) -> String {
        let encoded = data.base64EncodedString()
        guard !encoded.isEmpty else { return "" }
        var lines: [Substring] = []
        var start = encoded.startIndex
        while start < encoded.endIndex {
            let end = encoded.index(start, offsetBy: 76, limitedBy: encoded.endIndex) ?? encoded.endIndex
            lines.append(encoded[start..<end])
            start = end
        }
        return lines.map(String.init).joined(separator: "\r\n")
    }

    private static func render(_ mailbox: Mailbox) -> String {
        guard let displayName = mailbox.displayName, !displayName.isEmpty else {
            return "<\(mailbox.address)>"
        }
        return "\(encodedWords(displayName)) <\(mailbox.address)>"
    }

    private static func encodedWordHeader(_ name: String, _ value: String) -> [String] {
        guard !value.isEmpty else { return ["\(name):"] }
        return foldHeader(name: name, tokens: encodedWordTokens(value), separator: " ")
    }

    private static func encodedWords(_ value: String) -> String {
        encodedWordTokens(value).joined(separator: " ")
    }

    private static func encodedWordTokens(_ value: String) -> [String] {
        var chunks: [String] = []
        var current = ""
        var currentByteCount = 0
        for scalar in value.unicodeScalars {
            let string = String(scalar)
            let byteCount = string.utf8.count
            if currentByteCount + byteCount > 42, !current.isEmpty {
                chunks.append(current)
                current = ""
                currentByteCount = 0
            }
            current.append(contentsOf: string)
            currentByteCount += byteCount
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks.map { chunk in
            "=?UTF-8?B?\(Data(chunk.utf8).base64EncodedString())?="
        }
    }

    private static func singleValueHeader(_ name: String, _ value: String) -> [String] {
        foldHeader(name: name, tokens: value.split(separator: " ").map(String.init), separator: " ")
    }

    private static func mailboxListHeader(_ name: String, _ values: [String]) -> [String] {
        foldHeader(name: name, tokens: values, separator: ", ")
    }

    private static func foldHeader(name: String, tokens: [String], separator: String) -> [String] {
        guard let first = tokens.first else { return ["\(name):"] }
        var lines = ["\(name): \(first)"]
        for token in tokens.dropFirst() {
            let addition = separator + token
            if lines[lines.count - 1].utf8.count + addition.utf8.count <= 78 {
                lines[lines.count - 1] += addition
            } else {
                if separator == ", " {
                    lines[lines.count - 1] += ","
                }
                lines.append(" \(token)")
            }
        }
        return lines
    }

    private static func rfc2231Value(_ value: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$&+-.^_`|~".utf8)
        return value.utf8.map { byte in
            allowed.contains(byte) ? String(UnicodeScalar(byte)) : String(format: "%%%02X", byte)
        }.joined()
    }
}

private enum MarkdownRenderer {
    static func render(_ markdown: String) -> RenderedMarkdown {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        return RenderedMarkdown(
            plainText: renderPlain(lines),
            sanitizedHTML: renderHTML(lines)
        )
    }

    private static func renderPlain(_ lines: [String]) -> String {
        lines.map { line in
            if let (_, content) = heading(line) {
                return inlinePlain(content)
            }
            if let content = listItem(line) {
                return "• \(inlinePlain(content))"
            }
            return inlinePlain(line)
        }.joined(separator: "\n")
    }

    private static func renderHTML(_ lines: [String]) -> String {
        var blocks: [String] = []
        var paragraph: [String] = []
        var listItems: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            blocks.append("<p>\(paragraph.map { inlineHTML($0) }.joined(separator: "<br>\n"))</p>")
            paragraph.removeAll(keepingCapacity: true)
        }

        func flushList() {
            guard !listItems.isEmpty else { return }
            let items = listItems.map { "<li>\(inlineHTML($0))</li>" }.joined()
            blocks.append("<ul>\(items)</ul>")
            listItems.removeAll(keepingCapacity: true)
        }

        for line in lines {
            if line.isEmpty {
                flushParagraph()
                flushList()
            } else if let (level, content) = heading(line) {
                flushParagraph()
                flushList()
                blocks.append("<h\(level)>\(inlineHTML(content))</h\(level)>")
            } else if let content = listItem(line) {
                flushParagraph()
                listItems.append(content)
            } else {
                flushList()
                paragraph.append(line)
            }
        }
        flushParagraph()
        flushList()

        return "<!doctype html><html><body>\(blocks.joined(separator: "\n"))</body></html>"
    }

    private static func heading(_ line: String) -> (Int, String)? {
        let hashes = line.prefix(while: { $0 == "#" })
        guard (1...6).contains(hashes.count),
              line.dropFirst(hashes.count).first == " " else {
            return nil
        }
        return (hashes.count, String(line.dropFirst(hashes.count + 1)))
    }

    private static func listItem(_ line: String) -> String? {
        guard line.count >= 2 else { return nil }
        let marker = line.first
        guard marker == "-" || marker == "*" || marker == "+",
              line.dropFirst().first == " " else {
            return nil
        }
        return String(line.dropFirst(2))
    }

    private static func inlineHTML(_ value: String, depth: Int = 0) -> String {
        guard depth < 8 else { return escapeHTML(value) }
        var result = ""
        var index = value.startIndex

        while index < value.endIndex {
            if value[index...].hasPrefix("**"),
               let close = value.range(of: "**", range: value.index(index, offsetBy: 2)..<value.endIndex) {
                let contentStart = value.index(index, offsetBy: 2)
                result += "<strong>\(inlineHTML(String(value[contentStart..<close.lowerBound]), depth: depth + 1))</strong>"
                index = close.upperBound
            } else if value[index] == "*",
                      let close = value[value.index(after: index)...].firstIndex(of: "*") {
                result += "<em>\(inlineHTML(String(value[value.index(after: index)..<close]), depth: depth + 1))</em>"
                index = value.index(after: close)
            } else if value[index] == "`",
                      let close = value[value.index(after: index)...].firstIndex(of: "`") {
                result += "<code>\(escapeHTML(String(value[value.index(after: index)..<close])))</code>"
                index = value.index(after: close)
            } else if value[index] == "[", let link = parseLink(value, from: index) {
                let label = inlineHTML(link.label, depth: depth + 1)
                if isAllowedLink(link.destination) {
                    result += "<a href=\"\(escapeAttribute(link.destination))\">\(label)</a>"
                } else {
                    result += label
                }
                index = link.end
            } else {
                result += escapeHTML(String(value[index]))
                index = value.index(after: index)
            }
        }
        return result
    }

    private static func inlinePlain(_ value: String, depth: Int = 0) -> String {
        guard depth < 8 else { return value }
        var result = ""
        var index = value.startIndex

        while index < value.endIndex {
            if value[index...].hasPrefix("**"),
               let close = value.range(of: "**", range: value.index(index, offsetBy: 2)..<value.endIndex) {
                let start = value.index(index, offsetBy: 2)
                result += inlinePlain(String(value[start..<close.lowerBound]), depth: depth + 1)
                index = close.upperBound
            } else if value[index] == "*",
                      let close = value[value.index(after: index)...].firstIndex(of: "*") {
                result += inlinePlain(String(value[value.index(after: index)..<close]), depth: depth + 1)
                index = value.index(after: close)
            } else if value[index] == "`",
                      let close = value[value.index(after: index)...].firstIndex(of: "`") {
                result += String(value[value.index(after: index)..<close])
                index = value.index(after: close)
            } else if value[index] == "[", let link = parseLink(value, from: index) {
                result += inlinePlain(link.label, depth: depth + 1)
                if isAllowedLink(link.destination) {
                    result += " (\(link.destination))"
                }
                index = link.end
            } else {
                result.append(value[index])
                index = value.index(after: index)
            }
        }
        return result
    }

    private static func parseLink(
        _ value: String,
        from start: String.Index
    ) -> (label: String, destination: String, end: String.Index)? {
        guard let labelEnd = value[value.index(after: start)...].firstIndex(of: "]"),
              value.index(after: labelEnd) < value.endIndex,
              value[value.index(after: labelEnd)] == "(" else {
            return nil
        }
        let destinationStart = value.index(labelEnd, offsetBy: 2)
        guard let destinationEnd = value[destinationStart...].firstIndex(of: ")") else {
            return nil
        }
        return (
            String(value[value.index(after: start)..<labelEnd]),
            String(value[destinationStart..<destinationEnd]),
            value.index(after: destinationEnd)
        )
    }

    private static func isAllowedLink(_ value: String) -> Bool {
        guard value.unicodeScalars.allSatisfy({ scalar in
            scalar.value >= 0x20 && scalar.value != 0x7f
        }), let components = URLComponents(string: value), let scheme = components.scheme?.lowercased() else {
            return false
        }
        return scheme == "https" || scheme == "http" || scheme == "mailto"
    }

    private static func escapeHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static func escapeAttribute(_ value: String) -> String {
        escapeHTML(value).replacingOccurrences(of: "'", with: "&#39;")
    }
}
