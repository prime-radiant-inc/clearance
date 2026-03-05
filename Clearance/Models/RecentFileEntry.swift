import Foundation

struct RecentFileEntry: Codable, Equatable, Identifiable {
    let path: String
    let lastOpenedAt: Date

    var id: String { path }

    var isRemote: Bool { path.hasPrefix("http://") || path.hasPrefix("https://") }

    var displayName: String {
        if isRemote {
            return URL(string: path)?.lastPathComponent ?? path
        }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    var directoryPath: String {
        if isRemote {
            guard let url = URL(string: path) else { return path }
            let host = url.host ?? ""
            let parentPath = url.deletingLastPathComponent().path
            return parentPath == "/" ? host : "\(host)\(parentPath)"
        }
        return fileURL.deletingLastPathComponent().path
    }

    var fileURL: URL {
        if isRemote {
            return URL(string: path) ?? URL(fileURLWithPath: path)
        }
        return URL(fileURLWithPath: path)
    }

    init(path: String, lastOpenedAt: Date = .now) {
        self.path = path
        self.lastOpenedAt = lastOpenedAt
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
