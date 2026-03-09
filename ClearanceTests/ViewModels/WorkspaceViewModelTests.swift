import XCTest
@testable import Clearance

@MainActor
final class WorkspaceViewModelTests: XCTestCase {
    func testOpenURLCreatesActiveSession() throws {
        let fileURL = try makeTempMarkdown(contents: "# One")
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let viewModel = WorkspaceViewModel(recentFilesStore: store)

        viewModel.open(url: fileURL)

        XCTAssertEqual(viewModel.activeSession?.url.path, fileURL.path)
        XCTAssertTrue(viewModel.hasActiveDocument)
        XCTAssertFalse(viewModel.isActiveDocumentRemote)
    }

    func testOpenURLInsertsRecentAtTop() throws {
        let firstURL = try makeTempMarkdown(contents: "1")
        let secondURL = try makeTempMarkdown(contents: "2")
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let viewModel = WorkspaceViewModel(recentFilesStore: store)

        viewModel.open(url: firstURL)
        viewModel.open(url: secondURL)

        XCTAssertEqual(store.entries.first?.path, secondURL.path)
    }

    func testOpeningFromRecentEntryReopensSession() throws {
        let firstURL = try makeTempMarkdown(contents: "1")
        let secondURL = try makeTempMarkdown(contents: "2")
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let viewModel = WorkspaceViewModel(recentFilesStore: store)

        viewModel.open(url: firstURL)
        viewModel.open(url: secondURL)

        let firstEntry = store.entries.last!
        viewModel.open(recentEntry: firstEntry)

        XCTAssertEqual(viewModel.activeSession?.url.path, firstURL.path)
    }

    func testWindowTitleUpdatesForActiveAndDirtySession() throws {
        let fileURL = try makeTempMarkdown(contents: "# One")
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let viewModel = WorkspaceViewModel(recentFilesStore: store)

        viewModel.open(url: fileURL)
        XCTAssertEqual(viewModel.windowTitle, "sample.md")

        viewModel.activeSession?.content = "changed"
        let titleUpdate = expectation(description: "dirty title updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            titleUpdate.fulfill()
        }
        wait(for: [titleUpdate], timeout: 1.0)
        XCTAssertEqual(viewModel.windowTitle, "*sample.md")
    }

    func testExternalChangeFlowAutoReloadsInViewMode() throws {
        let fileURL = try makeTempMarkdown(contents: "# One")
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let viewModel = WorkspaceViewModel(recentFilesStore: store)
        viewModel.open(url: fileURL)

        try "outside change".write(to: fileURL, atomically: true, encoding: .utf8)
        viewModel.checkForExternalChangesNow()
        let reloadUpdate = expectation(description: "view mode auto reloads")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            reloadUpdate.fulfill()
        }
        wait(for: [reloadUpdate], timeout: 1.0)

        XCTAssertEqual(viewModel.activeSession?.content, "outside change")
        XCTAssertNil(viewModel.externalChangeDocumentName)
    }

    func testExternalChangeFlowCanKeepCurrentVersionInEditMode() throws {
        let fileURL = try makeTempMarkdown(contents: "# One")
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let viewModel = WorkspaceViewModel(recentFilesStore: store)
        viewModel.open(url: fileURL)
        viewModel.mode = .edit

        try "outside change".write(to: fileURL, atomically: true, encoding: .utf8)
        viewModel.checkForExternalChangesNow()
        let alertUpdate = expectation(description: "external change alert updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            alertUpdate.fulfill()
        }
        wait(for: [alertUpdate], timeout: 1.0)
        XCTAssertEqual(viewModel.externalChangeDocumentName, "sample.md")

        viewModel.keepCurrentVersionAfterExternalChange()
        XCTAssertNil(viewModel.externalChangeDocumentName)
    }

    func testExternalChangeFlowCanReloadFromDisk() throws {
        let fileURL = try makeTempMarkdown(contents: "# One")
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let viewModel = WorkspaceViewModel(recentFilesStore: store)
        viewModel.open(url: fileURL)

        try "outside change".write(to: fileURL, atomically: true, encoding: .utf8)
        viewModel.checkForExternalChangesNow()

        viewModel.reloadActiveFromDisk()
        XCTAssertEqual(viewModel.activeSession?.content, "outside change")
        XCTAssertNil(viewModel.externalChangeDocumentName)
    }

    func testNavigationHistorySupportsBackAndForward() throws {
        let firstURL = try makeTempMarkdown(contents: "# One")
        let secondURL = try makeTempMarkdown(contents: "# Two")
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let viewModel = WorkspaceViewModel(recentFilesStore: store)

        viewModel.open(url: firstURL)
        viewModel.open(url: secondURL)

        XCTAssertTrue(viewModel.canNavigateBack)
        XCTAssertFalse(viewModel.canNavigateForward)

        XCTAssertTrue(viewModel.navigateBack())
        XCTAssertEqual(viewModel.activeSession?.url.path, firstURL.path)
        XCTAssertFalse(viewModel.canNavigateBack)
        XCTAssertTrue(viewModel.canNavigateForward)

        XCTAssertTrue(viewModel.navigateForward())
        XCTAssertEqual(viewModel.activeSession?.url.path, secondURL.path)
        XCTAssertTrue(viewModel.canNavigateBack)
        XCTAssertFalse(viewModel.canNavigateForward)
    }

    func testOpeningAfterBackClearsForwardHistory() throws {
        let firstURL = try makeTempMarkdown(contents: "# One")
        let secondURL = try makeTempMarkdown(contents: "# Two")
        let thirdURL = try makeTempMarkdown(contents: "# Three")
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let viewModel = WorkspaceViewModel(recentFilesStore: store)

        viewModel.open(url: firstURL)
        viewModel.open(url: secondURL)
        XCTAssertTrue(viewModel.navigateBack())

        viewModel.open(url: thirdURL)
        XCTAssertFalse(viewModel.canNavigateForward)
        XCTAssertTrue(viewModel.canNavigateBack)
    }

    func testOpenRemoteUsesRenderURLForActiveDocumentBase() async throws {
        let requestedURL = URL(string: "https://example.com/docs")!
        let renderURL = URL(string: "https://example.com/docs/INDEX.md")!
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let viewModel = WorkspaceViewModel(
            recentFilesStore: store,
            remoteDocumentLoader: { _ in
                try await Task.sleep(nanoseconds: 30_000_000)
                return RemoteDocument(requestedURL: requestedURL, renderURL: renderURL)
            }
        )

        viewModel.open(url: requestedURL)

        XCTAssertEqual(viewModel.activeDocumentURL, requestedURL)
        XCTAssertEqual(viewModel.activeRenderURL, renderURL)
        XCTAssertTrue(viewModel.isLoadingRemoteDocument)
        XCTAssertTrue(viewModel.hasActiveDocument)
        XCTAssertTrue(viewModel.isActiveDocumentRemote)

        try await Task.sleep(nanoseconds: 80_000_000)
        XCTAssertEqual(viewModel.activeDocumentURL, requestedURL)
        XCTAssertEqual(viewModel.activeRenderURL, renderURL)
        XCTAssertFalse(viewModel.isLoadingRemoteDocument)
        XCTAssertTrue(viewModel.hasActiveDocument)
        XCTAssertTrue(viewModel.isActiveDocumentRemote)
    }

    func testLatestRemoteRequestWins() async throws {
        let firstRequestedURL = URL(string: "https://example.com/first")!
        let firstRenderURL = URL(string: "https://example.com/first/INDEX.md")!
        let secondRequestedURL = URL(string: "https://example.com/second")!
        let secondRenderURL = URL(string: "https://example.com/second/INDEX.md")!
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let viewModel = WorkspaceViewModel(
            recentFilesStore: store,
            remoteDocumentLoader: { url in
                if url == firstRequestedURL {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    return RemoteDocument(requestedURL: firstRequestedURL, renderURL: firstRenderURL)
                }

                try? await Task.sleep(nanoseconds: 20_000_000)
                return RemoteDocument(requestedURL: secondRequestedURL, renderURL: secondRenderURL)
            }
        )

        viewModel.open(url: firstRequestedURL)
        viewModel.open(url: secondRequestedURL)

        try await Task.sleep(nanoseconds: 260_000_000)
        XCTAssertEqual(viewModel.activeRemoteDocument?.requestedURL, secondRequestedURL)
        XCTAssertEqual(viewModel.activeDocumentURL, secondRequestedURL)
        XCTAssertEqual(viewModel.activeRenderURL, secondRenderURL)
        XCTAssertFalse(viewModel.isLoadingRemoteDocument)
    }

    func testNavigationBackAcrossLocalAndRemote() async throws {
        let localURL = try makeTempMarkdown(contents: "# Local")
        let remoteRequestedURL = URL(string: "https://example.com/docs")!
        let remoteRenderURL = URL(string: "https://example.com/docs/INDEX.md")!
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let viewModel = WorkspaceViewModel(
            recentFilesStore: store,
            remoteDocumentLoader: { _ in
                RemoteDocument(requestedURL: remoteRequestedURL, renderURL: remoteRenderURL)
            }
        )

        viewModel.open(url: localURL)
        viewModel.open(url: remoteRequestedURL)
        await Task.yield()

        XCTAssertTrue(viewModel.canNavigateBack)
        XCTAssertEqual(viewModel.activeDocumentURL, remoteRequestedURL)
        XCTAssertEqual(viewModel.activeRenderURL, remoteRenderURL)
        XCTAssertNil(viewModel.activeSession)
        XCTAssertTrue(viewModel.hasActiveDocument)
        XCTAssertTrue(viewModel.isActiveDocumentRemote)

        XCTAssertTrue(viewModel.navigateBack())
        XCTAssertEqual(viewModel.activeSession?.url.path, localURL.path)
        XCTAssertEqual(viewModel.activeDocumentURL, localURL)
        XCTAssertEqual(viewModel.activeRenderURL, localURL)
        XCTAssertTrue(viewModel.canNavigateForward)
        XCTAssertTrue(viewModel.hasActiveDocument)
        XCTAssertFalse(viewModel.isActiveDocumentRemote)

        XCTAssertTrue(viewModel.navigateForward())
        await Task.yield()
        XCTAssertEqual(viewModel.activeDocumentURL, remoteRequestedURL)
        XCTAssertEqual(viewModel.activeRenderURL, remoteRenderURL)
        XCTAssertNil(viewModel.activeSession)
    }

    func testRemovingSelectedRecentEntryClearsSidebarSelection() throws {
        let fileURL = try makeTempMarkdown(contents: "# One")
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let viewModel = WorkspaceViewModel(recentFilesStore: store)

        viewModel.open(url: fileURL)
        let path = RecentFileEntry.storageKey(for: fileURL)
        XCTAssertEqual(viewModel.selectedRecentPath, path)

        viewModel.removeRecentEntry(path: path)

        XCTAssertNil(viewModel.selectedRecentPath)
        XCTAssertTrue(store.entries.isEmpty)
    }

    // MARK: - importFolder

    func testImportFolderAddsAllFilesToStore() throws {
        let folderURL = try makeTempFolderWithMarkdownFiles(count: 3)
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let mockPanel = MockOpenPanelService(folderURL: folderURL, useFolderNames: false)
        let viewModel = WorkspaceViewModel(recentFilesStore: store, openPanelService: mockPanel)

        let urls = viewModel.importFolder()

        XCTAssertEqual(urls.count, 3)
        XCTAssertEqual(store.entries.count, 3)
    }

    func testImportFolderOpensFirstFile() throws {
        let folderURL = try makeTempFolderWithMarkdownFiles(count: 2)
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let mockPanel = MockOpenPanelService(folderURL: folderURL, useFolderNames: false)
        let viewModel = WorkspaceViewModel(recentFilesStore: store, openPanelService: mockPanel)

        let urls = viewModel.importFolder()

        XCTAssertNotNil(viewModel.activeSession)
        XCTAssertEqual(
            viewModel.activeSession?.url.standardizedFileURL.path,
            urls.first?.standardizedFileURL.path
        )
    }

    func testImportFolderWithFolderNamesAppliesOverrides() throws {
        let folderURL = try makeTempFolderWithMarkdownFiles(count: 3)
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let mockPanel = MockOpenPanelService(folderURL: folderURL, useFolderNames: true)
        let viewModel = WorkspaceViewModel(recentFilesStore: store, openPanelService: mockPanel)

        viewModel.importFolder()

        XCTAssertTrue(store.entries.allSatisfy { $0.displayNameOverride != nil })
    }

    func testImportFolderWithoutFolderNamesHasNilOverrides() throws {
        let folderURL = try makeTempFolderWithMarkdownFiles(count: 3)
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let mockPanel = MockOpenPanelService(folderURL: folderURL, useFolderNames: false)
        let viewModel = WorkspaceViewModel(recentFilesStore: store, openPanelService: mockPanel)

        viewModel.importFolder()

        XCTAssertTrue(store.entries.allSatisfy { $0.displayNameOverride == nil })
    }

    func testImportFolderReturnsEmptyWhenCancelled() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let mockPanel = MockOpenPanelService(folderURL: nil)
        let viewModel = WorkspaceViewModel(recentFilesStore: store, openPanelService: mockPanel)

        let urls = viewModel.importFolder()

        XCTAssertTrue(urls.isEmpty)
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertNil(viewModel.activeSession)
    }

    func testImportFolderWithEmptyFolderReturnsEmpty() throws {
        let emptyFolder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: emptyFolder, withIntermediateDirectories: true)
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let mockPanel = MockOpenPanelService(folderURL: emptyFolder, useFolderNames: true)
        let viewModel = WorkspaceViewModel(recentFilesStore: store, openPanelService: mockPanel)

        let urls = viewModel.importFolder()

        XCTAssertTrue(urls.isEmpty)
        XCTAssertNil(viewModel.activeSession)
    }

    // MARK: - Helpers

    private func makeTempMarkdown(contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("sample.md")
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    private func makeTempFolderWithMarkdownFiles(count: Int) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for i in 1...count {
            let fileURL = folder.appendingPathComponent("file\(i).md")
            try "# File \(i)".write(to: fileURL, atomically: true, encoding: .utf8)
        }
        return folder
    }
}

@MainActor
private final class MockOpenPanelService: OpenPanelServicing {
    var markdownFileURL: URL?
    var folderURL: URL?
    var useFolderNames: Bool

    init(folderURL: URL?, useFolderNames: Bool = false) {
        self.folderURL = folderURL
        self.useFolderNames = useFolderNames
    }

    func chooseMarkdownFile() -> URL? { markdownFileURL }
    func chooseFolder() -> (url: URL, useFolderNames: Bool)? {
        guard let url = folderURL else { return nil }
        return (url: url, useFolderNames: useFolderNames)
    }
}
