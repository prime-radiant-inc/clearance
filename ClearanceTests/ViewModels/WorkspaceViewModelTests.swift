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

    func testExternalChangeFlowCanKeepCurrentVersion() throws {
        let fileURL = try makeTempMarkdown(contents: "# One")
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let viewModel = WorkspaceViewModel(recentFilesStore: store)
        viewModel.open(url: fileURL)

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

    func testOpenRemoteURLCreatesRemoteDocument() async throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let fetcher = RemoteDocumentFetcher { _ in "# Remote" }
        let viewModel = WorkspaceViewModel(recentFilesStore: store, remoteFetcher: fetcher)

        let url = URL(string: "https://example.com/test.md")!
        viewModel.openRemote(url: url)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(viewModel.activeRemoteDocument)
        XCTAssertEqual(viewModel.activeRemoteDocument?.url, url)
        XCTAssertEqual(viewModel.activeRemoteDocument?.content, "# Remote")
        XCTAssertNil(viewModel.activeSession)
    }

    func testOpenRemoteURLForcesViewMode() async throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let fetcher = RemoteDocumentFetcher { _ in "# Remote" }
        let viewModel = WorkspaceViewModel(recentFilesStore: store, remoteFetcher: fetcher)
        viewModel.mode = .edit

        let url = URL(string: "https://example.com/test.md")!
        viewModel.openRemote(url: url)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(viewModel.mode, .view)
    }

    func testOpenRemoteURLSetsLoadingState() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let fetcher = RemoteDocumentFetcher { _ in
            try await Task.sleep(nanoseconds: 500_000_000)
            return "# Slow"
        }
        let viewModel = WorkspaceViewModel(recentFilesStore: store, remoteFetcher: fetcher)

        let url = URL(string: "https://example.com/test.md")!
        viewModel.openRemote(url: url)

        XCTAssertTrue(viewModel.isLoadingRemoteDocument)
    }

    func testOpenRemoteURLErrorSetsErrorMessage() async throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let fetcher = RemoteDocumentFetcher { _ in
            throw RemoteDocumentError.httpError(statusCode: 404)
        }
        let viewModel = WorkspaceViewModel(recentFilesStore: store, remoteFetcher: fetcher)

        let url = URL(string: "https://example.com/missing.md")!
        viewModel.openRemote(url: url)

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNil(viewModel.activeRemoteDocument)
    }

    func testOpenURLWithHTTPSchemeRoutesToRemote() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let fetcher = RemoteDocumentFetcher { _ in "# Remote" }
        let viewModel = WorkspaceViewModel(recentFilesStore: store, remoteFetcher: fetcher)

        let url = URL(string: "https://example.com/test.md")!
        let result = viewModel.open(url: url)

        XCTAssertNil(result, "open(url:) should return nil for remote URLs")
    }

    func testNavigationHistoryAcrossLocalAndRemote() async throws {
        let localURL = try makeTempMarkdown(contents: "# Local")
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let fetcher = RemoteDocumentFetcher { _ in "# Remote" }
        let viewModel = WorkspaceViewModel(recentFilesStore: store, remoteFetcher: fetcher)

        viewModel.open(url: localURL)
        XCTAssertNotNil(viewModel.activeSession)

        let remoteURL = URL(string: "https://example.com/test.md")!
        viewModel.openRemote(url: remoteURL)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(viewModel.canNavigateBack)
        XCTAssertTrue(viewModel.navigateBack())

        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNotNil(viewModel.activeSession)
        XCTAssertEqual(viewModel.activeSession?.url.path, localURL.path)
    }

    private func makeTempMarkdown(contents: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("sample.md")
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
