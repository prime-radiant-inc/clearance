import AppKit
import SwiftUI
import XCTest
@testable import Clearance

@MainActor
final class OutlineSplitViewControllerTests: XCTestCase {
    func testInspectorItemUsesNativeCollapsibleInspectorBehavior() {
        let controller = OutlineSplitViewController(
            primary: AnyView(Text("Document")),
            inspector: AnyView(Text("Outline")),
            showsInspector: true
        )
        let window = hostWindow(for: controller)
        defer {
            window.orderOut(nil)
        }

        XCTAssertEqual(controller.splitViewItems.count, 2)

        let inspectorItem = controller.inspectorItem
        XCTAssertEqual(inspectorItem.behavior, .inspector)
        XCTAssertTrue(inspectorItem.canCollapse)
        XCTAssertFalse(inspectorItem.isCollapsed)
    }

    func testInspectorItemCollapsesAndUncollapsesOnDemand() throws {
        let controller = OutlineSplitViewController(
            primary: AnyView(Text("Document")),
            inspector: AnyView(Text("Outline")),
            showsInspector: true
        )
        let window = hostWindow(for: controller)
        defer {
            window.orderOut(nil)
        }

        controller.setInspectorCollapsed(true, animated: false)
        XCTAssertTrue(controller.inspectorItem.isCollapsed)

        controller.setInspectorCollapsed(false, animated: false)
        XCTAssertFalse(controller.inspectorItem.isCollapsed)
    }

    private func hostWindow(for controller: NSViewController) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 700),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = controller
        window.makeKeyAndOrderFront(nil)
        pumpMainRunLoop()
        return window
    }

    private func pumpMainRunLoop() {
        for _ in 0..<5 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }
}
