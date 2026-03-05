import Foundation

final class RecentFilesStore: ObservableObject {
    @Published private(set) var entries: [RecentFileEntry]

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let maxEntries: Int

    init(userDefaults: UserDefaults = .standard, storageKey: String = "recentFiles", maxEntries: Int = 200) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.maxEntries = maxEntries

        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([RecentFileEntry].self, from: data) {
            entries = decoded
        } else {
            entries = []
        }
    }

    func add(url: URL) {
        let key = url.isFileURL ? url.standardizedFileURL.path : url.absoluteString
        entries.removeAll { $0.path == key }
        entries.insert(RecentFileEntry(path: key, lastOpenedAt: .now), at: 0)

        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else {
            return
        }

        userDefaults.set(data, forKey: storageKey)
    }
}
