import Foundation

#if os(Linux)
import Glibc
#else
import Darwin
#endif

public struct HTTPServerConfiguration: Sendable {
    public var host: String
    public var port: Int32

    public init(host: String = "0.0.0.0", port: Int32 = 8080) {
        self.host = host
        self.port = port
    }

    public static func environment() -> HTTPServerConfiguration {
        let port = ProcessInfo.processInfo.environment["PORT"]
            .flatMap(Int32.init) ??
            ProcessInfo.processInfo.environment["ATELIER_API_PORT"].flatMap(Int32.init) ??
            8080
        let host = ProcessInfo.processInfo.environment["ATELIER_API_HOST"] ?? "0.0.0.0"
        return HTTPServerConfiguration(host: host, port: port)
    }
}

public final class AtelierHTTPServer: @unchecked Sendable {
    private let configuration: HTTPServerConfiguration
    private let router: MailAPIRouter

    public init(configuration: HTTPServerConfiguration = .environment(), router: MailAPIRouter = MailAPIRouter()) {
        self.configuration = configuration
        self.router = router
    }

    public func run() async throws {
        let serverSocket = socket(AF_INET, SOCK_STREAM, 0)
        guard serverSocket >= 0 else {
            throw HTTPServerError.socketCreateFailed(errno)
        }

        var reuse: Int32 = 1
        setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = UInt16(configuration.port).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr(configuration.host))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockaddrPointer in
                bind(serverSocket, sockaddrPointer, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            close(serverSocket)
            throw HTTPServerError.bindFailed(errno)
        }

        guard listen(serverSocket, 128) == 0 else {
            close(serverSocket)
            throw HTTPServerError.listenFailed(errno)
        }

        print("Atelier Mail API listening on \(configuration.host):\(configuration.port)")

        while true {
            let clientSocket = accept(serverSocket, nil, nil)
            guard clientSocket >= 0 else { continue }
            Task {
                await self.handle(clientSocket)
            }
        }
    }

    private func handle(_ clientSocket: Int32) async {
        defer { close(clientSocket) }

        do {
            let requestData = try readRequest(from: clientSocket)
            let request = try parseRequest(requestData)
            let response = await router.handle(request)
            try write(response, to: clientSocket)
        } catch {
            let response = APIResponse(
                status: 400,
                body: Data("{\"error\":\"bad_request\"}".utf8)
            )
            try? write(response, to: clientSocket)
        }
    }

    private func readRequest(from socket: Int32) throws -> Data {
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        let count = recv(socket, &buffer, buffer.count, 0)
        guard count > 0 else {
            throw HTTPServerError.readFailed(errno)
        }
        return Data(buffer.prefix(count))
    }

    private func parseRequest(_ data: Data) throws -> APIRequest {
        guard let raw = String(data: data, encoding: .utf8),
              let headerEnd = raw.range(of: "\r\n\r\n") else {
            throw HTTPServerError.invalidRequest
        }

        let headerText = String(raw[..<headerEnd.lowerBound])
        let bodyStart = headerEnd.upperBound
        let body = Data(raw[bodyStart...].utf8)
        let lines = headerText.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            throw HTTPServerError.invalidRequest
        }

        let parts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count >= 2, let method = HTTPMethod(rawValue: parts[0]) else {
            throw HTTPServerError.invalidRequest
        }

        var components = URLComponents()
        components.path = parts[1].split(separator: "?", maxSplits: 1).first.map(String.init) ?? parts[1]
        if let query = parts[1].split(separator: "?", maxSplits: 1).dropFirst().first {
            components.query = String(query)
        }

        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        return APIRequest(
            method: method,
            path: components.path,
            query: query,
            body: body.isEmpty ? nil : body
        )
    }

    private func write(_ response: APIResponse, to socket: Int32) throws {
        let reason = HTTPReason.phrase(for: response.status)
        let headers = [
            "HTTP/1.1 \(response.status) \(reason)",
            "Content-Type: application/json; charset=utf-8",
            "Content-Length: \(response.body.count)",
            "Connection: close",
            "Access-Control-Allow-Origin: *",
            "Access-Control-Allow-Headers: content-type, authorization",
            "Access-Control-Allow-Methods: GET, POST, OPTIONS",
            "",
            ""
        ].joined(separator: "\r\n")
        var output = Data(headers.utf8)
        output.append(response.body)
        try output.withUnsafeBytes { pointer in
            guard let base = pointer.baseAddress else { return }
            var totalSent = 0
            while totalSent < output.count {
                let sent = send(socket, base.advanced(by: totalSent), output.count - totalSent, 0)
                guard sent > 0 else {
                    throw HTTPServerError.writeFailed(errno)
                }
                totalSent += sent
            }
        }
    }
}

public enum HTTPServerError: Error, Equatable {
    case socketCreateFailed(Int32)
    case bindFailed(Int32)
    case listenFailed(Int32)
    case readFailed(Int32)
    case writeFailed(Int32)
    case invalidRequest
}

private enum HTTPReason {
    static func phrase(for status: Int) -> String {
        switch status {
        case 200: "OK"
        case 201: "Created"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 404: "Not Found"
        default: "OK"
        }
    }
}
