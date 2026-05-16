//
//  LocalSiteServer.swift
//  GuideGuide
//
//  Created by Friedrich Pittelkow on 16.05.26.
//

import Foundation

final class LocalSiteServer {
    private static let preferredPort: UInt16 = 52_413

    private let queue = DispatchQueue(label: "GuideGuide.LocalSiteServer", qos: .userInitiated)
    private let clientQueue = DispatchQueue(label: "GuideGuide.LocalSiteServer.Clients", qos: .userInitiated, attributes: .concurrent)
    private var serverSocket: CInt = -1
    private var resourcesURLs: [URL] = []
    private var sites: [SiteFolder] = []
    private var isRunning = false

    func start(resourcesURLs: [URL]) throws -> URL {
        stop()

        self.resourcesURLs = resourcesURLs
        self.sites = SiteScanner.scan(resourcesURLs: resourcesURLs)

        let socketDescriptor = try makeBoundSocket(preferredPort: Self.preferredPort)

        guard listen(socketDescriptor, SOMAXCONN) == 0 else {
            close(socketDescriptor)
            throw ServerError.listenFailed(errno)
        }

        var boundAddress = sockaddr_in()
        var boundAddressLength = socklen_t(MemoryLayout<sockaddr_in>.size)
        let portResult = withUnsafeMutablePointer(to: &boundAddress) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                getsockname(socketDescriptor, socketAddress, &boundAddressLength)
            }
        }

        guard portResult == 0 else {
            close(socketDescriptor)
            throw ServerError.portLookupFailed(errno)
        }

        serverSocket = socketDescriptor
        isRunning = true
        acceptConnections(on: socketDescriptor)

        let port = UInt16(bigEndian: boundAddress.sin_port)
        return URL(string: "http://127.0.0.1:\(port)/")!
    }

    private func makeBoundSocket(preferredPort: UInt16) throws -> CInt {
        if let socketDescriptor = try? makeSocket(port: preferredPort) {
            return socketDescriptor
        }

        return try makeSocket(port: 0)
    }

    private func makeSocket(port: UInt16) throws -> CInt {
        let socketDescriptor = socket(AF_INET, SOCK_STREAM, 0)
        guard socketDescriptor >= 0 else {
            throw ServerError.socketCreationFailed(errno)
        }

        var reuseAddress: CInt = 1
        setsockopt(socketDescriptor, SOL_SOCKET, SO_REUSEADDR, &reuseAddress, socklen_t(MemoryLayout<CInt>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = in_port_t(port).bigEndian
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                bind(socketDescriptor, socketAddress, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard bindResult == 0 else {
            let bindError = errno
            close(socketDescriptor)
            throw ServerError.bindFailed(bindError)
        }

        return socketDescriptor
    }

    func stop() {
        isRunning = false
        if serverSocket >= 0 {
            shutdown(serverSocket, SHUT_RDWR)
            close(serverSocket)
            serverSocket = -1
        }
        resourcesURLs = []
        sites = []
    }

    private func acceptConnections(on socketDescriptor: CInt) {
        queue.async { [weak self] in
            guard let self else { return }

            while self.isRunning {
                let clientSocket = accept(socketDescriptor, nil, nil)
                guard clientSocket >= 0 else {
                    if self.isRunning {
                        continue
                    }
                    break
                }

                self.clientQueue.async { [weak self] in
                    self?.handle(clientSocket: clientSocket)
                }
            }
        }
    }

    private func handle(clientSocket: CInt) {
        defer { close(clientSocket) }

        var requestData = Data()
        var buffer = [UInt8](repeating: 0, count: 16_384)

        while true {
            let bytesRead = recv(clientSocket, &buffer, buffer.count, 0)
            guard bytesRead > 0 else { break }

            requestData.append(buffer, count: bytesRead)
            if requestData.containsHeaderTerminator {
                break
            }

            if requestData.count > 1_048_576 {
                break
            }
        }

        let response = response(for: HTTPRequest(data: requestData))
        response.data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return }
            var sent = 0
            while sent < response.data.count {
                let result = send(clientSocket, baseAddress.advanced(by: sent), response.data.count - sent, 0)
                guard result > 0 else { break }
                sent += result
            }
        }
    }

    private func response(for request: HTTPRequest?) -> HTTPResponse {
        guard !resourcesURLs.isEmpty else { return .notFound() }
        guard let request, request.method == "GET" || request.method == "HEAD" else {
            return .methodNotAllowed()
        }

        if request.path == "/" {
            return .html(hubHTML(), includeBody: request.method != "HEAD")
        }

        guard let fileURL = fileURL(for: request.path) else {
            return .notFound("""
            GuideGuide route resolver v2
            No local file matched \(request.path).
            Known routes: \(sites.map { $0.routeComponent }.sorted().joined(separator: ", "))
            Active site count: \(sites.count)
            """)
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return .ok(data: request.method == "HEAD" ? Data() : data, mimeType: MimeType.forPathExtension(fileURL.pathExtension))
        } catch {
            return .notFound("Could not read \(fileURL.path(percentEncoded: false)): \(error.localizedDescription)")
        }
    }

    private func fileURL(for requestPath: String) -> URL? {
        let components = pathComponents(from: requestPath)
        guard let siteName = components.first else { return nil }
        let selectedSite: SiteFolder
        if sites.count == 1 {
            selectedSite = sites[0]
        } else if let resolvedSite = site(forRouteComponent: siteName) {
            selectedSite = resolvedSite
        } else {
            return nil
        }

        let siteURL = selectedSite.folderURL.standardizedFileURL

        let relativeComponents = Array(components.dropFirst())
        let requestedURL: URL
        if relativeComponents.isEmpty {
            requestedURL = siteURL.appendingPathComponent(selectedSite.entryFileName, isDirectory: false)
        } else {
            requestedURL = relativeComponents.reduce(siteURL) { partialURL, component in
                partialURL.appendingPathComponent(component)
            }
        }

        let standardizedSitePath = siteURL.pathWithoutTrailingSlashes
        let standardizedRequestedPath = requestedURL.standardizedFileURL.pathWithoutTrailingSlashes
        guard standardizedRequestedPath == standardizedSitePath || standardizedRequestedPath.hasPrefix(standardizedSitePath + "/") else {
            return nil
        }

        return requestedURL
    }

    private func site(forRouteComponent routeComponent: String) -> SiteFolder? {
        let normalizedRoute = routeComponent.normalizedRouteComponent
        if let exactMatch = sites.first(where: { site in
            site.routeComponent.normalizedRouteComponent == normalizedRoute
        }) {
            return exactMatch
        }

        if sites.count == 1 {
            return sites[0]
        }

        return nil
    }

    private func pathComponents(from requestPath: String) -> [String] {
        requestPath
            .split(separator: "/")
            .compactMap { component in
                String(component).removingPercentEncoding
            }
            .filter { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    private func hubHTML() -> String {
        let links = sites.map { site in
            """
            <li><a href="/\(site.routeComponent.urlPathEncoded)/">\(site.displayName.htmlEscaped)</a></li>
            """
        }
        .joined(separator: "\n")

        return """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>GuideGuide</title>
          <style>
            :root { color-scheme: light dark; font-family: -apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif; }
            body { margin: 0; padding: 42px; background: Canvas; color: CanvasText; }
            h1 { font-size: 28px; margin: 0 0 24px; }
            ul { display: grid; gap: 10px; list-style: none; margin: 0; padding: 0; max-width: 680px; }
            a { display: block; padding: 14px 16px; border: 1px solid color-mix(in srgb, CanvasText 16%, transparent); border-radius: 10px; color: LinkText; text-decoration: none; }
            a:hover { background: color-mix(in srgb, CanvasText 6%, transparent); }
          </style>
        </head>
        <body>
          <h1>GuideGuide</h1>
          <ul>
            \(links)
          </ul>
        </body>
        </html>
        """
    }
}

private enum ServerError: LocalizedError {
    case socketCreationFailed(Int32)
    case bindFailed(Int32)
    case listenFailed(Int32)
    case portLookupFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .socketCreationFailed(let code):
            "Could not create local server socket: \(String(cString: strerror(code)))"
        case .bindFailed(let code):
            "Could not bind local server to 127.0.0.1: \(String(cString: strerror(code)))"
        case .listenFailed(let code):
            "Could not listen on local server socket: \(String(cString: strerror(code)))"
        case .portLookupFailed(let code):
            "Could not read local server port: \(String(cString: strerror(code)))"
        }
    }
}

private struct HTTPRequest {
    let method: String
    let path: String

    init?(data: Data) {
        guard let string = String(data: data, encoding: .utf8),
              let requestLine = string.components(separatedBy: "\r\n").first else {
            return nil
        }

        let parts = requestLine.split(separator: " ", maxSplits: 2).map(String.init)
        guard parts.count >= 2 else { return nil }

        method = parts[0]
        path = URLComponents(string: parts[1])?.percentEncodedPath ?? parts[1]
    }
}

private struct HTTPResponse {
    let data: Data

    static func ok(data body: Data, mimeType: String) -> HTTPResponse {
        response(status: "200 OK", headers: [
            "Content-Type": mimeType,
            "Content-Length": "\(body.count)",
            "Cache-Control": "no-cache"
        ], body: body)
    }

    static func html(_ html: String, includeBody: Bool = true) -> HTTPResponse {
        let body = includeBody ? Data(html.utf8) : Data()
        return response(status: "200 OK", headers: [
            "Content-Type": "text/html; charset=utf-8",
            "Content-Length": "\(body.count)",
            "Cache-Control": "no-cache"
        ], body: body)
    }

    static func redirect(to location: String) -> HTTPResponse {
        response(status: "308 Permanent Redirect", headers: [
            "Location": location,
            "Content-Length": "0"
        ], body: Data())
    }

    static func notFound(_ message: String = "Not Found") -> HTTPResponse {
        let body = Data(message.utf8)
        return response(status: "404 Not Found", headers: [
            "Content-Type": "text/plain; charset=utf-8",
            "Content-Length": "\(body.count)"
        ], body: body)
    }

    static func methodNotAllowed() -> HTTPResponse {
        let body = Data("Method Not Allowed".utf8)
        return response(status: "405 Method Not Allowed", headers: [
            "Allow": "GET, HEAD",
            "Content-Type": "text/plain; charset=utf-8",
            "Content-Length": "\(body.count)"
        ], body: body)
    }

    private static func response(status: String, headers: [String: String], body: Data) -> HTTPResponse {
        var lines = ["HTTP/1.1 \(status)", "Connection: close"]
        lines.append(contentsOf: headers.map { "\($0.key): \($0.value)" })
        lines.append("")
        lines.append("")

        var data = Data(lines.joined(separator: "\r\n").utf8)
        data.append(body)
        return HTTPResponse(data: data)
    }
}

private enum MimeType {
    static func forPathExtension(_ pathExtension: String) -> String {
        switch pathExtension.lowercased() {
        case "html", "htm": "text/html; charset=utf-8"
        case "css": "text/css; charset=utf-8"
        case "js", "mjs": "text/javascript; charset=utf-8"
        case "json": "application/json; charset=utf-8"
        case "png": "image/png"
        case "jpg", "jpeg": "image/jpeg"
        case "gif": "image/gif"
        case "svg": "image/svg+xml"
        case "ico": "image/x-icon"
        case "pdf": "application/pdf"
        case "woff": "font/woff"
        case "woff2": "font/woff2"
        case "ttf": "font/ttf"
        case "otf": "font/otf"
        default: "application/octet-stream"
        }
    }
}

private extension Data {
    var containsHeaderTerminator: Bool {
        range(of: Data("\r\n\r\n".utf8)) != nil
    }
}

extension String {
    var urlPathEncoded: String {
        addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? self
    }

    var htmlEscaped: String {
        replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    var normalizedRouteComponent: String {
        trimmingCharacters(in: CharacterSet(charactersIn: "/").union(.whitespacesAndNewlines))
            .precomposedStringWithCanonicalMapping
            .lowercased()
    }
}

private extension URL {
    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    var pathWithoutTrailingSlashes: String {
        var path = path(percentEncoded: false)
        while path.count > 1 && path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }
}
