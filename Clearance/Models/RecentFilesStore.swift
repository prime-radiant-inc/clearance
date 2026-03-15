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
        let storageKey = RecentFileEntry.storageKey(for: url)
        entries.removeAll { $0.path == storageKey }
        entries.insert(RecentFileEntry(path: storageKey, lastOpenedAt: .now), at: 0)

        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        persist()
    }

    func add(urls: [URL]) {
        guard !urls.isEmpty else {
            return
        }

        let now = Date.now
        let storageKeys = urls.map(RecentFileEntry.storageKey(for:))
        let newPaths = Set(storageKeys)
        entries.removeAll { newPaths.contains($0.path) }
        entries.insert(
            contentsOf: storageKeys.map { RecentFileEntry(path: $0, lastOpenedAt: now) },
            at: 0
        )

        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        persist()
    }

    func removeMissingLocalFiles() {
        let priorCount = entries.count
        entries.removeAll { entry in
            entry.fileURL.isFileURL && !FileManager.default.fileExists(atPath: entry.fileURL.path)
        }

        guard entries.count != priorCount else {
            return
        }

        persist()
    }

    func remove(path: String) {
        let priorCount = entries.count
        entries.removeAll { $0.path == path }

        guard entries.count != priorCount else {
            return
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
