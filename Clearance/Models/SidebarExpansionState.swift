import Foundation

@MainActor
final class SidebarExpansionState: ObservableObject {
    @Published private(set) var expandedPaths: Set<String>

    private let userDefaults: UserDefaults
    private let storageKey: String
    private var knownPaths: Set<String>

    init(userDefaults: UserDefaults = .standard, storageKey: String = "sidebarExpandedPaths") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey

        if let stored = userDefaults.stringArray(forKey: storageKey) {
            expandedPaths = Set(stored)
        } else {
            expandedPaths = []
        }

        let knownKey = storageKey + ".known"
        knownPaths = Set(userDefaults.stringArray(forKey: knownKey) ?? [])
    }

    func isExpanded(_ path: String) -> Bool {
        expandedPaths.contains(path)
    }

    func setExpanded(_ path: String, expanded: Bool) {
        if expanded {
            expandedPaths.insert(path)
        } else {
            expandedPaths.remove(path)
        }

        persist()
    }

    func toggle(_ path: String) {
        if expandedPaths.contains(path) {
            expandedPaths.remove(path)
        } else {
            expandedPaths.insert(path)
        }

        persist()
    }

    private var pendingExpansions: Set<String> = []
    private var flushScheduled = false

    func expandIfUnknown(_ path: String) {
        guard !expandedPaths.contains(path), !knownPaths.contains(path) else {
            return
        }

        pendingExpansions.insert(path)

        guard !flushScheduled else {
            return
        }

        flushScheduled = true
        DispatchQueue.main.async { [weak self] in
            self?.flushPendingExpansions()
        }
    }

    private func flushPendingExpansions() {
        flushScheduled = false

        guard !pendingExpansions.isEmpty else {
            return
        }

        let toExpand = pendingExpansions
        pendingExpansions.removeAll()

        knownPaths.formUnion(toExpand)
        userDefaults.set(Array(knownPaths), forKey: storageKey + ".known")

        expandedPaths.formUnion(toExpand)
        persist()
    }

    private func persist() {
        userDefaults.set(Array(expandedPaths), forKey: storageKey)
    }
}
