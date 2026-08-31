import AtelierMailSyncKit
import Foundation
import Testing

private let mimeBuilder = MarkdownMIMEBuilder()
private let sender = Mailbox(displayName: "Atelier Sender", address: "sender@example.com")
private let recipient = Mailbox(displayName: "Sam", address: "sam@example.com")

private func draft(subject: String = "Draft", markdown: String = "Hello") -> MarkdownMailDraft {
    MarkdownMailDraft(from: sender, to: [recipient], subject: subject, markdown: markdown)
}

private func hasOnlyCRLFLineEndings(_ data: Data) -> Bool {
    let bytes = Array(data)
    for index in bytes.indices {
        if bytes[index] == 0x0a, (index == 0 || bytes[index - 1] != 0x0d) {
            return false
        }
        if bytes[index] == 0x0d, (index + 1 == bytes.count || bytes[index + 1] != 0x0a) {
            return false
        }
    }
    return true
}

@Test func unicodeMarkdownProducesPlainFallbackAndSanitizedHTML() throws {
    let fixtures = [
        "# Hello, 世界 👋",
        "Привет, **мир**",
        "مرحبا [آمن](https://example.com/مسار)",
        "<script>alert('no')</script> [bad](javascript:alert(1))",
        "Cafe\u{301} and café",
    ]

    for fixture in fixtures {
        let rendered = mimeBuilder.render(markdown: fixture)
        #expect(!rendered.plainText.isEmpty)
        #expect(rendered.sanitizedHTML.hasPrefix("<!doctype html><html><body>"))
        #expect(!rendered.sanitizedHTML.contains("<script>"))
        #expect(!rendered.sanitizedHTML.contains("href=\"javascript:"))

        let data = try mimeBuilder.build(draft: draft(subject: "Unicode ✓", markdown: fixture))
        let message = try #require(String(data: data, encoding: .utf8))
        #expect(hasOnlyCRLFLineEndings(data))
        #expect(message.contains("Content-Type: multipart/alternative"))
        #expect(message.contains("Content-Type: text/plain; charset=utf-8"))
        #expect(message.contains("Content-Type: text/html; charset=utf-8"))
        #expect(message.components(separatedBy: "Content-Transfer-Encoding: base64").count == 3)
        #expect(message.contains("Subject: =?UTF-8?B?"))
    }

    let rendered = mimeBuilder.render(
        markdown: "**Bold** and [safe](https://example.com?q=1&ok=yes) <b>raw</b>"
    )
    #expect(rendered.plainText == "Bold and safe (https://example.com?q=1&ok=yes) <b>raw</b>")
    #expect(rendered.sanitizedHTML.contains("<strong>Bold</strong>"))
    #expect(rendered.sanitizedHTML.contains("href=\"https://example.com?q=1&amp;ok=yes\""))
    #expect(rendered.sanitizedHTML.contains("&lt;b&gt;raw&lt;/b&gt;"))
}

@Test func attachmentPermutationsProduceIdenticalCanonicalMIME() throws {
    let alpha = MIMEAttachment(
        filename: "alpha-資料.txt",
        mediaType: "text/plain",
        data: Data("alpha".utf8)
    )
    let middle = MIMEAttachment(
        filename: "middle.png",
        mediaType: "image/png",
        data: Data([0x89, 0x50, 0x4e, 0x47])
    )
    let zeta = MIMEAttachment(
        filename: "zeta.pdf",
        mediaType: "application/pdf",
        data: Data("pdf".utf8)
    )
    let permutations = [
        [alpha, middle, zeta],
        [alpha, zeta, middle],
        [middle, alpha, zeta],
        [middle, zeta, alpha],
        [zeta, alpha, middle],
        [zeta, middle, alpha],
    ]

    let expected = try mimeBuilder.build(
        draft: draft(subject: "Attachments", markdown: "Body"),
        attachments: permutations[0]
    )
    for permutation in permutations {
        #expect(try mimeBuilder.build(
            draft: draft(subject: "Attachments", markdown: "Body"),
            attachments: permutation
        ) == expected)
    }

    let message = try #require(String(data: expected, encoding: .utf8))
    #expect(message.contains("Content-Type: multipart/mixed"))
    #expect(message.contains("Content-Type: multipart/alternative"))
    let alphaIndex = try #require(message.range(of: "filename*=UTF-8''alpha-%E8%B3%87%E6%96%99.txt"))
    let middleIndex = try #require(message.range(of: "filename*=UTF-8''middle.png"))
    let zetaIndex = try #require(message.range(of: "filename*=UTF-8''zeta.pdf"))
    #expect(alphaIndex.lowerBound < middleIndex.lowerBound)
    #expect(middleIndex.lowerBound < zetaIndex.lowerBound)
    #expect(hasOnlyCRLFLineEndings(expected))
    #expect(message.components(separatedBy: "Content-Transfer-Encoding: base64").count == 6)
}

@Test func identicalDraftsProduceByteIdenticalOutputAndRFCLineLengths() throws {
    let attachment = MIMEAttachment(
        filename: "large.bin",
        mediaType: "application/octet-stream",
        data: Data(repeating: 0xab, count: 1_024)
    )
    let value = draft(
        subject: String(repeating: "Unicode subject 🚀 ", count: 20),
        markdown: String(repeating: "line with Unicode 🌌\n", count: 20)
    )

    let first = try mimeBuilder.build(draft: value, attachments: [attachment])
    let second = try mimeBuilder.build(draft: value, attachments: [attachment])
    #expect(first == second)
    #expect(hasOnlyCRLFLineEndings(first))

    let message = try #require(String(data: first, encoding: .utf8))
    let lines = message.components(separatedBy: "\r\n")
    #expect(lines.allSatisfy { $0.utf8.count <= 998 })

    let base64Alphabet = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
    for line in lines where !line.isEmpty && line.unicodeScalars.allSatisfy(base64Alphabet.contains) {
        #expect(line.utf8.count <= 76)
    }
}

@Test func everyHeaderSurfaceRejectsInjectionOrInvalidSyntax() {
    #expect(throws: MarkdownMIMEError.invalidHeaderValue("subject")) {
        try mimeBuilder.build(draft: draft(subject: "Hello\r\nBcc: attacker@example.com"))
    }
    #expect(throws: MarkdownMIMEError.invalidHeaderValue("from.displayName")) {
        try mimeBuilder.build(draft: MarkdownMailDraft(
            from: Mailbox(displayName: "Sender\nBcc: attacker@example.com", address: "sender@example.com"),
            to: [recipient],
            subject: "Draft",
            markdown: "Body"
        ))
    }
    #expect(throws: MarkdownMIMEError.invalidMailboxAddress("to")) {
        try mimeBuilder.build(draft: MarkdownMailDraft(
            from: sender,
            to: [Mailbox(address: "victim@example.com\r\nBcc: attacker@example.com")],
            subject: "Draft",
            markdown: "Body"
        ))
    }
    #expect(throws: MarkdownMIMEError.invalidAttachmentFilename) {
        try mimeBuilder.build(
            draft: draft(),
            attachments: [.init(
                filename: "safe.txt\r\nContent-Type: text/html",
                mediaType: "text/plain",
                data: Data()
            )]
        )
    }
    #expect(throws: MarkdownMIMEError.invalidMediaType) {
        try mimeBuilder.build(
            draft: draft(),
            attachments: [.init(
                filename: "safe.txt",
                mediaType: "text/plain\r\nX-Evil: yes",
                data: Data()
            )]
        )
    }
    #expect(throws: MarkdownMIMEError.missingRecipient) {
        try mimeBuilder.build(draft: MarkdownMailDraft(
            from: sender,
            to: [],
            subject: "Draft",
            markdown: "Body"
        ))
    }
}
