import Foundation

final class ProjectStore: ObservableObject {
    @Published private(set) var projects: [Project]

    private let userDefaults: UserDefaults
    private let storageKey: String

    init(userDefaults: UserDefaults = .standard, storageKey: String = "projects") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey

        if let data = userDefaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([Project].self, from: data) {
            projects = decoded
        } else {
            projects = []
        }
    }

    @discardableResult
    func addProject(name: String) -> Project {
        let project = Project(name: name)
        projects.append(project)
        persist()
        return project
    }

    func removeProject(id: UUID) {
        let priorCount = projects.count
        projects.removeAll { $0.id == id }

        guard projects.count != priorCount else {
            return
        }

        persist()
    }

    func renameProject(id: UUID, newName: String) {
        guard let index = projects.firstIndex(where: { $0.id == id }) else {
            return
        }

        projects[index].name = newName
        persist()
    }

    func addDirectory(to projectID: UUID, path: String) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else {
            return
        }

        let normalizedPath = path.hasSuffix("/") ? String(path.dropLast()) : path

        // Don't add if already covered by an existing parent directory
        if projects[index].directoryPaths.contains(where: { parent in
            normalizedPath.hasPrefix(parent + "/") || normalizedPath == parent
        }) {
            return
        }

        // Remove any existing subdirectories that the new path covers
        projects[index].directoryPaths.removeAll { existing in
            existing.hasPrefix(normalizedPath + "/")
        }

        projects[index].directoryPaths.append(normalizedPath)
        persist()
    }

    func removeDirectory(from projectID: UUID, path: String) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else {
            return
        }

        let priorCount = projects[index].directoryPaths.count
        projects[index].directoryPaths.removeAll { $0 == path }

        guard projects[index].directoryPaths.count != priorCount else {
            return
        }

        persist()
    }

    func excludeDirectory(from projectID: UUID, path: String) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else {
            return
        }

        guard !projects[index].excludedPaths.contains(path) else {
            return
        }

        projects[index].excludedPaths.append(path)
        persist()
    }

    func includeDirectory(in projectID: UUID, path: String) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else {
            return
        }

        let priorCount = projects[index].excludedPaths.count
        projects[index].excludedPaths.removeAll { $0 == path }

        guard projects[index].excludedPaths.count != priorCount else {
            return
        }

        persist()
    }

    func setEnabledFileTypes(for projectID: UUID, types: [String]?) {
        guard let index = projects.firstIndex(where: { $0.id == projectID }) else {
            return
        }

        projects[index].enabledFileTypes = types
        persist()
    }

    func moveProject(from source: IndexSet, to destination: Int) {
        projects.move(fromOffsets: source, toOffset: destination)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(projects) else {
            return
        }

        userDefaults.set(data, forKey: storageKey)
    }
}
