import AppKit
import SwiftUI
import WebKit
import XCTest
@testable import Clearance

@MainActor
final class WorkspaceToolbarTests: XCTestCase {
    func testNewDocumentCommandUsesStandardMacTitleAndShortcut() {
        XCTAssertEqual(NewDocumentCommand.title, "New…")
        XCTAssertEqual(NewDocumentCommand.keyEquivalent, "n")
        XCTAssertEqual(NewDocumentCommand.modifiers, EventModifiers.command)
    }

    func testRenderedTextZoomCommandsUseStandardMacTitlesAndShortcuts() {
        XCTAssertEqual(RenderedTextZoomCommands.actualSize.title, "Actual Size")
        XCTAssertEqual(RenderedTextZoomCommands.actualSize.keyEquivalent, "0")
        XCTAssertEqual(RenderedTextZoomCommands.actualSize.modifiers, EventModifiers.command)

        XCTAssertEqual(RenderedTextZoomCommands.zoomIn.title, "Zoom In")
        XCTAssertEqual(RenderedTextZoomCommands.zoomIn.keyEquivalent, "=")
        XCTAssertEqual(RenderedTextZoomCommands.zoomIn.modifiers, EventModifiers.command)

        XCTAssertEqual(RenderedTextZoomCommands.zoomOut.title, "Zoom Out")
        XCTAssertEqual(RenderedTextZoomCommands.zoomOut.keyEquivalent, "-")
        XCTAssertEqual(RenderedTextZoomCommands.zoomOut.modifiers, EventModifiers.command)
    }

    func testAddressToolbarItemStaysVisibleAtPracticalWindowWidths() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        defer {
            window.orderOut(nil)
        }

        window.contentViewController = NSHostingController(rootView: WorkspaceView())

        window.makeKeyAndOrderFront(nil)
        pumpMainRunLoop()

        guard let toolbar = window.toolbar else {
            XCTFail("Expected workspace window to install a toolbar")
            return
        }

        guard let addressItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "clearance.address" }) as? NSSearchToolbarItem else {
            XCTFail("Expected workspace toolbar to include the address item")
            return
        }

        XCTAssertEqual(addressItem.visibilityPriority, .standard)
        window.setContentSize(NSSize(width: 900, height: 700))
        pumpMainRunLoop()

        XCTAssertTrue(addressItem.isVisible)
        let wideItemWidth = width(for: addressItem)
        XCTAssertGreaterThan(wideItemWidth, 0)

        window.setContentSize(NSSize(width: 700, height: 700))
        pumpMainRunLoop()

        XCTAssertTrue(addressItem.isVisible)
        let narrowItemWidth = width(for: addressItem)
        XCTAssertGreaterThan(narrowItemWidth, 0)
    }

    func testAddressToolbarItemUsesDocumentGlyph() throws {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        defer {
            window.orderOut(nil)
        }

        window.contentViewController = NSHostingController(rootView: WorkspaceView())

        window.makeKeyAndOrderFront(nil)
        pumpMainRunLoop()

        let defaultSearchField = NSSearchField()

        guard let toolbar = window.toolbar,
              let addressItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "clearance.address" }) as? NSSearchToolbarItem,
              let cell = addressItem.searchField.cell as? NSSearchFieldCell,
              let actualImage = cell.searchButtonCell?.image,
              let defaultImage = (defaultSearchField.cell as? NSSearchFieldCell)?.searchButtonCell?.image,
              let defaultData = defaultImage.tiffRepresentation,
              let actualData = actualImage.tiffRepresentation
        else {
            XCTFail("Expected a live address toolbar search field with a document glyph")
            return
        }

        XCTAssertTrue(type(of: cell) == NSSearchFieldCell.self)
        XCTAssertNotEqual(actualData, defaultData)
    }

    func testRenderedDocumentPrintJobRunsPrintOperationForPresentingWindow() {
        let printOperation = NSPrintOperation(view: NSView(frame: .init(x: 0, y: 0, width: 100, height: 100)))
        let webView = StubPrintWebView(printOperation: printOperation)
        let presentingWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        var capturedOperation: NSPrintOperation?
        var capturedWindow: NSWindow?

        let job = RenderedDocumentPrintJob(
            html: "<p>Printed</p>",
            baseURL: URL(fileURLWithPath: "/tmp"),
            presentingWindow: presentingWindow,
            webView: webView,
            printOperationRunner: { operation, window, _ in
                capturedOperation = operation
                capturedWindow = window
            },
            completion: {}
        )

        job.webView(webView, didFinish: nil)

        XCTAssertTrue(webView.navigationDelegate === job)
        XCTAssertEqual(webView.loadedHTMLString, "<p>Printed</p>")
        XCTAssertEqual(webView.loadedBaseURL, URL(fileURLWithPath: "/tmp"))
        XCTAssertTrue(capturedOperation === printOperation)
        XCTAssertTrue(capturedWindow === presentingWindow)
        XCTAssertTrue(printOperation.showsPrintPanel)
        XCTAssertTrue(printOperation.showsProgressPanel)
    }

    func testRenderedDocumentPrintJobCompletesOnlyAfterRunnerCallback() {
        let printOperation = NSPrintOperation(view: NSView(frame: .init(x: 0, y: 0, width: 100, height: 100)))
        let webView = StubPrintWebView(printOperation: printOperation)
        let presentingWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )

        var completionCount = 0
        var runCompletion: (() -> Void)?

        let job = RenderedDocumentPrintJob(
            html: "<p>Printed</p>",
            baseURL: URL(fileURLWithPath: "/tmp"),
            presentingWindow: presentingWindow,
            webView: webView,
            printOperationRunner: { _, _, completion in
                runCompletion = completion
            },
            completion: {
                completionCount += 1
            }
        )

        job.webView(webView, didFinish: nil)

        XCTAssertEqual(completionCount, 0)

        runCompletion?()

        XCTAssertEqual(completionCount, 1)
    }

    private func pumpMainRunLoop() {
        for _ in 0..<5 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }

    private func width(for item: NSToolbarItem) -> CGFloat {
        if let searchItem = item as? NSSearchToolbarItem {
            return searchItem.searchField.frame.width
        }

        return item.view?.frame.width ?? 0
    }
}

@MainActor
private final class StubPrintWebView: WKWebView {
    let stubPrintOperation: NSPrintOperation
    private(set) var loadedHTMLString: String?
    private(set) var loadedBaseURL: URL?

    init(printOperation: NSPrintOperation) {
        self.stubPrintOperation = printOperation
        super.init(frame: .zero, configuration: WKWebViewConfiguration())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadHTMLString(_ string: String, baseURL: URL?) -> WKNavigation? {
        loadedHTMLString = string
        loadedBaseURL = baseURL
        return nil
    }

    override func printOperation(with printInfo: NSPrintInfo) -> NSPrintOperation {
        stubPrintOperation
    }
}
