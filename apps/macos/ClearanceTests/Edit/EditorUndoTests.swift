import AppKit
import XCTest
@testable import Clearance

@MainActor
final class EditorUndoTests: XCTestCase {
    func testSyntaxHighlightingPreservesTextUndoStep() {
        let textView = EditorTextView(frame: .zero)
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.string = "abc"

        textView.insertText("d", replacementRange: NSRange(location: 3, length: 0))
        XCTAssertEqual(textView.string, "abcd")

        MarkdownSyntaxHighlighter().apply(to: textView)

        textView.undoManager?.undo()
        XCTAssertEqual(textView.string, "abc")
    }

    func testControlZPerformsUndo() throws {
        let textView = EditorTextView(frame: .zero)
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.string = "abc"

        textView.insertText("d", replacementRange: NSRange(location: 3, length: 0))
        XCTAssertEqual(textView.string, "abcd")

        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.control],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "z",
            charactersIgnoringModifiers: "z",
            isARepeat: false,
            keyCode: 6
        ) else {
            XCTFail("Failed to build Control+Z key event")
            return
        }

        textView.keyDown(with: event)
        XCTAssertEqual(textView.string, "abc")
    }

    func testCommandZPerformsUndo() throws {
        let textView = EditorTextView(frame: .zero)
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.string = "abc"

        textView.insertText("d", replacementRange: NSRange(location: 3, length: 0))
        XCTAssertEqual(textView.string, "abcd")

        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "z",
            charactersIgnoringModifiers: "z",
            isARepeat: false,
            keyCode: 6
        ) else {
            XCTFail("Failed to build Command+Z key event")
            return
        }

        textView.keyDown(with: event)
        XCTAssertEqual(textView.string, "abc")
    }

    func testShiftCommandZPerformsRedo() throws {
        let textView = EditorTextView(frame: .zero)
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.string = "abc"

        textView.insertText("d", replacementRange: NSRange(location: 3, length: 0))
        XCTAssertEqual(textView.string, "abcd")
        textView.undoManager?.undo()
        XCTAssertEqual(textView.string, "abc")

        guard let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.command, .shift],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "Z",
            charactersIgnoringModifiers: "z",
            isARepeat: false,
            keyCode: 6
        ) else {
            XCTFail("Failed to build Shift+Command+Z key event")
            return
        }

        textView.keyDown(with: event)
        XCTAssertEqual(textView.string, "abcd")
    }
}
