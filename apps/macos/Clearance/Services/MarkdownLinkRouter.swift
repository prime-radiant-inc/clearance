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
            if isSameDocumentAnchor(requestedURL: requestedURL, sourceDocumentURL: sourceDocumentURL) {
                return .allowWebView
            }

            let normalizedURL = stripFragment(from: requestedURL).standardized
            if sourceDocumentIsRemote(sourceDocumentURL),
               shouldOpenRemoteURLInApp(normalizedURL) {
                return .openInApp(normalizedURL)
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

    private static func isSameDocumentAnchor(requestedURL: URL, sourceDocumentURL: URL?) -> Bool {
        guard requestedURL.fragment != nil,
              let sourceDocumentURL else {
            return false
        }

        let requestedWithoutFragment = stripFragment(from: requestedURL)
        let sourceWithoutFragment = stripFragment(from: sourceDocumentURL)

        if requestedWithoutFragment.isFileURL || sourceWithoutFragment.isFileURL {
            guard requestedWithoutFragment.isFileURL,
                  sourceWithoutFragment.isFileURL else {
                return false
            }

            return requestedWithoutFragment.standardizedFileURL.path == sourceWithoutFragment.standardizedFileURL.path
        }

        return requestedWithoutFragment.standardized.absoluteString == sourceWithoutFragment.standardized.absoluteString
    }

    private static func sourceDocumentIsRemote(_ url: URL?) -> Bool {
        guard let scheme = url?.scheme?.lowercased() else {
            return false
        }

        return scheme == "http" || scheme == "https"
    }

    private static func shouldOpenRemoteURLInApp(_ url: URL) -> Bool {
        if shouldOpenInApp(url) {
            return true
        }

        return url.pathExtension.isEmpty
    }

    private static func stripFragment(from url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }

        components.fragment = nil
        return components.url ?? url
    }
}
