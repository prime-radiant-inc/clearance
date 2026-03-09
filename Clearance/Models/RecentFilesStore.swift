import Foundation

final class RecentFilesStore: ObservableObject {
    @Published private(set) var entries: [RecentFileEntry]

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let maxEntries: Int

    init(userDefaults: UserDefaults = .standard, storageKey: String = "recentFiles", maxEntries: Int = 10_000) {
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
        let existingOverride = entries.first(where: { $0.path == storageKey })?.displayNameOverride
        entries.removeAll { $0.path == storageKey }
        entries.insert(
            RecentFileEntry(path: storageKey, lastOpenedAt: .now, displayNameOverride: existingOverride),
            at: 0
        )

        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }

        persist()
    }

    func addAll(urls: [URL], displayNameOverride: ((URL) -> String?)? = nil) {
        let now = Date.now
        var newEntries: [RecentFileEntry] = []
        
        // Create entries for all URLs
        for url in urls {
            let storageKey = RecentFileEntry.storageKey(for: url)
            let override = displayNameOverride?(url)
            let entry = RecentFileEntry(
                path: storageKey,
                lastOpenedAt: now,
                displayNameOverride: override
            )
            newEntries.append(entry)
        }
        
        // Deduplicate: remove existing entries with same paths
        let newPaths = Set(newEntries.map { $0.path })
        entries.removeAll { newPaths.contains($0.path) }
        
        // Insert new entries at the top
        entries.insert(contentsOf: newEntries, at: 0)
        
        // Respect maxEntries limit
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
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

    func removeAll(paths: [String]) {
        let pathSet = Set(paths)
        let priorCount = entries.count
        entries.removeAll { pathSet.contains($0.path) }

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
