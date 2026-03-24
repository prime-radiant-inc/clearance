import Foundation

enum RemoteDocumentFetcherError: Error {
    case invalidUTF8Response
    case unsupportedContentType(String?)
}

extension RemoteDocumentFetcherError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidUTF8Response:
            return "The remote document was not valid UTF-8."
        case .unsupportedContentType(let mimeType):
            if let mimeType {
                return "The remote document returned an unsupported content type: \(mimeType)."
            }

            return "The remote document did not declare a supported text or markdown content type."
        }
    }
}

enum RemoteDocumentFetcher {
    private static let supportedApplicationMimeTypes: Set<String> = [
        "application/markdown",
        "application/x-markdown"
    ]

    static func resolveForMarkdownRequest(_ requestedURL: URL) -> RemoteDocument {
        RemoteDocument(
            requestedURL: requestedURL,
            renderURL: resolveRenderURL(for: requestedURL)
        )
    }

    static func fetch(_ requestedURL: URL, session: URLSession = .shared) async throws -> RemoteDocument {
        let resolved = resolveForMarkdownRequest(requestedURL)
        let (data, response) = try await session.data(from: resolved.renderURL)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if !(200..<300).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        let contentType = headerContentType(for: httpResponse)
        guard isSupportedContentType(contentType) else {
            throw RemoteDocumentFetcherError.unsupportedContentType(contentType)
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw RemoteDocumentFetcherError.invalidUTF8Response
        }

        return RemoteDocument(
            requestedURL: resolved.requestedURL,
            renderURL: resolved.renderURL,
            content: content
        )
    }

    private static func resolveRenderURL(for requestedURL: URL) -> URL {
        guard requestedURL.pathExtension.isEmpty else {
            return requestedURL
        }

        return requestedURL.appendingPathComponent("INDEX.md")
    }

    private static func isSupportedContentType(_ mimeType: String?) -> Bool {
        guard let mimeType else {
            return false
        }

        let normalizedMimeType = mimeType.lowercased()
        if normalizedMimeType == "text/html" {
            return false
        }

        if normalizedMimeType.hasPrefix("text/") {
            return true
        }

        return supportedApplicationMimeTypes.contains(normalizedMimeType)
    }

    private static func headerContentType(for response: HTTPURLResponse) -> String? {
        guard let rawValue = response.value(forHTTPHeaderField: "Content-Type") else {
            return nil
        }

        let type = rawValue.split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true).first
        return type.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    }
}
