import Foundation

struct RecentFileEntry: Codable, Equatable, Identifiable {
    let path: String
    let lastOpenedAt: Date

    var id: String { path }

    var displayName: String {
        let component = fileURL.lastPathComponent
        if !component.isEmpty, component != "/" {
            return component
        }

        if !fileURL.isFileURL,
           let host = fileURL.host,
           !host.isEmpty {
            return host
        }

        return path
    }

    var directoryPath: String {
        if fileURL.isFileURL {
            return fileURL.deletingLastPathComponent().path
        }

        let directoryURL: URL
        if fileURL.pathExtension.isEmpty {
            directoryURL = fileURL
        } else {
            directoryURL = fileURL.deletingLastPathComponent()
        }

        if let components = URLComponents(url: directoryURL, resolvingAgainstBaseURL: false),
           let host = components.host {
            let remotePath = components.path.isEmpty ? "/" : components.path
            return "\(host)\(remotePath)"
        }

        return directoryURL.absoluteString
    }

    var fileURL: URL {
        if let parsedURL = URL(string: path),
           parsedURL.scheme != nil {
            return parsedURL
        }

        return URL(fileURLWithPath: path)
    }

    var isAvailable: Bool {
        guard fileURL.isFileURL else {
            return true
        }

        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    init(path: String, lastOpenedAt: Date = .now) {
        self.path = path
        self.lastOpenedAt = lastOpenedAt
    }

    init(url: URL, lastOpenedAt: Date = .now) {
        self.path = Self.storageKey(for: url)
        self.lastOpenedAt = lastOpenedAt
    }

    static func storageKey(for url: URL) -> String {
        if url.isFileURL {
            return url.standardizedFileURL.path
        }

        return url.absoluteString
    }

    enum CodingKeys: String, CodingKey {
        case path
        case lastOpenedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        path = try container.decode(String.self, forKey: .path)
        lastOpenedAt = try container.decodeIfPresent(Date.self, forKey: .lastOpenedAt) ?? .distantPast
    }
}
