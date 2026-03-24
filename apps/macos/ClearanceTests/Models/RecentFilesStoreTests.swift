import XCTest
@testable import Clearance

final class RecentFilesStoreTests: XCTestCase {
    func testAddingNewFilePlacesItAtTop() {
        let defaults = UserDefaults(suiteName: "RecentFilesStoreTests-1")!
        defaults.removePersistentDomain(forName: "RecentFilesStoreTests-1")

        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        store.add(url: URL(fileURLWithPath: "/tmp/one.md"))
        store.add(url: URL(fileURLWithPath: "/tmp/two.md"))

        XCTAssertEqual(store.entries.map(\.path), ["/tmp/two.md", "/tmp/one.md"])
    }

    func testReopeningFileMovesItToTopWithoutDuplicates() {
        let defaults = UserDefaults(suiteName: "RecentFilesStoreTests-2")!
        defaults.removePersistentDomain(forName: "RecentFilesStoreTests-2")

        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let one = URL(fileURLWithPath: "/tmp/one.md")
        let two = URL(fileURLWithPath: "/tmp/two.md")
        store.add(url: one)
        store.add(url: two)
        store.add(url: one)

        XCTAssertEqual(store.entries.map(\.path), ["/tmp/one.md", "/tmp/two.md"])
    }

    func testStoreRoundTripsThroughUserDefaults() {
        let suite = "RecentFilesStoreTests-3"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let firstStore = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        firstStore.add(url: URL(fileURLWithPath: "/tmp/alpha.md"))

        let secondStore = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        XCTAssertEqual(secondStore.entries.count, 1)
        XCTAssertEqual(secondStore.entries.first?.path, "/tmp/alpha.md")
        XCTAssertEqual(secondStore.entries.first?.displayName, "alpha.md")
        XCTAssertEqual(secondStore.entries.first?.directoryPath, "/tmp")
        XCTAssertNotEqual(secondStore.entries.first?.lastOpenedAt, .distantPast)
    }

    func testDecodesLegacyEntriesWithoutLastOpenedDate() throws {
        let suite = "RecentFilesStoreTests-4"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let legacyData = #" [{"path":"/tmp/legacy.md"}] "#.data(using: .utf8)!
        defaults.set(legacyData, forKey: "recent")

        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.path, "/tmp/legacy.md")
        XCTAssertEqual(store.entries.first?.lastOpenedAt, .distantPast)
    }

    func testRecentStoreSupportsRemoteURLKeys() {
        let suite = "RecentFilesStoreTests-5"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let remoteURL = URL(string: "https://example.com/docs")!
        store.add(url: remoteURL)
        store.add(url: URL(fileURLWithPath: "/tmp/local.md"))
        store.add(url: remoteURL)

        XCTAssertEqual(store.entries.first?.path, "https://example.com/docs")
        XCTAssertEqual(store.entries.first?.fileURL, remoteURL)
        XCTAssertEqual(store.entries.filter { $0.path == "https://example.com/docs" }.count, 1)
        XCTAssertNotEqual(store.entries.first?.path, remoteURL.path)
    }

    func testRemovingEntryDeletesOnlyMatchingPath() {
        let suite = "RecentFilesStoreTests-6"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        store.add(url: URL(fileURLWithPath: "/tmp/one.md"))
        store.add(url: URL(fileURLWithPath: "/tmp/two.md"))

        store.remove(path: "/tmp/one.md")

        XCTAssertEqual(store.entries.map(\.path), ["/tmp/two.md"])
    }
}
