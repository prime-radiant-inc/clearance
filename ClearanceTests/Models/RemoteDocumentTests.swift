import XCTest
@testable import Clearance

final class RemoteDocumentTests: XCTestCase {
    func testDisplayTitleReturnsLastPathComponent() {
        let doc = RemoteDocument(url: URL(string: "https://example.com/docs/setup.md")!, content: "# Setup")
        XCTAssertEqual(doc.displayTitle, "setup.md")
    }

    func testEachDocumentHasUniqueID() {
        let url = URL(string: "https://example.com/README.md")!
        let doc1 = RemoteDocument(url: url, content: "a")
        let doc2 = RemoteDocument(url: url, content: "b")
        XCTAssertNotEqual(doc1.id, doc2.id)
    }
}
