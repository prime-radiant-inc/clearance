import AppKit
import SwiftUI

struct AddressBarView: View {
    let activeURL: URL?
    let isLoading: Bool
    let onCommit: (String) -> Void

    var body: some View {
        Color.clear
            .frame(width: 1, height: AddressBarSearchToolbarController.toolbarHeight)
            .accessibilityHidden(true)
    }
}

@MainActor
private final class AddressBarSearchField: NSSearchField {
    var onPrimaryInteraction: ((NSSearchField) -> Void)?

    override func mouseDown(with event: NSEvent) {
        onPrimaryInteraction?(self)
        super.mouseDown(with: event)
    }

    override func becomeFirstResponder() -> Bool {
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if didBecomeFirstResponder {
            onPrimaryInteraction?(self)
        }

        return didBecomeFirstResponder
    }
}

@MainActor
final class AddressBarSearchToolbarController: NSObject, NSSearchFieldDelegate {
    static let itemIdentifier = NSToolbarItem.Identifier("clearance.address")
    static let toolbarHeight: CGFloat = 24

    let item = NSSearchToolbarItem(itemIdentifier: AddressBarSearchToolbarController.itemIdentifier)

    private var activeURL: URL?
    private var onCommit: (String) -> Void = { _ in }
    private var isEditing = false
    private var committedViaReturn = false

    override init() {
        super.init()

        let searchField = AddressBarSearchField()
        item.searchField = searchField
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(commitFromAction(_:))
        searchField.sendsSearchStringImmediately = false
        searchField.sendsWholeSearchString = true
        searchField.focusRingType = .default
        searchField.placeholderString = "Enter path or URL"
        searchField.onPrimaryInteraction = { [weak self] field in
            self?.handlePrimaryInteraction(field)
        }

        if let cell = searchField.cell as? NSSearchFieldCell {
            cell.usesSingleLineMode = true
            cell.searchButtonCell = makeDocumentButtonCell()
        }
    }

    func update(
        activeURL: URL?,
        isLoading: Bool,
        onCommit: @escaping (String) -> Void
    ) {
        let didChangeURL = self.activeURL != activeURL
        self.activeURL = activeURL
        self.onCommit = onCommit

        if didChangeURL {
            isEditing = false
        }

        if !isLoading && item.searchField.placeholderString != "Enter path or URL" {
            item.searchField.placeholderString = "Enter path or URL"
        } else if isLoading {
            item.searchField.placeholderString = "Loading…"
        }

        syncText()
    }

    @objc func commitFromAction(_ sender: NSSearchField) {
        commit(using: sender)
    }

    func handlePrimaryInteraction(_ sender: NSSearchField) {
        beginEditing(on: sender)
    }

    func controlTextDidBeginEditing(_ obj: Notification) {
        guard let searchField = obj.object as? NSSearchField else {
            return
        }

        beginEditing(on: searchField)
    }

    func controlTextDidEndEditing(_ obj: Notification) {
        if committedViaReturn {
            committedViaReturn = false
            return
        }

        cancelEditing(resignFirstResponder: false)
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            if let searchField = control as? NSSearchField {
                commit(using: searchField)
            }
            return true
        }

        if commandSelector == #selector(NSResponder.cancelOperation(_:)) {
            cancelEditing(resignFirstResponder: true)
            return true
        }

        return false
    }

    private var displayLineBreakMode: NSLineBreakMode {
        guard let activeURL, !activeURL.isFileURL else {
            return .byTruncatingMiddle
        }

        return .byTruncatingHead
    }

    private func beginEditing(on searchField: NSSearchField) {
        guard !isEditing else {
            return
        }

        isEditing = true
        let editingText = AddressBarFormatter.editingText(for: activeURL)
        applyEditingText(editingText, to: searchField)

        DispatchQueue.main.async { [weak self, weak searchField] in
            guard let self,
                  let searchField,
                  self.isEditing else {
                return
            }

            self.applyEditingText(editingText, to: searchField)
        }
    }

    private func commit(using searchField: NSSearchField) {
        committedViaReturn = true
        isEditing = false
        onCommit(commitText(for: searchField.stringValue))
        syncText()
    }

    private func cancelEditing(resignFirstResponder: Bool) {
        guard isEditing else {
            return
        }

        isEditing = false
        syncText()

        if resignFirstResponder {
            item.searchField.window?.makeFirstResponder(nil)
        }
    }

    private func syncText() {
        let nextValue = isEditing
            ? AddressBarFormatter.editingText(for: activeURL)
            : AddressBarFormatter.displayText(for: activeURL)

        setFieldText(nextValue)

        if let cell = item.searchField.cell as? NSSearchFieldCell {
            cell.lineBreakMode = isEditing ? .byClipping : displayLineBreakMode
        }
    }

    private func setFieldText(_ value: String) {
        if item.searchField.stringValue != value {
            item.searchField.stringValue = value
        }

        if let editor = item.searchField.currentEditor(), editor.string != value {
            editor.string = value
        }
    }

    private func applyEditingText(_ editingText: String, to searchField: NSSearchField) {
        setFieldText(editingText)

        if let cell = searchField.cell as? NSSearchFieldCell {
            cell.lineBreakMode = .byClipping
        }

        if let editor = searchField.currentEditor() {
            editor.string = editingText
            editor.selectedRange = NSRange(location: 0, length: editor.string.utf16.count)
        }
    }

    private func commitText(for currentValue: String) -> String {
        guard activeURL != nil,
              currentValue == AddressBarFormatter.displayText(for: activeURL) else {
            return currentValue
        }

        return AddressBarFormatter.editingText(for: activeURL)
    }

    private func makeDocumentButtonCell() -> NSButtonCell? {
        guard let image = NSImage(
            systemSymbolName: "doc.text",
            accessibilityDescription: "Document"
        ) else {
            return nil
        }

        let cell = NSButtonCell(imageCell: image)
        cell.bezelStyle = .shadowlessSquare
        cell.imageScaling = .scaleProportionallyDown
        cell.highlightsBy = []
        cell.isBordered = false
        return cell
    }
}
