import Foundation

enum AddressBarInputParser {
    static func parse(_ input: String) -> URL? {
        if let url = URL(string: input),
           let scheme = url.scheme?.lowercased(),
           !scheme.isEmpty {
            switch scheme {
            case "file", "http", "https":
                return url
            default:
                return nil
            }
        }

        let expandedInput = (input as NSString).expandingTildeInPath
        return URL(fileURLWithPath: expandedInput)
    }
}

enum AddressBarFormatter {
    static func displayText(for url: URL?) -> String {
        guard let url else {
            return ""
        }

        if url.isFileURL {
            let filename = url.lastPathComponent
            return filename.isEmpty ? url.path : filename
        }

        let collapsedURL = collapsedDirectoryURLIfNeeded(url)
        return simplifiedRemoteText(for: collapsedURL)
    }

    static func editingText(for url: URL?) -> String {
        guard let url else {
            return ""
        }

        if url.isFileURL {
            return url.path
        }

        return url.absoluteString
    }

    private static func collapsedDirectoryURLIfNeeded(_ url: URL) -> URL {
        let lastPathComponent = url.lastPathComponent.lowercased()
        guard lastPathComponent == "index.md" || lastPathComponent == "readme.md" else {
            return url
        }

        return url.deletingLastPathComponent()
    }

    private static func simplifiedRemoteText(for url: URL) -> String {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return stripScheme(from: url.absoluteString)
        }

        components.scheme = nil
        let text = components.string ?? stripScheme(from: url.absoluteString)
        let withoutSchemePrefix: String
        if text.hasPrefix("//") {
            withoutSchemePrefix = String(text.dropFirst(2))
        } else {
            withoutSchemePrefix = text
        }

        if components.query == nil,
           components.fragment == nil,
           components.path.hasSuffix("/"),
           components.path.count > 1,
           withoutSchemePrefix.hasSuffix("/") {
            return String(withoutSchemePrefix.dropLast())
        }

        return withoutSchemePrefix
    }

    private static func stripScheme(from text: String) -> String {
        guard let schemeRange = text.range(of: "://") else {
            return text
        }

        return String(text[schemeRange.upperBound...])
    }
}
