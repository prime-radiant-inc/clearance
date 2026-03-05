import Combine
import Foundation

@MainActor
final class WorkspaceViewModel: NSObject, ObservableObject {
    @Published var activeSession: DocumentSession? {
        didSet {
            bindActiveSession()
        }
    }
    @Published var activeRemoteDocument: RemoteDocument?
    @Published var isLoadingRemoteDocument = false
    @Published var errorMessage: String?
    @Published var mode: WorkspaceMode
    @Published var selectedRecentPath: String?
    @Published private(set) var windowTitle: String
    @Published private(set) var externalChangeDocumentName: String?
    @Published private(set) var canNavigateBack = false
    @Published private(set) var canNavigateForward = false

    var hasActiveDocument: Bool { activeSession != nil || activeRemoteDocument != nil }
    var isActiveDocumentRemote: Bool { activeRemoteDocument != nil }
    var activeDocumentURL: URL? { activeRemoteDocument?.url ?? activeSession?.url }

    let recentFilesStore: RecentFilesStore

    private let openPanelService: OpenPanelServicing
    private let appSettings: AppSettings
    private let remoteFetcher: RemoteDocumentFetcher
    private var activeSessionCancellables: Set<AnyCancellable> = []
    private var externalChangeTimer: Timer?
    private weak var monitoredSession: DocumentSession?
    private var navigationHistory: [URL] = []
    private var navigationHistoryIndex = -1

    init(
        recentFilesStore: RecentFilesStore = RecentFilesStore(),
        openPanelService: OpenPanelServicing = OpenPanelService(),
        appSettings: AppSettings = AppSettings(),
        remoteFetcher: RemoteDocumentFetcher = .live
    ) {
        self.recentFilesStore = recentFilesStore
        self.openPanelService = openPanelService
        self.appSettings = appSettings
        self.remoteFetcher = remoteFetcher
        mode = appSettings.defaultOpenMode
        windowTitle = "Clearance"
        super.init()
    }

    @discardableResult
    func promptAndOpenFile() -> DocumentSession? {
        guard let url = openPanelService.chooseMarkdownFile() else {
            return nil
        }

        return open(url: url)
    }

    @discardableResult
    func open(recentEntry: RecentFileEntry, recordNavigation: Bool = true) -> DocumentSession? {
        open(url: recentEntry.fileURL, recordNavigation: recordNavigation)
    }

    @discardableResult
    func open(url: URL, recordNavigation: Bool = true, resetModeToDefault: Bool = true) -> DocumentSession? {
        if url.scheme == "http" || url.scheme == "https" {
            openRemote(url: url, recordNavigation: recordNavigation)
            return nil
        }

        let standardizedURL = url.standardizedFileURL

        do {
            let session = try DocumentSession(url: standardizedURL)
            activeRemoteDocument = nil
            activeSession = session
            recentFilesStore.add(url: standardizedURL)
            selectedRecentPath = standardizedURL.path
            if resetModeToDefault {
                mode = appSettings.defaultOpenMode
            }
            if recordNavigation {
                pushNavigationEntry(standardizedURL)
            } else {
                updateNavigationAvailability()
            }
            errorMessage = nil
            return session
        } catch {
            errorMessage = "Failed to open \(standardizedURL.path): \(error.localizedDescription)"
            return nil
        }
    }

    func openRemote(url: URL, recordNavigation: Bool = true) {
        isLoadingRemoteDocument = true
        Task {
            do {
                let content = try await remoteFetcher.fetch(url)
                let remoteDoc = RemoteDocument(url: url, content: content)
                activeSession = nil
                activeRemoteDocument = remoteDoc
                mode = .view
                recentFilesStore.add(url: url)
                selectedRecentPath = url.absoluteString
                windowTitle = remoteDoc.displayTitle
                if recordNavigation {
                    pushNavigationEntry(url)
                } else {
                    updateNavigationAvailability()
                }
                errorMessage = nil
            } catch {
                errorMessage = "Failed to load \(url.absoluteString): \(error.localizedDescription)"
            }
            isLoadingRemoteDocument = false
        }
    }

    func navigateBack() -> Bool {
        guard navigationHistoryIndex > 0 else {
            return false
        }

        let targetIndex = navigationHistoryIndex - 1
        let targetURL = navigationHistory[targetIndex]
        if targetURL.scheme == "http" || targetURL.scheme == "https" {
            navigationHistoryIndex = targetIndex
            updateNavigationAvailability()
            openRemote(url: targetURL, recordNavigation: false)
            return true
        }
        guard open(url: targetURL, recordNavigation: false, resetModeToDefault: false) != nil else {
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
        if targetURL.scheme == "http" || targetURL.scheme == "https" {
            navigationHistoryIndex = nextIndex
            updateNavigationAvailability()
            openRemote(url: targetURL, recordNavigation: false)
            return true
        }
        guard open(url: targetURL, recordNavigation: false, resetModeToDefault: false) != nil else {
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

        do {
            try session.reloadFromDisk()
            errorMessage = nil
            externalChangeDocumentName = nil
        } catch {
            errorMessage = "Failed to reload \(session.url.path): \(error.localizedDescription)"
        }
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

    private func bindActiveSession() {
        activeSessionCancellables.removeAll()
        externalChangeTimer?.invalidate()
        externalChangeTimer = nil
        monitoredSession = nil
        externalChangeDocumentName = nil

        guard let session = activeSession else {
            if activeRemoteDocument != nil {
                return
            }
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

                if hasExternalChanges {
                    self.externalChangeDocumentName = session.url.lastPathComponent
                } else {
                    self.externalChangeDocumentName = nil
                }
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

    private func updateWindowTitle(for session: DocumentSession) {
        windowTitle = session.displayTitle
    }

    private func pushNavigationEntry(_ url: URL) {
        let currentKey = url.isFileURL ? url.path : url.absoluteString
        if navigationHistoryIndex >= 0 {
            let prev = navigationHistory[navigationHistoryIndex]
            let previousKey = prev.isFileURL ? prev.path : prev.absoluteString
            if currentKey == previousKey {
                updateNavigationAvailability()
                return
            }
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
}
