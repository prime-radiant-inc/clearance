import AppKit
import SwiftUI
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

    func testCoordinatorSkipsHighlightingWhenTextAndStyleAreUnchanged() {
        let textView = EditorTextView(frame: .zero)
        textView.string = "abc"
        let highlighter = CountingEditorHighlighter()
        let editor = CodeMirrorEditorView(
            text: .constant("abc"),
            theme: .apple,
            appearance: .light
        )
        let coordinator = CodeMirrorEditorView.Coordinator(parent: editor, highlighter: highlighter)

        coordinator.updateTextView(textView, with: "abc")
        XCTAssertEqual(highlighter.applyCount, 1)

        coordinator.updateTextView(textView, with: "abc")
        XCTAssertEqual(highlighter.applyCount, 1)
    }

    func testCoordinatorDoesNotRunFullHighlightingDuringTyping() async throws {
        var boundText = ""
        let textView = EditorTextView(frame: .zero)
        let highlighter = CountingEditorHighlighter()
        let editor = CodeMirrorEditorView(
            text: Binding(
                get: { boundText },
                set: { boundText = $0 }
            ),
            theme: .apple,
            appearance: .light
        )
        let coordinator = CodeMirrorEditorView.Coordinator(
            parent: editor,
            highlighter: highlighter
        )
        coordinator.editorTextView = textView

        textView.string = "first"
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))
        textView.string = "second"
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(boundText, "second")
        XCTAssertEqual(highlighter.applyCount, 0)

        try await Task.sleep(nanoseconds: 250_000_000)

        XCTAssertEqual(highlighter.applyCount, 0)
    }

    func testCoordinatorUsesIncrementalHighlightingDuringTyping() {
        var boundText = ""
        let textView = EditorTextView(frame: .zero)
        let highlighter = CountingEditorHighlighter()
        let editor = CodeMirrorEditorView(
            text: Binding(
                get: { boundText },
                set: { boundText = $0 }
            ),
            theme: .apple,
            appearance: .light
        )
        let coordinator = CodeMirrorEditorView.Coordinator(
            parent: editor,
            highlighter: highlighter
        )
        coordinator.editorTextView = textView

        let delegate = coordinator as NSTextViewDelegate
        XCTAssertTrue(delegate.textView?(textView, shouldChangeTextIn: NSRange(location: 0, length: 0), replacementString: "#") ?? false)
        textView.string = "#"
        coordinator.textDidChange(Notification(name: NSText.didChangeNotification, object: textView))

        XCTAssertEqual(boundText, "#")
        XCTAssertEqual(highlighter.applyCount, 0)
        XCTAssertEqual(highlighter.incrementalApplyCount, 1)
        XCTAssertEqual(highlighter.lastChangedRange, NSRange(location: 0, length: 1))
    }

    func testIncrementalHighlightingFormatsChangedHeading() {
        let textView = EditorTextView(frame: .zero)
        textView.string = "# Heading\n\nPlain"

        MarkdownSyntaxHighlighter().apply(to: textView, changedRange: NSRange(location: 0, length: 9))

        let font = try? XCTUnwrap(textView.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont)
        XCTAssertEqual(font?.pointSize, 20)
    }

    func testSyntaxHighlightingColorsFrontmatterYamlTokens() throws {
        let textView = EditorTextView(frame: .zero)
        textView.string = """
        ---
        title: "Post"
        published: true
        count: 42
        ---
        # Body
        """

        MarkdownSyntaxHighlighter().apply(to: textView)

        let palette = EditorPalette(variant: AppTheme.apple.palette.light)
        XCTAssertColor(atSubstring: "title", in: textView, equals: palette.syntaxProperty)
        XCTAssertColor(atSubstring: "\"Post\"", in: textView, equals: palette.syntaxString)
        XCTAssertColor(atSubstring: "true", in: textView, equals: palette.syntaxKeyword)
        XCTAssertColor(atSubstring: "42", in: textView, equals: palette.syntaxNumber)
    }

    func testSyntaxHighlightingColorsPythonFencedCodeTokens() throws {
        let textView = EditorTextView(frame: .zero)
        textView.string = """
        ```python
        def greet(name):
            return "hi"
        # comment
        ```
        """

        MarkdownSyntaxHighlighter().apply(to: textView)

        let palette = EditorPalette(variant: AppTheme.apple.palette.light)
        XCTAssertColor(atSubstring: "def", in: textView, equals: palette.syntaxKeyword)
        XCTAssertColor(atSubstring: "return", in: textView, equals: palette.syntaxKeyword)
        XCTAssertColor(atSubstring: "\"hi\"", in: textView, equals: palette.syntaxString)
        XCTAssertColor(atSubstring: "# comment", in: textView, equals: palette.syntaxComment)
    }

    func testDeletingEitherCodeFenceClearsTokenColors() throws {
        for closingFence in [false, true] {
            let textView = EditorTextView(frame: .zero)
            textView.string = "```python\nreturn 42\n```\n"
            let highlighter = MarkdownSyntaxHighlighter()
            highlighter.apply(to: textView)
            let storage = try XCTUnwrap(textView.textStorage)
            let fence = (storage.string as NSString).range(
                of: "```", options: closingFence ? .backwards : []
            )

            storage.replaceCharacters(in: fence, with: "")
            highlighter.apply(to: textView, changedRange: NSRange(location: fence.location, length: 0))

            XCTAssertColor(atSubstring: "return", in: textView, equals: EditorPalette.default.text)
        }
    }

    func testDeletingFrontmatterDelimiterClearsYamlColors() throws {
        let textView = EditorTextView(frame: .zero)
        textView.string = "---\ntitle: Post\n---\nBody\n"
        let highlighter = MarkdownSyntaxHighlighter()
        highlighter.apply(to: textView)
        let storage = try XCTUnwrap(textView.textStorage)
        let delimiter = (storage.string as NSString).range(of: "---", options: .backwards)

        storage.replaceCharacters(in: delimiter, with: "")
        highlighter.apply(to: textView, changedRange: NSRange(location: delimiter.location, length: 0))

        XCTAssertColor(atSubstring: "title", in: textView, equals: EditorPalette.default.text)
    }

    func testDeletingMultilineLinkDelimiterClearsLinkFormatting() throws {
        let textView = EditorTextView(frame: .zero)
        textView.string = "[first\nsecond](https://example.com)\n"
        let highlighter = MarkdownSyntaxHighlighter()
        highlighter.apply(to: textView)
        let storage = try XCTUnwrap(textView.textStorage)
        let delimiter = (storage.string as NSString).range(of: ")")

        storage.replaceCharacters(in: delimiter, with: "")
        highlighter.apply(to: textView, changedRange: NSRange(location: delimiter.location, length: 0))

        XCTAssertColor(atSubstring: "first", in: textView, equals: EditorPalette.default.text)
        XCTAssertNil(storage.attribute(.underlineStyle, at: 1, effectiveRange: nil))
    }

    func testEditingMultilineLinkPreservesLinkFormatting() throws {
        let textView = EditorTextView(frame: .zero)
        textView.string = "[first\nsecond](https://example.com)\n"
        let highlighter = MarkdownSyntaxHighlighter()
        highlighter.apply(to: textView)
        let storage = try XCTUnwrap(textView.textStorage)
        let word = (storage.string as NSString).range(of: "second")

        storage.replaceCharacters(in: word, with: "changed")
        highlighter.apply(to: textView, changedRange: NSRange(location: word.location, length: 7))

        XCTAssertColor(atSubstring: "changed", in: textView, equals: EditorPalette.default.link)
    }

    private func XCTAssertColor(
        atSubstring substring: String,
        in textView: NSTextView,
        equals expectedColor: NSColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let text = textView.string as NSString
        let range = text.range(of: substring)
        XCTAssertNotEqual(range.location, NSNotFound, file: file, line: line)

        guard range.location != NSNotFound,
              let actualColor = textView.textStorage?.attribute(.foregroundColor, at: range.location, effectiveRange: nil) as? NSColor else {
            XCTFail("Missing foreground color for \(substring)", file: file, line: line)
            return
        }

        XCTAssertTrue(
            actualColor.isEqual(expectedColor),
            "Expected \(substring) to use \(expectedColor), got \(actualColor)",
            file: file,
            line: line
        )
    }
}

@MainActor
private final class CountingEditorHighlighter: EditorHighlighting {
    private(set) var applyCount = 0
    private(set) var incrementalApplyCount = 0
    private(set) var lastChangedRange: NSRange?

    func setPalette(_ newPalette: EditorPalette) {}

    func apply(to textView: NSTextView) {
        applyCount += 1
    }

    func apply(to textView: NSTextView, changedRange: NSRange) {
        incrementalApplyCount += 1
        lastChangedRange = changedRange
    }
}
