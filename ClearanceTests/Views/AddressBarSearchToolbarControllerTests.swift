import AppKit
import XCTest
@testable import Clearance

@MainActor
final class AddressBarSearchToolbarControllerTests: XCTestCase {
    func testAddressFieldShowsDocumentGlyph() {
        let controller = AddressBarSearchToolbarController()
        let expectedImage = NSImage(
            systemSymbolName: "doc.text",
            accessibilityDescription: "Document"
        )

        guard let cell = controller.item.searchField.cell as? NSSearchFieldCell,
              let actualImage = cell.searchButtonCell?.image,
              let expectedImage else {
            XCTFail("Expected an NSSearchFieldCell backing the address field")
            return
        }

        XCTAssertEqual(actualImage.tiffRepresentation, expectedImage.tiffRepresentation)
    }

    func testBeginEditingShowsFullPathForLocalFile() {
        let controller = AddressBarSearchToolbarController()
        let url = URL(fileURLWithPath: "/tmp/docs/SKILL.md")

        controller.update(activeURL: url, isLoading: false) { _ in }
        controller.controlTextDidBeginEditing(
            Notification(name: NSControl.textDidBeginEditingNotification, object: controller.item.searchField)
        )

        XCTAssertEqual(controller.item.searchField.stringValue, "/tmp/docs/SKILL.md")
    }

    func testCommitUsesFullPathWhenFieldStillShowsDisplayTextForLocalFile() {
        let controller = AddressBarSearchToolbarController()
        let url = URL(fileURLWithPath: "/tmp/docs/SKILL.md")
        var committedValue: String?

        controller.update(activeURL: url, isLoading: false) { committedValue = $0 }
        controller.item.searchField.stringValue = "SKILL.md"
        controller.commitFromAction(controller.item.searchField)

        XCTAssertEqual(committedValue, "/tmp/docs/SKILL.md")
    }

    func testCommitUsesFullURLWhenFieldStillShowsDisplayTextForRemoteURL() {
        let controller = AddressBarSearchToolbarController()
        let url = URL(string: "https://example.com/docs/guide.md")!
        var committedValue: String?

        controller.update(activeURL: url, isLoading: false) { committedValue = $0 }
        controller.item.searchField.stringValue = "example.com/docs/guide.md"
        controller.commitFromAction(controller.item.searchField)

        XCTAssertEqual(committedValue, "https://example.com/docs/guide.md")
    }

    func testMousePrimaryActionShowsFullPathForLocalFile() {
        let controller = AddressBarSearchToolbarController()
        let url = URL(fileURLWithPath: "/tmp/docs/SKILL.md")

        controller.update(activeURL: url, isLoading: false) { _ in }
        controller.handlePrimaryInteraction(controller.item.searchField)
        pumpMainRunLoop()

        XCTAssertEqual(controller.item.searchField.stringValue, "/tmp/docs/SKILL.md")
    }

    private func pumpMainRunLoop() {
        for _ in 0..<5 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
    }
}
