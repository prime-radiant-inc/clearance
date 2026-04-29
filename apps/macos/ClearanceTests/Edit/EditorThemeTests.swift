import AppKit
import SwiftUI
import XCTest
@testable import Clearance

@MainActor
final class EditorThemeTests: XCTestCase {

    private func makeEditorScrollView(theme: AppTheme, appearance: AppearancePreference) -> NSScrollView {
        let editor = CodeMirrorEditorView(text: .constant(""), theme: theme, appearance: appearance)
        let context = editor.makeCoordinator()

        // NSViewRepresentable.Context can't be fabricated in tests, so drive Coordinator directly.
        let scrollView = NSScrollView()
        scrollView.drawsBackground = true

        let textView = EditorTextView(frame: .zero)
        textView.isRichText = false
        textView.importsGraphics = false
        scrollView.documentView = textView

        context.textView = textView
        context.applyTheme(to: textView)

        return scrollView
    }

    private func assertBackground(
        of scrollView: NSScrollView,
        matchesHex hex: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expected = NSColor.testHex(hex)
        guard let textView = scrollView.documentView as? NSTextView else {
            XCTFail("No text view in scroll view", file: file, line: line)
            return
        }

        assertColorsEqual(textView.backgroundColor, expected, label: "textView.backgroundColor", hex: hex, file: file, line: line)
        assertColorsEqual(scrollView.backgroundColor, expected, label: "scrollView.backgroundColor", hex: hex, file: file, line: line)
        assertColorsEqual(scrollView.contentView.backgroundColor, expected, label: "scrollView.contentView.backgroundColor", hex: hex, file: file, line: line)
    }

    private func assertColorsEqual(
        _ actual: NSColor,
        _ expected: NSColor,
        label: String,
        hex: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actualRGB = actual.usingColorSpace(.deviceRGB)
        let expectedRGB = expected.usingColorSpace(.deviceRGB)
        guard let a = actualRGB, let e = expectedRGB else {
            XCTFail("\(label): could not convert to deviceRGB", file: file, line: line)
            return
        }

        let tolerance: CGFloat = 1.0 / 255.0
        XCTAssertEqual(a.redComponent, e.redComponent, accuracy: tolerance, "\(label) red mismatch for \(hex)", file: file, line: line)
        XCTAssertEqual(a.greenComponent, e.greenComponent, accuracy: tolerance, "\(label) green mismatch for \(hex)", file: file, line: line)
        XCTAssertEqual(a.blueComponent, e.blueComponent, accuracy: tolerance, "\(label) blue mismatch for \(hex)", file: file, line: line)
    }

    // MARK: - Apple Theme

    func testAppleLightBackground() {
        let scrollView = makeEditorScrollView(theme: .apple, appearance: .light)
        assertBackground(of: scrollView, matchesHex: "#F5F5F7")
    }

    func testAppleDarkBackground() {
        let scrollView = makeEditorScrollView(theme: .apple, appearance: .dark)
        assertBackground(of: scrollView, matchesHex: "#1C1C1E")
    }

    // MARK: - Classic Blue Theme

    func testClassicBlueLightBackground() {
        let scrollView = makeEditorScrollView(theme: .classicBlue, appearance: .light)
        assertBackground(of: scrollView, matchesHex: "#F3F5F9")
    }

    func testClassicBlueDarkBackground() {
        let scrollView = makeEditorScrollView(theme: .classicBlue, appearance: .dark)
        assertBackground(of: scrollView, matchesHex: "#0E1118")
    }
}

private extension NSColor {
    static func testHex(_ value: String) -> NSColor {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        let scanner = Scanner(string: normalized)
        var hexValue: UInt64 = 0
        guard scanner.scanHexInt64(&hexValue) else {
            return .textColor
        }

        switch normalized.count {
        case 6:
            let red = CGFloat((hexValue & 0xFF0000) >> 16) / 255.0
            let green = CGFloat((hexValue & 0x00FF00) >> 8) / 255.0
            let blue = CGFloat(hexValue & 0x0000FF) / 255.0
            return NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1.0)
        case 8:
            let red = CGFloat((hexValue & 0xFF000000) >> 24) / 255.0
            let green = CGFloat((hexValue & 0x00FF0000) >> 16) / 255.0
            let blue = CGFloat((hexValue & 0x0000FF00) >> 8) / 255.0
            let alpha = CGFloat(hexValue & 0x000000FF) / 255.0
            return NSColor(calibratedRed: red, green: green, blue: blue, alpha: alpha)
        default:
            preconditionFailure("testHex expects a 6 or 8 character hex string, got \(normalized.count): \(value)")
        }
    }
}
