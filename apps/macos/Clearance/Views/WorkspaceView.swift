import AppKit
import SwiftUI
import WebKit

enum WorkspaceDropPayloadResolver {
    static func recentEntry(for droppedURL: URL, in entries: [RecentFileEntry]) -> RecentFileEntry? {
        let storageKey = RecentFileEntry.storageKey(for: droppedURL)
        return entries.first { $0.path == storageKey }
    }
}

struct WorkspaceView: View {
    @ObservedObject private var appSettings: AppSettings
    @StateObject private var viewModel: WorkspaceViewModel
    @StateObject private var interactionState = WorkspaceInteractionState()
    @State private var isPopOutDropTargeted = false
    @State private var isOutlineVisible = true
    @State private var renderedFindQuery = ""
    @State private var isRenderedSearchPresented = false
    @State private var headingScrollSequence = 0
    @State private var headingScrollRequest: HeadingScrollRequest?
    private let showToolbarLayoutDebug = false
    private let popoutWindowController: PopoutWindowController

    init(
        appSettings: AppSettings = AppSettings(),
        popoutWindowController: PopoutWindowController = PopoutWindowController()
    ) {
        _appSettings = ObservedObject(wrappedValue: appSettings)
        _viewModel = StateObject(wrappedValue: WorkspaceViewModel(appSettings: appSettings))
        self.popoutWindowController = popoutWindowController
    }

    var body: some View {
        NavigationSplitView {
            RecentFilesSidebar(
                entries: viewModel.recentFilesStore.entries,
                selectedPath: $viewModel.selectedRecentPath,
                onOpenFile: { openDocumentFromPicker() },
                onDropURL: { handleSidebarDrop($0) }
            ) { entry in
                selectRecentEntry(entry)
            } onOpenInNewWindow: { entry in
                popOut(entry: entry)
            } onRemoveFromSidebar: { entry in
                removeRecentEntry(entry)
            }
        } detail: {
            Group {
                if let session = viewModel.activeSession {
                    let parsed = FrontmatterParser().parse(markdown: session.content)
                    OutlineSplitView(showsInspector: shouldShowOutline(for: parsed)) {
                        DocumentSurfaceView(
                            session: session,
                            parsedDocument: parsed,
                            headingScrollRequest: headingScrollRequest,
                            onOpenLinkedDocument: { linkedURL in
                                _ = openDocument(linkedURL)
                            },
                            theme: appSettings.theme,
                            appearance: appSettings.appearance,
                            textScale: appSettings.renderedTextScale,
                            mode: $viewModel.mode
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } inspector: {
                        MarkdownOutlineView(headings: parsed.headings) { heading in
                            requestScroll(to: heading)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let remoteDocument = viewModel.activeRemoteDocument {
                    let parsed = FrontmatterParser().parse(markdown: remoteDocument.content)
                    OutlineSplitView(showsInspector: shouldShowOutline(for: parsed)) {
                        RenderedMarkdownView(
                            document: parsed,
                            sourceDocumentURL: remoteDocument.renderURL,
                            isRemoteContent: true,
                            headingScrollRequest: headingScrollRequest,
                            theme: appSettings.theme,
                            appearance: appSettings.appearance,
                            textScale: appSettings.renderedTextScale,
                            onOpenLinkedDocument: { linkedURL in
                                _ = openDocument(linkedURL)
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } inspector: {
                        MarkdownOutlineView(headings: parsed.headings) { heading in
                            requestScroll(to: heading)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView {
                        Label {
                            Text("Open a Markdown File or Folder")
                        } icon: {
                            Group {
                                if let appIcon = NSApp.applicationIconImage {
                                    Image(nsImage: appIcon)
                                        .resizable()
                                        .interpolation(.high)
                                        .frame(width: 64, height: 64)
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                } else {
                                    Image(systemName: "doc.text")
                                }
                            }
                        }
                    } description: {
                        Text("Choose an item from History, or open one directly.")
                    } actions: {
                        Button("Open…") {
                            openDocumentFromPicker()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.leading, 1)
            .overlay(alignment: .topTrailing) {
                if isPopOutDropTargeted {
                    Label("Drop To Pop Out", systemImage: "arrow.up.forward.square")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.thinMaterial, in: Capsule())
                        .padding(12)
                }
            }
            .dropDestination(for: URL.self) { items, _ in
                guard let url = items.first else {
                    return false
                }

                return popOutDraggedURL(url)
            } isTargeted: { isTargeted in
                isPopOutDropTargeted = isTargeted
            }
            .alert("File Changed On Disk", isPresented: Binding(
                get: { viewModel.externalChangeDocumentName != nil },
                set: { _ in }
            ), actions: {
                Button("Reload") {
                    viewModel.reloadActiveFromDisk()
                }
                Button("Keep Current", role: .cancel) {
                    viewModel.keepCurrentVersionAfterExternalChange()
                }
            }, message: {
                Text("“\(viewModel.externalChangeDocumentName ?? "This file")” changed outside Clearance.")
            })
        }
        .focusedSceneValue(\.workspaceCommandActions, workspaceCommandActions)
        .toolbarRole(.editor)
        .toolbar {
            ToolbarItem(id: "clearance.back", placement: .navigation) {
                Button {
                    _ = viewModel.navigateBack()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .toolbarDebugFrame(enabled: showToolbarLayoutDebug, color: .red)
                .help("Back")
                .disabled(!viewModel.canNavigateBack)
            }

            ToolbarItem(id: "clearance.forward", placement: .navigation) {
                Button {
                    _ = viewModel.navigateForward()
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .toolbarDebugFrame(enabled: showToolbarLayoutDebug, color: .orange)
                .help("Forward")
                .disabled(!viewModel.canNavigateForward)
            }

            ToolbarItem(id: "clearance.address", placement: .navigation) {
                AddressBarView(
                    activeURL: viewModel.activeDocumentURL,
                    isLoading: viewModel.isLoadingRemoteDocument
                ) { rawValue in
                    openDocumentFromAddressBar(rawValue)
                }
                .toolbarDebugFrame(enabled: showToolbarLayoutDebug, color: .blue)
            }

            ToolbarItem(id: "clearance.mode", placement: .primaryAction) {
                if viewModel.activeSession != nil {
                    Picker("", selection: $viewModel.mode) {
                        Text("View").tag(WorkspaceMode.view)
                        Text("Edit").tag(WorkspaceMode.edit)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .toolbarDebugFrame(enabled: showToolbarLayoutDebug, color: .green)
                }
            }

            ToolbarItem(id: "clearance.outline", placement: .primaryAction) {
                if canShowOutlineControls {
                    Button {
                        isOutlineVisible.toggle()
                    } label: {
                        Image(systemName: "sidebar.right")
                    }
                    .toolbarDebugFrame(enabled: showToolbarLayoutDebug, color: .purple)
                    .help(isOutlineVisible ? "Hide Outline" : "Show Outline")
                }
            }
        }
        .background(WindowToolbarPriorityConfigurator(
            activeURL: viewModel.activeDocumentURL,
            isLoading: viewModel.isLoadingRemoteDocument,
            onCommit: openDocumentFromAddressBar
        ))
        .searchable(
            text: $renderedFindQuery,
            isPresented: $isRenderedSearchPresented,
            placement: .toolbar,
            prompt: "Find in Document"
        )
        .onSubmit(of: .search) {
            if viewModel.mode == .view {
                performRenderedSearch(for: renderedFindQuery, backwards: false)
            }
        }
        .onChange(of: renderedFindQuery) { _, newValue in
            if viewModel.mode == .view {
                performRenderedSearch(for: newValue, backwards: false)
            }
        }
        .onChange(of: viewModel.mode) { _, mode in
            if mode != .view {
                isRenderedSearchPresented = false
            }
        }
        .onChange(of: viewModel.activeDocumentURL) { _, _ in
            headingScrollRequest = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearanceOpenURLs)) { notification in
            guard let urls = notification.object as? [URL],
                  let firstURL = urls.first else {
                return
            }

            _ = openDocument(firstURL)
        }
        .alert("Could Not Open File", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.errorMessage = nil
                }
            }
        ), actions: {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        }, message: {
            Text(viewModel.errorMessage ?? "")
        })
        .alert(
            "Add \(viewModel.pendingFolderImport?.urls.count ?? 0) Files To History?",
            isPresented: Binding(
                get: { viewModel.pendingFolderImport != nil },
                set: { isPresented in
                    if !isPresented {
                        viewModel.cancelPendingFolderImport()
                    }
                }
            )
        ) {
            Button("Add Files") {
                _ = viewModel.confirmPendingFolderImport()
            }
            Button("Cancel", role: .cancel) {
                viewModel.cancelPendingFolderImport()
            }
        } message: {
            Text("This folder contains more than 10 supported files.")
        }
    }

    private func popOutActiveSession() {
        guard let session = viewModel.activeSession else {
            return
        }

        popoutWindowController.openWindow(
            for: session,
            mode: viewModel.mode,
            appSettings: appSettings
        )
    }

    @discardableResult
    private func openDocumentFromPicker() -> DocumentSession? {
        viewModel.promptAndOpenFile()
    }

    @discardableResult
    private func createNewDocument() -> DocumentSession? {
        viewModel.promptAndCreateNewDocument()
    }

    private func handleSidebarDrop(_ url: URL) -> Bool {
        if let values = try? url.resourceValues(forKeys: [.isDirectoryKey]), values.isDirectory == true {
            _ = viewModel.openPickedItem(url)
            return true
        }

        return openDocument(url) != nil
    }

    @discardableResult
    private func openDocument(_ url: URL, recordNavigation: Bool = true) -> DocumentSession? {
        if recordNavigation {
            return viewModel.openPickedItem(url)
        }

        return viewModel.open(url: url, recordNavigation: false)
    }

    private func openDocumentFromAddressBar(_ rawInput: String) {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        guard let url = parseAddressBarURL(trimmed) else {
            viewModel.errorMessage = "Could not parse address: \(trimmed)"
            return
        }

        _ = openDocument(url)
    }

    private func parseAddressBarURL(_ input: String) -> URL? {
        AddressBarInputParser.parse(input)
    }

    private func popOut(entry: RecentFileEntry) {
        guard entry.fileURL.isFileURL else {
            viewModel.errorMessage = "Open In New Window is only available for local files."
            return
        }

        if let session = popOutSession(for: entry.fileURL) {
            popoutWindowController.openWindow(
                for: session,
                mode: viewModel.mode,
                appSettings: appSettings
            )
        }
    }

    private func selectRecentEntry(_ entry: RecentFileEntry) {
        let activePath = viewModel.activeDocumentURL.map(RecentFileEntry.storageKey(for:))
        if activePath == entry.path {
            viewModel.selectedRecentPath = entry.path
            return
        }

        _ = viewModel.open(recentEntry: entry)
    }

    private func removeRecentEntry(_ entry: RecentFileEntry) {
        viewModel.removeRecentEntry(path: entry.path)
    }

    private func popOutDraggedURL(_ url: URL) -> Bool {
        if let entry = WorkspaceDropPayloadResolver.recentEntry(
            for: url,
            in: viewModel.recentFilesStore.entries
        ) {
            popOut(entry: entry)
            return true
        }

        guard let session = popOutSession(for: url) else {
            return false
        }

        popoutWindowController.openWindow(
            for: session,
            mode: viewModel.mode,
            appSettings: appSettings
        )
        return true
    }

    private func popOutSession(for url: URL) -> DocumentSession? {
        guard url.isFileURL else {
            viewModel.errorMessage = "Open In New Window is only available for local files."
            return nil
        }

        let standardizedURL = url.standardizedFileURL
        do {
            let session = try DocumentSession(url: standardizedURL)
            viewModel.recentFilesStore.add(url: standardizedURL)
            return session
        } catch {
            viewModel.errorMessage = "Failed to open \(standardizedURL.path): \(error.localizedDescription)"
            return nil
        }
    }

    private func requestScroll(to heading: MarkdownHeading) {
        headingScrollSequence += 1
        headingScrollRequest = HeadingScrollRequest(
            headingIndex: heading.index,
            sequence: headingScrollSequence
        )
    }

    private func shouldShowOutline(for parsed: ParsedMarkdownDocument) -> Bool {
        isOutlineVisible && viewModel.mode == .view && !parsed.headings.isEmpty
    }

    private var canShowOutlineControls: Bool {
        guard viewModel.mode == .view,
              let markdown = activeMarkdownContent else {
            return false
        }

        let parsed = FrontmatterParser().parse(markdown: markdown)
        return !parsed.headings.isEmpty
    }

    private var activeMarkdownContent: String? {
        if let session = viewModel.activeSession {
            return session.content
        }

        if let remoteDocument = viewModel.activeRemoteDocument {
            return remoteDocument.content
        }

        return nil
    }

    private var workspaceCommandActions: WorkspaceCommandActions {
        WorkspaceCommandActions(
            newFile: { createNewDocument() },
            openFile: { openDocumentFromPicker() },
            toggleOutline: { if canShowOutlineControls { isOutlineVisible.toggle() } },
            showViewMode: { if viewModel.hasActiveDocument { viewModel.mode = .view } },
            showEditMode: { if viewModel.activeSession != nil { viewModel.mode = .edit } },
            openInNewWindow: { popOutActiveSession() },
            undoInDocument: { performUndoInDocument() },
            redoInDocument: { performRedoInDocument() },
            goBack: { _ = viewModel.navigateBack() },
            goForward: { _ = viewModel.navigateForward() },
            findInDocument: { performFindInDocument() },
            findPreviousInDocument: { performFindPreviousInDocument() },
            printDocument: { performPrint() },
            hasActiveDocument: viewModel.hasActiveDocument,
            hasActiveSession: viewModel.activeSession != nil,
            canUndoInDocument: canUndoInDocument,
            canRedoInDocument: canRedoInDocument,
            canGoBack: viewModel.canNavigateBack,
            canGoForward: viewModel.canNavigateForward,
            hasVisibleOutline: isOutlineVisible,
            canShowOutline: canShowOutlineControls,
            makeTextBigger: { makeTextBigger() },
            makeTextSmaller: { makeTextSmaller() },
            resetTextSize: { resetTextSize() },
            canZoomText: canZoomText
        )
    }

    private func performFindInDocument() -> Bool {
        if viewModel.mode == .view {
            isRenderedSearchPresented = true
            if !renderedFindQuery.isEmpty {
                performRenderedSearch(for: renderedFindQuery, backwards: false)
            }
            return true
        }

        let findMenuItem = NSMenuItem()
        findMenuItem.tag = NSTextFinder.Action.showFindInterface.rawValue
        if NSApp.sendAction(#selector(NSResponder.performTextFinderAction(_:)), to: nil, from: findMenuItem) {
            return true
        }

        let legacyFindMenuItem = NSMenuItem()
        legacyFindMenuItem.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        return NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: legacyFindMenuItem)
    }

    private func performFindPreviousInDocument() -> Bool {
        if viewModel.mode == .view {
            isRenderedSearchPresented = true
            if !renderedFindQuery.isEmpty {
                performRenderedSearch(for: renderedFindQuery, backwards: true)
            }
            return true
        }

        let findMenuItem = NSMenuItem()
        findMenuItem.tag = NSTextFinder.Action.previousMatch.rawValue
        return NSApp.sendAction(#selector(NSResponder.performTextFinderAction(_:)), to: nil, from: findMenuItem)
    }

    private func performPrint() -> Bool {
        let markdown: String
        let baseURL: URL

        if let session = viewModel.activeSession {
            markdown = session.content
            baseURL = session.url.deletingLastPathComponent()
        } else if let remoteDocument = viewModel.activeRemoteDocument {
            markdown = remoteDocument.content
            baseURL = remoteDocument.renderURL.deletingLastPathComponent()
        } else {
            return false
        }

        let parsed = FrontmatterParser().parse(markdown: markdown)
        let html = RenderedHTMLBuilder().buildPrintHTML(
            document: parsed,
            theme: appSettings.theme,
            textScale: appSettings.renderedTextScale
        )
        let state = interactionState
        state.printJob = RenderedDocumentPrintJob(
            html: html,
            baseURL: baseURL
        ) { [weak state] in
            state?.printJob = nil
        }
        return true
    }

    private func performUndoInDocument() -> Bool {
        guard viewModel.mode == .edit,
              let textView = activeEditorTextView(),
              let undoManager = textView.undoManager,
              undoManager.canUndo else {
            return false
        }

        undoManager.undo()
        return true
    }

    private func performRedoInDocument() -> Bool {
        guard viewModel.mode == .edit,
              let textView = activeEditorTextView(),
              let undoManager = textView.undoManager,
              undoManager.canRedo else {
            return false
        }

        undoManager.redo()
        return true
    }

    private var canUndoInDocument: Bool {
        guard viewModel.mode == .edit,
              let textView = activeEditorTextView(),
              let undoManager = textView.undoManager else {
            return false
        }

        return undoManager.canUndo
    }

    private var canRedoInDocument: Bool {
        guard viewModel.mode == .edit,
              let textView = activeEditorTextView(),
              let undoManager = textView.undoManager else {
            return false
        }

        return undoManager.canRedo
    }

    private func activeEditorTextView() -> EditorTextView? {
        guard let keyWindow = NSApp.keyWindow,
              let contentView = keyWindow.contentView else {
            return nil
        }

        return contentView.firstDescendant(ofType: EditorTextView.self)
    }

    private func activeRenderedWebView() -> WKWebView? {
        guard let keyWindow = NSApp.keyWindow,
              let contentView = keyWindow.contentView else {
            return nil
        }

        return contentView.firstDescendant(ofType: WKWebView.self)
    }

    private func makeTextBigger() {
        setRenderedTextScale(appSettings.renderedTextScale + 0.1)
    }

    private func makeTextSmaller() {
        setRenderedTextScale(appSettings.renderedTextScale - 0.1)
    }

    private func resetTextSize() {
        appSettings.renderedTextScale = 1.0
    }

    private func setRenderedTextScale(_ value: Double) {
        let clampedValue = min(max(value, 0.7), 1.5)
        appSettings.renderedTextScale = (clampedValue * 10).rounded() / 10
    }

    private var canZoomText: Bool {
        viewModel.hasActiveDocument && viewModel.mode == .view
    }

    private func performRenderedSearch(for rawQuery: String, backwards: Bool) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty,
              let webView = activeRenderedWebView() else {
            return
        }

        if #available(macOS 12.0, *) {
            let configuration = WKFindConfiguration()
            configuration.backwards = backwards
            configuration.wraps = true
            webView.find(query, configuration: configuration) { _ in }
        } else {
            let escapedQuery = query
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
            webView.evaluateJavaScript("window.find(\"\(escapedQuery)\", false, \(backwards ? "true" : "false"), true, false, false, false);")
        }
    }
}

private struct ToolbarDebugFrameModifier: ViewModifier {
    let enabled: Bool
    let color: Color

    func body(content: Content) -> some View {
        if enabled {
            content
                .padding(.horizontal, 1)
                .background(color.opacity(0.14))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(color, lineWidth: 1)
                )
        } else {
            content
        }
    }
}

private extension View {
    func toolbarDebugFrame(enabled: Bool, color: Color) -> some View {
        modifier(ToolbarDebugFrameModifier(enabled: enabled, color: color))
    }
}

private struct WindowToolbarPriorityConfigurator: NSViewRepresentable {
    let activeURL: URL?
    let isLoading: Bool
    let onCommit: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configureToolbar(from: view, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureToolbar(from: nsView, coordinator: context.coordinator)
        }
    }

    private func configureToolbar(from view: NSView, coordinator: Coordinator) {
        guard let window = view.window,
              let toolbar = window.toolbar else {
            return
        }

        window.titleVisibility = .hidden
        installAddressToolbarItemIfNeeded(on: toolbar, coordinator: coordinator)

        for item in toolbar.items {
            switch item.itemIdentifier.rawValue {
            case "clearance.back", "clearance.forward", "clearance.mode", "clearance.outline":
                item.visibilityPriority = .high
            case "clearance.address":
                item.visibilityPriority = .standard
                configureAddressItem(item, coordinator: coordinator)
            default:
                break
            }
        }
    }

    private func configureAddressItem(_ item: NSToolbarItem, coordinator: Coordinator) {
        if let searchItem = item as? NSSearchToolbarItem {
            coordinator.addressBarController.applyFieldAppearance(to: searchItem.searchField)
        }

        coordinator.addressBarController.update(
            activeURL: activeURL,
            isLoading: isLoading,
            onCommit: onCommit
        )
        item.visibilityPriority = .standard
    }

    private func installAddressToolbarItemIfNeeded(on toolbar: NSToolbar, coordinator: Coordinator) {
        let toolbarID = ObjectIdentifier(toolbar)

        if !(toolbar.delegate is ToolbarDelegateProxy),
           let originalDelegate = toolbar.delegate as? NSObject {
            let proxy = ToolbarDelegateProxy(
                originalDelegate: originalDelegate,
                addressItemProvider: { coordinator.addressBarController.item }
            )
            coordinator.toolbarDelegateProxies[toolbarID] = proxy
            toolbar.delegate = proxy
        }

        guard let addressIndex = toolbar.items.firstIndex(where: {
            $0.itemIdentifier == AddressBarSearchToolbarController.itemIdentifier
        }) else {
            return
        }

        if toolbar.items[addressIndex] is NSSearchToolbarItem {
            return
        }

        toolbar.removeItem(at: addressIndex)
        toolbar.insertItem(
            withItemIdentifier: AddressBarSearchToolbarController.itemIdentifier,
            at: addressIndex
        )
    }

    @MainActor
    final class Coordinator {
        let addressBarController = AddressBarSearchToolbarController()
        var toolbarDelegateProxies: [ObjectIdentifier: ToolbarDelegateProxy] = [:]
    }
}

private final class ToolbarDelegateProxy: NSObject, NSToolbarDelegate {
    private let originalDelegate: NSObject
    private let addressItemProvider: () -> NSToolbarItem

    init(
        originalDelegate: NSObject,
        addressItemProvider: @escaping () -> NSToolbarItem
    ) {
        self.originalDelegate = originalDelegate
        self.addressItemProvider = addressItemProvider
    }

    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || originalDelegate.responds(to: aSelector)
    }

    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if originalDelegate.responds(to: aSelector) {
            return originalDelegate
        }

        return super.forwardingTarget(for: aSelector)
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        if itemIdentifier == AddressBarSearchToolbarController.itemIdentifier {
            return addressItemProvider()
        }

        let selector = #selector(
            NSToolbarDelegate.toolbar(_:itemForItemIdentifier:willBeInsertedIntoToolbar:)
        )

        guard originalDelegate.responds(to: selector) else {
            return nil
        }

        typealias Method = @convention(c) (
            AnyObject,
            Selector,
            NSToolbar,
            NSToolbarItem.Identifier,
            Bool
        ) -> NSToolbarItem?

        let implementation = originalDelegate.method(for: selector)
        return unsafeBitCast(implementation, to: Method.self)(
            originalDelegate,
            selector,
            toolbar,
            itemIdentifier,
            flag
        )
    }
}

struct MarkdownOutlineView: View {
    let headings: [MarkdownHeading]
    let onSelectHeading: (MarkdownHeading) -> Void
    @State private var selectedHeadingID: MarkdownHeading.ID?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 3) {
                ForEach(headings) { heading in
                    Button {
                        selectedHeadingID = heading.id
                        onSelectHeading(heading)
                    } label: {
                        Text(heading.title)
                            .lineLimit(1)
                            .padding(.leading, CGFloat(max(0, heading.level - 1)) * 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(heading.title)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(selectionBackgroundColor(for: heading.id))
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
    }

    private func selectionBackgroundColor(for headingID: MarkdownHeading.ID) -> Color {
        if selectedHeadingID == headingID {
            return Color.accentColor.opacity(0.18)
        }

        return Color.clear
    }
}

private extension NSView {
    func firstDescendant<T: NSView>(ofType type: T.Type) -> T? {
        if let match = self as? T {
            return match
        }

        for subview in subviews {
            if let match = subview.firstDescendant(ofType: type) {
                return match
            }
        }

        return nil
    }
}

@MainActor
private final class WorkspaceInteractionState: ObservableObject {
    var printJob: RenderedDocumentPrintJob?
}

@MainActor
private final class RenderedDocumentPrintJob: NSObject, WKNavigationDelegate {
    private let webView: WKWebView
    private let completion: () -> Void
    private var hasCompleted = false

    init(html: String, baseURL: URL, completion: @escaping () -> Void) {
        self.webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 960, height: 1200))
        self.completion = completion
        super.init()

        webView.navigationDelegate = self
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let printOperation = webView.printOperation(with: NSPrintInfo.shared)
        printOperation.showsPrintPanel = true
        printOperation.showsProgressPanel = true
        _ = printOperation.run()
        completeIfNeeded()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completeIfNeeded()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        completeIfNeeded()
    }

    private func completeIfNeeded() {
        guard !hasCompleted else {
            return
        }

        hasCompleted = true
        completion()
    }
}
