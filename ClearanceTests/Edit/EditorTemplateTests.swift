import XCTest
@testable import Clearance

final class EditorTemplateTests: XCTestCase {
    func testEditorTemplateContainsCodeMirrorBootstrap() {
        let html = EditorTemplateProvider().html()

        XCTAssertTrue(html.contains("CodeMirror.fromTextArea"))
        XCTAssertTrue(html.contains("mode: 'markdown'"))
        XCTAssertTrue(html.contains("undoDepth: 10000"))
        XCTAssertTrue(html.contains("vendor/codemirror/lib/codemirror.min.css"))
        XCTAssertTrue(html.contains("vendor/codemirror/lib/codemirror.min.js"))
        XCTAssertTrue(html.contains("vendor/codemirror/mode/xml/xml.min.js"))
        XCTAssertTrue(html.contains("vendor/codemirror/mode/meta.min.js"))
        XCTAssertTrue(html.contains("vendor/codemirror/mode/markdown/markdown.min.js"))
        XCTAssertFalse(html.contains("https://"))
    }
}
