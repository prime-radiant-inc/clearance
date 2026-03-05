import Foundation

struct RemoteDocumentFetcher: Sendable {
    var fetch: @Sendable (URL) async throws -> String

    static let live = RemoteDocumentFetcher { url in
        let resolved = RemoteDocumentFetcher.resolveIndexIfNeeded(url)
        let (data, response) = try await URLSession.shared.data(from: resolved)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw RemoteDocumentError.httpError(
                statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0
            )
        }
        guard let text = String(data: data, encoding: .utf8) else {
            throw RemoteDocumentError.invalidEncoding
        }
        return text
    }

    static func resolveIndexIfNeeded(_ url: URL) -> URL {
        let ext = url.pathExtension.lowercased()
        if ["md", "markdown", "txt"].contains(ext) { return url }
        var resolved = url
        if !resolved.path.hasSuffix("/") {
            resolved = resolved.appendingPathComponent("")
        }
        return resolved.appendingPathComponent("INDEX.md")
    }
}

enum RemoteDocumentError: LocalizedError {
    case httpError(statusCode: Int)
    case invalidEncoding

    var errorDescription: String? {
        switch self {
        case .httpError(let statusCode):
            return "Server returned HTTP \(statusCode)"
        case .invalidEncoding:
            return "Response is not valid UTF-8 text"
        }
    }
}
