import XCTest
@testable import Clearance

final class FolderScannerTests: XCTestCase {
    private var tempDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDirectory)
        try super.tearDownWithError()
    }

    func testFindsMarkdownFilesRecursively() throws {
        let subDir = tempDirectory.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)
        try "".write(to: tempDirectory.appendingPathComponent("root.md"), atomically: true, encoding: .utf8)
        try "".write(to: subDir.appendingPathComponent("nested.md"), atomically: true, encoding: .utf8)

        let results = FolderScanner.findMarkdownFiles(in: tempDirectory)

        XCTAssertEqual(results.count, 2)
        XCTAssertTrue(results.contains { $0.lastPathComponent == "root.md" })
        XCTAssertTrue(results.contains { $0.lastPathComponent == "nested.md" })
    }

    func testFindsAllSupportedExtensions() throws {
        try "".write(to: tempDirectory.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try "".write(to: tempDirectory.appendingPathComponent("b.markdown"), atomically: true, encoding: .utf8)
        try "".write(to: tempDirectory.appendingPathComponent("c.txt"), atomically: true, encoding: .utf8)
        try "".write(to: tempDirectory.appendingPathComponent("d.swift"), atomically: true, encoding: .utf8)

        let results = FolderScanner.findMarkdownFiles(in: tempDirectory)

        XCTAssertEqual(results.count, 3)
        XCTAssertFalse(results.contains { $0.lastPathComponent == "d.swift" })
    }

    func testSkipsHiddenFiles() throws {
        try "".write(to: tempDirectory.appendingPathComponent(".hidden.md"), atomically: true, encoding: .utf8)
        try "".write(to: tempDirectory.appendingPathComponent("visible.md"), atomically: true, encoding: .utf8)

        let results = FolderScanner.findMarkdownFiles(in: tempDirectory)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.lastPathComponent, "visible.md")
    }

    func testSkipsHiddenDirectories() throws {
        let hiddenDir = tempDirectory.appendingPathComponent(".hidden", isDirectory: true)
        try FileManager.default.createDirectory(at: hiddenDir, withIntermediateDirectories: true)
        try "".write(to: hiddenDir.appendingPathComponent("inside.md"), atomically: true, encoding: .utf8)
        try "".write(to: tempDirectory.appendingPathComponent("visible.md"), atomically: true, encoding: .utf8)

        let results = FolderScanner.findMarkdownFiles(in: tempDirectory)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.lastPathComponent, "visible.md")
    }

    func testSkipsNodeModules() throws {
        let nodeModulesDir = tempDirectory.appendingPathComponent("node_modules", isDirectory: true)
        try FileManager.default.createDirectory(at: nodeModulesDir, withIntermediateDirectories: true)
        try "".write(to: nodeModulesDir.appendingPathComponent("package.md"), atomically: true, encoding: .utf8)
        try "".write(to: tempDirectory.appendingPathComponent("visible.md"), atomically: true, encoding: .utf8)

        let results = FolderScanner.findMarkdownFiles(in: tempDirectory)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.lastPathComponent, "visible.md")
    }

    func testResultsAreSortedAlphabetically() throws {
        try "".write(to: tempDirectory.appendingPathComponent("c.md"), atomically: true, encoding: .utf8)
        try "".write(to: tempDirectory.appendingPathComponent("a.md"), atomically: true, encoding: .utf8)
        try "".write(to: tempDirectory.appendingPathComponent("b.md"), atomically: true, encoding: .utf8)

        let results = FolderScanner.findMarkdownFiles(in: tempDirectory)

        XCTAssertEqual(results.map(\.lastPathComponent), ["a.md", "b.md", "c.md"])
    }

    func testEmptyDirectoryReturnsEmptyArray() {
        let results = FolderScanner.findMarkdownFiles(in: tempDirectory)
        XCTAssertTrue(results.isEmpty)
    }
}
