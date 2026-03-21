import Combine
import Foundation

struct PendingFolderImport {
    let urls: [URL]
}

@MainActor
final class WorkspaceViewModel: NSObject, ObservableObject {
    @Published var activeSession: DocumentSession? {
        didSet {
            bindActiveSession()
        }
    }
    @Published private(set) var activeRemoteDocument: RemoteDocument?
    @Published private(set) var isLoadingRemoteDocument = false
    @Published var errorMessage: String?
    @Published var mode: WorkspaceMode
    @Published var selectedRecentPath: String?
    @Published private(set) var windowTitle: String
    @Published private(set) var externalChangeDocumentName: String?
    @Published private(set) var canNavigateBack = false
    @Published private(set) var canNavigateForward = false
    @Published private(set) var pendingFolderImport: PendingFolderImport?
    @Published var selectedProjectFilePath: String?
    @Published private(set) var projects: [Project] = []
    @Published private(set) var directoryTrees: [String: ProjectFileNode] = [:]
    @Published private(set) var expandedPaths: Set<String> = []

    let recentFilesStore: RecentFilesStore
    let projectStore: ProjectStore
    let directoryMonitor: DirectoryMonitor
    let sidebarExpansionState: SidebarExpansionState
    var hasActiveDocument: Bool {
        activeSession != nil || activeRemoteDocument != nil
    }

    var isActiveDocumentRemote: Bool {
        activeRemoteDocument != nil
    }

    var activeDocumentURL: URL? {
        activeRemoteDocument?.requestedURL ?? activeSession?.url
    }

    var activeRenderURL: URL? {
        activeRemoteDocument?.renderURL ?? activeSession?.url
    }

    private let openPanelService: OpenPanelServicing
    private let appSettings: AppSettings
    private let remoteDocumentLoader: @Sendable (URL) async throws -> RemoteDocument
    private var activeSessionCancellables: Set<AnyCancellable> = []
    private var externalChangeTimer: Timer?
    private weak var monitoredSession: DocumentSession?
    private var remoteLoadTask: Task<Void, Never>?
    private var remoteLoadGeneration = 0
    private var navigationHistory: [URL] = []
    private var navigationHistoryIndex = -1
    private let folderImportConfirmationThreshold = 10
    private var projectsCancellable: AnyCancellable?
    private var projectsMirrorCancellable: AnyCancellable?
    private var treesMirrorCancellable: AnyCancellable?
    private var expansionMirrorCancellable: AnyCancellable?
    private var fileTypesCancellable: AnyCancellable?

    init(
        recentFilesStore: RecentFilesStore = RecentFilesStore(),
        projectStore: ProjectStore = ProjectStore(),
        directoryMonitor: DirectoryMonitor = DirectoryMonitor(),
        openPanelService: OpenPanelServicing = OpenPanelService(),
        appSettings: AppSettings = AppSettings(),
        remoteDocumentLoader: @escaping @Sendable (URL) async throws -> RemoteDocument = { requestedURL in
            try await RemoteDocumentFetcher.fetch(requestedURL)
        }
    ) {
        self.recentFilesStore = recentFilesStore
        self.projectStore = projectStore
        self.directoryMonitor = directoryMonitor
        self.sidebarExpansionState = SidebarExpansionState()
        self.openPanelService = openPanelService
        self.appSettings = appSettings
        self.remoteDocumentLoader = remoteDocumentLoader
        mode = appSettings.defaultOpenMode
        windowTitle = "Clearance"
        super.init()
        bindProjectStoreToMonitor()
    }

    deinit {
        remoteLoadTask?.cancel()
    }

    @discardableResult
    func promptAndOpenFile() -> DocumentSession? {
        guard let url = openPanelService.chooseMarkdownFile() else {
            return nil
        }

        return openPickedItem(url)
    }

    @discardableResult
    func promptAndCreateNewDocument() -> DocumentSession? {
        guard let url = openPanelService.chooseNewMarkdownFileLocation() else {
            return nil
        }

        return createAndOpenNewDocument(at: url)
    }

    @discardableResult
    func openPickedItem(_ url: URL) -> DocumentSession? {
        if isDirectory(url) {
            return queueOrImportFolder(at: url)
        }

        return open(url: url)
    }

    @discardableResult
    func confirmPendingFolderImport() -> DocumentSession? {
        guard let pendingFolderImport else {
            return nil
        }

        self.pendingFolderImport = nil
        return importFolderURLs(pendingFolderImport.urls)
    }

    func cancelPendingFolderImport() {
        pendingFolderImport = nil
    }

    @discardableResult
    func open(recentEntry: RecentFileEntry, recordNavigation: Bool = true) -> DocumentSession? {
        open(url: recentEntry.fileURL, recordNavigation: recordNavigation)
    }

    @discardableResult
    func open(url: URL, recordNavigation: Bool = true, resetModeToDefault: Bool = true) -> DocumentSession? {
        _ = openInternal(url: url, recordNavigation: recordNavigation, resetModeToDefault: resetModeToDefault)
        return activeSession
    }

    private func openInternal(url: URL, recordNavigation: Bool, resetModeToDefault: Bool) -> Bool {
        let normalizedURL = normalizedURL(for: url)

        if normalizedURL.isFileURL {
            return openLocal(
                url: normalizedURL,
                recordNavigation: recordNavigation,
                resetModeToDefault: resetModeToDefault
            ) != nil
        }

        openRemote(
            url: normalizedURL,
            recordNavigation: recordNavigation
        )
        return true
    }

    @discardableResult
    private func createAndOpenNewDocument(at url: URL) -> DocumentSession? {
        do {
            try NewMarkdownDocument.create(at: url)
        } catch {
            errorMessage = "Failed to create \(url.path): \(error.localizedDescription)"
            return nil
        }

        let session = open(url: url, resetModeToDefault: false)
        if session != nil {
            mode = .edit
        }
        return session
    }

    private func openLocal(url: URL, recordNavigation: Bool, resetModeToDefault: Bool) -> DocumentSession? {
        remoteLoadTask?.cancel()
        remoteLoadTask = nil
        remoteLoadGeneration += 1
        isLoadingRemoteDocument = false
        activeRemoteDocument = nil

        do {
            let session = try DocumentSession(url: url)
            activeSession = session
            recentFilesStore.add(url: url)
            selectedRecentPath = RecentFileEntry.storageKey(for: url)
            if resetModeToDefault {
                mode = appSettings.defaultOpenMode
            }
            if recordNavigation {
                pushNavigationEntry(url)
            } else {
                updateNavigationAvailability()
            }
            errorMessage = nil
            return session
        } catch {
            errorMessage = "Failed to open \(url.path): \(error.localizedDescription)"
            return nil
        }
    }

    private func openRemote(url: URL, recordNavigation: Bool) {
        remoteLoadTask?.cancel()
        remoteLoadTask = nil
        remoteLoadGeneration += 1
        let generation = remoteLoadGeneration

        activeSession = nil
        isLoadingRemoteDocument = true
        activeRemoteDocument = RemoteDocumentFetcher.resolveForMarkdownRequest(url)
        windowTitle = addressableTitle(for: url)
        recentFilesStore.add(url: url)
        selectedRecentPath = RecentFileEntry.storageKey(for: url)
        mode = .view
        if recordNavigation {
            pushNavigationEntry(url)
        } else {
            updateNavigationAvailability()
        }
        errorMessage = nil

        remoteLoadTask = Task { [weak self] in
            guard let self else {
                return
            }

            do {
                let remoteDocument = try await self.remoteDocumentLoader(url)
                guard self.remoteLoadGeneration == generation,
                      !Task.isCancelled else {
                    return
                }

                self.activeRemoteDocument = remoteDocument
                self.isLoadingRemoteDocument = false
                self.errorMessage = nil
                self.remoteLoadTask = nil
            } catch is CancellationError {
                guard self.remoteLoadGeneration == generation else {
                    return
                }

                self.isLoadingRemoteDocument = false
                self.remoteLoadTask = nil
            } catch {
                guard self.remoteLoadGeneration == generation else {
                    return
                }

                self.isLoadingRemoteDocument = false
                self.errorMessage = "Failed to open \(url.absoluteString): \(error.localizedDescription)"
                self.remoteLoadTask = nil
            }
        }
    }

    func navigateBack() -> Bool {
        guard navigationHistoryIndex > 0 else {
            return false
        }

        let targetIndex = navigationHistoryIndex - 1
        let targetURL = navigationHistory[targetIndex]
        guard openInternal(url: targetURL, recordNavigation: false, resetModeToDefault: false) else {
            return false
        }

        navigationHistoryIndex = targetIndex
        updateNavigationAvailability()
        return true
    }

    func navigateForward() -> Bool {
        let nextIndex = navigationHistoryIndex + 1
        guard nextIndex < navigationHistory.count else {
            return false
        }

        let targetURL = navigationHistory[nextIndex]
        guard openInternal(url: targetURL, recordNavigation: false, resetModeToDefault: false) else {
            return false
        }

        navigationHistoryIndex = nextIndex
        updateNavigationAvailability()
        return true
    }

    func reloadActiveFromDisk() {
        guard let session = activeSession else {
            return
        }

        reloadSessionFromDisk(session)
    }

    func keepCurrentVersionAfterExternalChange() {
        guard let session = activeSession else {
            return
        }

        session.acknowledgeExternalChangesKeepingCurrent()
        externalChangeDocumentName = nil
    }

    func checkForExternalChangesNow() {
        activeSession?.checkForExternalChanges()
    }

    func removeRecentEntry(path: String) {
        recentFilesStore.remove(path: path)
        if selectedRecentPath == path {
            selectedRecentPath = nil
        }
    }

    private func bindActiveSession() {
        activeSessionCancellables.removeAll()
        externalChangeTimer?.invalidate()
        externalChangeTimer = nil
        monitoredSession = nil
        externalChangeDocumentName = nil

        guard let session = activeSession else {
            windowTitle = "Clearance"
            return
        }

        updateWindowTitle(for: session)

        session.$isDirty
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self, self.activeSession === session else {
                    return
                }

                self.updateWindowTitle(for: session)
            }
            .store(in: &activeSessionCancellables)

        session.$hasExternalChanges
            .receive(on: RunLoop.main)
            .sink { [weak self] hasExternalChanges in
                guard let self, self.activeSession === session else {
                    return
                }

                self.handleExternalChangeState(for: session, hasExternalChanges: hasExternalChanges)
            }
            .store(in: &activeSessionCancellables)

        monitoredSession = session
        let timer = Timer(
            timeInterval: 1.0,
            target: self,
            selector: #selector(handleExternalChangeTimer),
            userInfo: nil,
            repeats: true
        )
        timer.tolerance = 0.3
        externalChangeTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func queueOrImportFolder(at folderURL: URL) -> DocumentSession? {
        let urls = Self.folderImportURLs(in: folderURL, supportedExtensions: appSettings.enabledFileTypes)
        guard !urls.isEmpty else {
            return nil
        }

        if urls.count > folderImportConfirmationThreshold {
            pendingFolderImport = PendingFolderImport(urls: urls)
            return nil
        }

        return importFolderURLs(urls)
    }

    private func importFolderURLs(_ urls: [URL]) -> DocumentSession? {
        guard let firstURL = urls.first else {
            return nil
        }

        recentFilesStore.add(urls: urls)
        return open(url: firstURL)
    }

    private func isDirectory(_ url: URL) -> Bool {
        guard url.isFileURL else {
            return false
        }

        return (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
    }

    private static func folderImportURLs(in folderURL: URL, supportedExtensions: Set<String>) -> [URL] {
        var urlsWithDates: [(url: URL, modificationDate: Date)] = []

        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .contentModificationDateKey]) else {
                continue
            }

            if values.isDirectory == true {
                continue
            }

            guard supportedExtensions.contains(url.pathExtension.lowercased()) else {
                continue
            }

            urlsWithDates.append((url, values.contentModificationDate ?? .distantPast))
        }

        return urlsWithDates
            .sorted {
                if $0.modificationDate == $1.modificationDate {
                    return $0.url.path < $1.url.path
                }

                return $0.modificationDate > $1.modificationDate
            }
            .map(\.url)
    }

    private func updateWindowTitle(for session: DocumentSession) {
        windowTitle = session.displayTitle
    }

    private func handleExternalChangeState(for session: DocumentSession, hasExternalChanges: Bool) {
        guard hasExternalChanges else {
            externalChangeDocumentName = nil
            return
        }

        guard mode == .view, !session.isDirty else {
            externalChangeDocumentName = session.url.lastPathComponent
            return
        }

        reloadSessionFromDisk(session)
    }

    private func reloadSessionFromDisk(_ session: DocumentSession) {
        do {
            try session.reloadFromDisk()
            errorMessage = nil
            externalChangeDocumentName = nil
        } catch {
            errorMessage = "Failed to reload \(session.url.path): \(error.localizedDescription)"
        }
    }

    private func pushNavigationEntry(_ url: URL) {
        if navigationHistoryIndex >= 0,
           navigationKey(for: navigationHistory[navigationHistoryIndex]) == navigationKey(for: url) {
            updateNavigationAvailability()
            return
        }

        if navigationHistoryIndex < navigationHistory.count - 1 {
            navigationHistory.removeSubrange((navigationHistoryIndex + 1)..<navigationHistory.count)
        }

        navigationHistory.append(url)
        navigationHistoryIndex = navigationHistory.count - 1
        updateNavigationAvailability()
    }

    private func updateNavigationAvailability() {
        canNavigateBack = navigationHistoryIndex > 0
        canNavigateForward = navigationHistoryIndex >= 0 && navigationHistoryIndex < navigationHistory.count - 1
    }

    private func normalizedURL(for url: URL) -> URL {
        if url.isFileURL {
            return url.standardizedFileURL
        }

        return url.standardized
    }

    private func navigationKey(for url: URL) -> String {
        RecentFileEntry.storageKey(for: normalizedURL(for: url))
    }

    private func addressableTitle(for url: URL) -> String {
        if url.isFileURL {
            return url.lastPathComponent
        }

        if !url.lastPathComponent.isEmpty {
            return url.lastPathComponent
        }

        if let host = url.host, !host.isEmpty {
            return host
        }

        return url.absoluteString
    }

    @objc private func handleExternalChangeTimer() {
        guard let session = monitoredSession,
              activeSession === session else {
            externalChangeTimer?.invalidate()
            externalChangeTimer = nil
            monitoredSession = nil
            return
        }

        session.checkForExternalChanges()
    }

    // MARK: - Projects

    private func bindProjectStoreToMonitor() {
        projects = projectStore.projects

        directoryMonitor.updateDefaultExtensions(appSettings.enabledFileTypes)
        updateExtensionOverrides(for: projectStore.projects)

        let allPaths = Set(projectStore.projects.flatMap(\.directoryPaths))
        let allExcluded = Set(projectStore.projects.flatMap(\.excludedPaths))
        directoryMonitor.updateMonitoredDirectories(allPaths, excludedPaths: allExcluded)

        fileTypesCancellable = appSettings.$enabledFileTypes
            .dropFirst()
            .sink { [weak self] types in
                self?.directoryMonitor.updateDefaultExtensions(types)
            }

        projectsCancellable = projectStore.$projects
            .sink { [weak self] projects in
                guard let self else {
                    return
                }

                let paths = Set(projects.flatMap(\.directoryPaths))
                let excluded = Set(projects.flatMap(\.excludedPaths))
                self.updateExtensionOverrides(for: projects)
                self.directoryMonitor.updateMonitoredDirectories(paths, excludedPaths: excluded)
            }

        projectsMirrorCancellable = projectStore.$projects
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.projects = $0 }

        treesMirrorCancellable = directoryMonitor.$treesByDirectory
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.directoryTrees = $0 }

        expandedPaths = sidebarExpansionState.expandedPaths
        expansionMirrorCancellable = sidebarExpansionState.$expandedPaths
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.expandedPaths = $0 }
    }

    @discardableResult
    func openProjectFile(_ node: ProjectFileNode) -> DocumentSession? {
        open(url: node.fileURL)
    }

    @discardableResult
    func createProject() -> UUID {
        let project = projectStore.addProject(name: "New Project")
        return project.id
    }

    func deleteProject(_ project: Project) {
        projectStore.removeProject(id: project.id)
    }

    func renameProject(_ project: Project, newName: String) {
        projectStore.renameProject(id: project.id, newName: newName)
    }

    func addDirectoryToProject(_ project: Project) {
        guard let url = openPanelService.chooseDirectory() else {
            return
        }

        projectStore.addDirectory(to: project.id, path: url.path)
    }

    func removeDirectoryFromProject(_ project: Project, path: String) {
        projectStore.removeDirectory(from: project.id, path: path)
    }

    func excludeDirectoryFromProject(_ project: Project, path: String) {
        projectStore.excludeDirectory(from: project.id, path: path)
    }

    func includeDirectoryInProject(_ project: Project, path: String) {
        projectStore.includeDirectory(in: project.id, path: path)
    }

    func setProjectFileTypes(_ project: Project, types: [String]?) {
        projectStore.setEnabledFileTypes(for: project.id, types: types)
    }

    private func updateExtensionOverrides(for projects: [Project]) {
        var overrides: [String: Set<String>] = [:]
        for project in projects {
            if let types = project.enabledFileTypes {
                let typeSet = Set(types)
                for path in project.directoryPaths {
                    overrides[path] = typeSet
                }
            }
        }
        directoryMonitor.updateExtensionOverrides(overrides)
    }
}
