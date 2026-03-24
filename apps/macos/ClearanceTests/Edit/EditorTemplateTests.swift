import XCTest
@testable import Clearance

final class EditorTemplateTests: XCTestCase {
    func testEditorTemplateContainsCodeMirrorBootstrap() {
        let html = EditorTemplateProvider().html()

        XCTAssertTrue(html.contains("CodeMirror.fromTextArea"))
        XCTAssertTrue(html.contains("mode: 'markdown'"))
        XCTAssertTrue(html.contains("undoDepth: 10000"))
        XCTAssertTrue(html.contains("codemirror.min.css"))
        XCTAssertTrue(html.contains("codemirror.min.js"))
        XCTAssertTrue(html.contains("xml.min.js"))
        XCTAssertTrue(html.contains("meta.min.js"))
        XCTAssertTrue(html.contains("markdown.min.js"))
        XCTAssertFalse(html.contains("https://"))
    }
}
