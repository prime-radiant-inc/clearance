import AppKit
import SwiftUI
import XCTest
@testable import Clearance

@MainActor
final class WorkspaceToolbarTests: XCTestCase {
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

        guard let toolbar = window.toolbar,
              let addressItem = toolbar.items.first(where: { $0.itemIdentifier.rawValue == "clearance.address" }) as? NSSearchToolbarItem,
              let cell = addressItem.searchField.cell as? NSSearchFieldCell,
              let actualImage = cell.searchButtonCell?.image,
              let expectedImage = NSImage(
                  systemSymbolName: "doc.text",
                  accessibilityDescription: "Document"
              ) else {
            XCTFail("Expected a live address toolbar search field with a document glyph")
            return
        }

        XCTAssertEqual(actualImage.tiffRepresentation, expectedImage.tiffRepresentation)
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
