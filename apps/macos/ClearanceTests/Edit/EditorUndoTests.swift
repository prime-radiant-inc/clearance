import AppKit
import XCTest
@testable import Clearance

@MainActor
final class EditorUndoTests: XCTestCase {
    func testApplyDarkThemeColorsTextViewAndScrollViewBackgrounds() {
        let scrollView = NSScrollView()
        let textView = EditorTextView(frame: .zero)
        scrollView.documentView = textView

        let editorView = CodeMirrorEditorView(
            text: .constant(""),
            theme: .apple,
            appearance: .dark
        )
        let coordinator = editorView.makeCoordinator()

        coordinator.applyTheme(to: textView)

        assertColor(textView.backgroundColor, equalsHex: "#1C1C1E")
        assertColor(scrollView.backgroundColor, equalsHex: "#1C1C1E")
        assertColor(scrollView.contentView.backgroundColor, equalsHex: "#1C1C1E")
        XCTAssertFalse(textView.usesAdaptiveColorMappingForDarkAppearance)
    }

    func testSystemThemeUsesApplicationAppearanceBeforeTextViewJoinsWindow() {
        let originalAppearance = NSApp.appearance
        NSApp.appearance = NSAppearance(named: .darkAqua)
        defer { NSApp.appearance = originalAppearance }

        let textView = EditorTextView(frame: .zero)
        let editorView = CodeMirrorEditorView(
            text: .constant(""),
            theme: .classicBlue,
            appearance: .system
        )
        let coordinator = editorView.makeCoordinator()

        coordinator.applyTheme(to: textView)

        assertColor(textView.backgroundColor, equalsHex: "#0E1118")
    }

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

    private func assertColor(
        _ color: NSColor,
        equalsHex hex: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expected = colorFromHex(hex)

        XCTAssertEqual(color.redComponent, expected.redComponent, accuracy: 1.0 / 255.0, file: file, line: line)
        XCTAssertEqual(color.greenComponent, expected.greenComponent, accuracy: 1.0 / 255.0, file: file, line: line)
        XCTAssertEqual(color.blueComponent, expected.blueComponent, accuracy: 1.0 / 255.0, file: file, line: line)
        XCTAssertEqual(color.alphaComponent, expected.alphaComponent, accuracy: 1.0 / 255.0, file: file, line: line)
    }

    private func colorFromHex(_ hex: String) -> NSColor {
        let trimmed = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: trimmed).scanHexInt64(&value)
        return NSColor(
            calibratedRed: CGFloat((value >> 16) & 0xFF) / 255.0,
            green: CGFloat((value >> 8) & 0xFF) / 255.0,
            blue: CGFloat(value & 0xFF) / 255.0,
            alpha: 1.0
        )
    }
}
