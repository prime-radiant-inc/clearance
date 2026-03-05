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

    func testAddRemoteURL() {
        let suite = "RecentFilesStoreTests-remote-1"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        let remoteURL = URL(string: "https://example.com/docs/README.md")!
        store.add(url: remoteURL)

        XCTAssertEqual(store.entries.count, 1)
        XCTAssertEqual(store.entries.first?.path, "https://example.com/docs/README.md")
    }

    func testRemoteEntryProperties() {
        let entry = RecentFileEntry(path: "https://example.com/docs/README.md")

        XCTAssertTrue(entry.isRemote)
        XCTAssertEqual(entry.displayName, "README.md")
        XCTAssertEqual(entry.directoryPath, "example.com/docs")
        XCTAssertEqual(entry.fileURL.absoluteString, "https://example.com/docs/README.md")
    }

    func testMixedLocalRemoteEntries() {
        let suite = "RecentFilesStoreTests-remote-2"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)

        let store = RecentFilesStore(userDefaults: defaults, storageKey: "recent")
        store.add(url: URL(fileURLWithPath: "/tmp/local.md"))
        store.add(url: URL(string: "https://example.com/remote.md")!)

        XCTAssertEqual(store.entries.count, 2)
        XCTAssertTrue(store.entries[0].isRemote)
        XCTAssertFalse(store.entries[1].isRemote)
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
}
