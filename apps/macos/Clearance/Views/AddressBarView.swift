import AppKit
import SwiftUI

@MainActor
private func makeAddressBarDocumentImage() -> NSImage? {
    NSImage(
        systemSymbolName: "doc.text",
        accessibilityDescription: "Document"
    )
}

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
    var activeFileURL: URL?

    override func mouseDown(with event: NSEvent) {
        // If the mouse went down on the doc icon (the search button cell on the left),
        // track subsequent events to distinguish a click from a drag. A drag initiates
        // a file drag session so the user can drop the open document into Finder, Slack,
        // or any other app that accepts files. A plain click falls through to the normal
        // address-bar focus/edit behaviour.
        if let fileURL = activeFileURL,
           let cell = cell as? NSSearchFieldCell {
            let buttonRect = cell.searchButtonRect(forBounds: bounds)
            let location = convert(event.locationInWindow, from: nil)

            if buttonRect.contains(location) {
                while let next = NSApp.nextEvent(
                    matching: [.leftMouseDragged, .leftMouseUp],
                    until: .distantFuture,
                    inMode: .eventTracking,
                    dequeue: true
                ) {
                    if next.type == .leftMouseUp { break }
                    let dragLoc = convert(next.locationInWindow, from: nil)
                    if hypot(dragLoc.x - location.x, dragLoc.y - location.y) >= 4 {
                        startFileDrag(for: fileURL, from: location, event: event)
                        return
                    }
                }
                // Not a drag — fall through to normal click handling
            }
        }

        onPrimaryInteraction?(self)
        super.mouseDown(with: event)
    }

    private func startFileDrag(for url: URL, from location: CGPoint, event: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: url as NSURL)
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: 32, height: 32)
        item.setDraggingFrame(
            NSRect(x: location.x - 16, y: location.y - 16, width: 32, height: 32),
            contents: icon
        )
        beginDraggingSession(with: [item], event: event, source: self)
    }

    override func becomeFirstResponder() -> Bool {
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if didBecomeFirstResponder {
            onPrimaryInteraction?(self)
        }

        return didBecomeFirstResponder
    }
}

extension AddressBarSearchField: NSDraggingSource {
    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        context == .outsideApplication ? .copy : []
    }
}

@MainActor
final class AddressBarSearchToolbarController: NSObject, NSSearchFieldDelegate {
    static let itemIdentifier = NSToolbarItem.Identifier("clearance.address")
    static let toolbarHeight: CGFloat = 24
    static let preferredWidth: CGFloat = 360

    let item = NSSearchToolbarItem(itemIdentifier: AddressBarSearchToolbarController.itemIdentifier)

    private var activeURL: URL?
    private var onCommit: (String) -> Void = { _ in }
    private var isEditing = false
    private var committedViaReturn = false

    override init() {
        super.init()

        let searchField = AddressBarSearchField()
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
        searchField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        searchField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        applyFieldAppearance(to: searchField)
        item.searchField = searchField
        item.preferredWidthForSearchField = Self.preferredWidth
    }

    func update(
        activeURL: URL?,
        isLoading: Bool,
        onCommit: @escaping (String) -> Void
    ) {
        let didChangeURL = self.activeURL != activeURL
        self.activeURL = activeURL
        self.onCommit = onCommit
        (item.searchField as? AddressBarSearchField)?.activeFileURL = activeURL?.isFileURL == true ? activeURL : nil
        applyFieldAppearance(to: item.searchField)

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

    func applyFieldAppearance(to searchField: NSSearchField) {
        guard let cell = searchField.cell as? NSSearchFieldCell else {
            return
        }

        cell.usesSingleLineMode = true
        guard let buttonCell = cell.searchButtonCell,
              let image = makeDocumentButtonImage() else {
            return
        }

        buttonCell.image = image
        buttonCell.alternateImage = image
        buttonCell.imageScaling = .scaleProportionallyDown
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

    private func makeDocumentButtonImage() -> NSImage? {
        makeAddressBarDocumentImage()
    }
}
