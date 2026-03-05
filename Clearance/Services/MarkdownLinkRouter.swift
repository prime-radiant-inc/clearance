import Foundation

enum MarkdownLinkOpenAction: Equatable {
    case allowWebView
    case openInApp(URL)
    case openExternal(URL)
}

enum MarkdownLinkRouter {
    static func action(for requestedURL: URL?, sourceDocumentURL: URL?) -> MarkdownLinkOpenAction {
        guard let requestedURL else {
            return .allowWebView
        }

        guard let scheme = requestedURL.scheme?.lowercased() else {
            return .allowWebView
        }

        switch scheme {
        case "about", "data":
            return .allowWebView
        case "file":
            if isSameDocumentAnchor(requestedURL: requestedURL, sourceDocumentURL: sourceDocumentURL) {
                return .allowWebView
            }

            let normalizedURL = stripFragment(from: requestedURL).standardizedFileURL
            if shouldOpenInApp(normalizedURL) {
                return .openInApp(normalizedURL)
            }

            return .openExternal(normalizedURL)
        case "http", "https":
            if let source = sourceDocumentURL, !source.isFileURL {
                if isSameDocumentAnchor(requestedURL: requestedURL, sourceDocumentURL: sourceDocumentURL) {
                    return .allowWebView
                }
                let normalized = stripFragment(from: requestedURL)
                if shouldOpenInApp(normalized) {
                    return .openInApp(normalized)
                }
                if isDirectoryLikeURL(normalized) {
                    return .openInApp(normalized)
                }
            }
            return .openExternal(requestedURL)
        case "javascript":
            return .allowWebView
        default:
            return .openExternal(requestedURL)
        }
    }

    private static func shouldOpenInApp(_ url: URL) -> Bool {
        let `extension` = url.pathExtension.lowercased()
        return ["md", "markdown", "txt"].contains(`extension`)
    }

    private static func isDirectoryLikeURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return ext.isEmpty || url.path.hasSuffix("/")
    }

    private static func isSameDocumentAnchor(requestedURL: URL, sourceDocumentURL: URL?) -> Bool {
        guard requestedURL.fragment != nil,
              let sourceDocumentURL else {
            return false
        }

        let reqBase = stripFragment(from: requestedURL)
        let srcBase = stripFragment(from: sourceDocumentURL)
        if requestedURL.isFileURL && sourceDocumentURL.isFileURL {
            return reqBase.standardizedFileURL.path == srcBase.standardizedFileURL.path
        }
        return reqBase.absoluteString == srcBase.absoluteString
    }

    private static func stripFragment(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        components.fragment = nil
        return components.url ?? url
    }
}
