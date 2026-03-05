import AppKit
import SwiftUI
import WebKit

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
    @State private var addressBarText: String = ""
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
                onOpenFile: { openDocumentFromPicker() }
            ) { entry in
                selectRecentEntry(entry)
            } onOpenInNewWindow: { entry in
                popOut(entry: entry)
            }
        } detail: {
            Group {
                if let remoteDoc = viewModel.activeRemoteDocument {
                    let parsed = FrontmatterParser().parse(markdown: remoteDoc.content)
                    HSplitView {
                        RenderedMarkdownView(
                            document: parsed,
                            sourceDocumentURL: remoteDoc.url,
                            headingScrollRequest: headingScrollRequest,
                            theme: appSettings.theme,
                            appearance: appSettings.appearance,
                            isRemoteContent: true,
                            onOpenLinkedDocument: { url in _ = openDocument(url) }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if shouldShowOutline(for: parsed) {
                            MarkdownOutlineView(headings: parsed.headings) { heading in
                                requestScroll(to: heading)
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.snappy(duration: 0.2), value: shouldShowOutline(for: parsed))
                } else if let session = viewModel.activeSession {
                    let parsed = FrontmatterParser().parse(markdown: session.content)
                    HSplitView {
                        DocumentSurfaceView(
                            session: session,
                            parsedDocument: parsed,
                            headingScrollRequest: headingScrollRequest,
                            onOpenLinkedDocument: { linkedURL in
                                _ = openDocument(linkedURL)
                            },
                            theme: appSettings.theme,
                            appearance: appSettings.appearance,
                            mode: $viewModel.mode
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if shouldShowOutline(for: parsed) {
                            MarkdownOutlineView(headings: parsed.headings) { heading in
                                requestScroll(to: heading)
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .animation(.snappy(duration: 0.2), value: shouldShowOutline(for: parsed))
                } else {
                    ContentUnavailableView {
                        Label {
                            Text("Open a Markdown File")
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
                        Text("Choose a file from the sidebar, or open one directly.")
                    } actions: {
                        Button("Open Markdown…") {
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
            .dropDestination(for: String.self) { items, _ in
                guard let path = items.first else {
                    return false
                }

                return popOutDraggedPath(path)
            } isTargeted: { isTargeted in
                isPopOutDropTargeted = isTargeted
            }
            .navigationTitle(viewModel.windowTitle)
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
        .focusedSceneValue(\.workspaceCommandActions, WorkspaceCommandActions(
            openFile: { openDocumentFromPicker() },
            toggleOutline: { if canShowOutlineControls { isOutlineVisible.toggle() } },
            showViewMode: { if viewModel.hasActiveDocument { viewModel.mode = .view } },
            showEditMode: { if viewModel.hasActiveDocument && !viewModel.isActiveDocumentRemote { viewModel.mode = .edit } },
            openInNewWindow: { popOutActiveSession() },
            undoInDocument: { performUndoInDocument() },
            redoInDocument: { performRedoInDocument() },
            goBack: { _ = viewModel.navigateBack() },
            goForward: { _ = viewModel.navigateForward() },
            findInDocument: { performFindInDocument() },
            findPreviousInDocument: { performFindPreviousInDocument() },
            printDocument: { performPrint() },
            hasActiveSession: viewModel.hasActiveDocument,
            isActiveDocumentRemote: viewModel.isActiveDocumentRemote,
            canUndoInDocument: canUndoInDocument,
            canRedoInDocument: canRedoInDocument,
            canGoBack: viewModel.canNavigateBack,
            canGoForward: viewModel.canNavigateForward,
            hasVisibleOutline: isOutlineVisible,
            canShowOutline: canShowOutlineControls
        ))
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button {
                    _ = viewModel.navigateBack()
                } label: {
                    Image(systemName: "chevron.backward")
                }
                .help("Back")
                .disabled(!viewModel.canNavigateBack)

                Button {
                    _ = viewModel.navigateForward()
                } label: {
                    Image(systemName: "chevron.forward")
                }
                .help("Forward")
                .disabled(!viewModel.canNavigateForward)
            }

            ToolbarItem(placement: .principal) {
                AddressBarView(
                    text: $addressBarText,
                    isLoading: viewModel.isLoadingRemoteDocument
                ) { input in
                    openFromAddressBar(input)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                if viewModel.hasActiveDocument && !viewModel.isActiveDocumentRemote {
                    Picker("", selection: $viewModel.mode) {
                        Text("View").tag(WorkspaceMode.view)
                        Text("Edit").tag(WorkspaceMode.edit)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
            }

            ToolbarItem(placement: .primaryAction) {
                if canShowOutlineControls {
                    Button {
                        isOutlineVisible.toggle()
                    } label: {
                        Image(systemName: "sidebar.right")
                    }
                    .help(isOutlineVisible ? "Hide Outline" : "Show Outline")
                }
            }
        }
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
        .onChange(of: viewModel.activeSession?.id) { _, _ in
            headingScrollRequest = nil
            if let session = viewModel.activeSession {
                addressBarText = session.url.path
            }
        }
        .onChange(of: viewModel.activeRemoteDocument?.id) { _, _ in
            if let remoteDoc = viewModel.activeRemoteDocument {
                addressBarText = remoteDoc.url.absoluteString
            }
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
    private func openDocument(_ url: URL, recordNavigation: Bool = true) -> DocumentSession? {
        viewModel.open(url: url, recordNavigation: recordNavigation)
    }

    private func openFromAddressBar(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let url = URL(string: trimmed), url.scheme == "http" || url.scheme == "https" {
            viewModel.openRemote(url: url)
        } else {
            _ = viewModel.open(url: URL(fileURLWithPath: trimmed))
        }
    }

    private func popOut(entry: RecentFileEntry) {
        if let session = popOutSession(for: entry.fileURL) {
            popoutWindowController.openWindow(
                for: session,
                mode: viewModel.mode,
                appSettings: appSettings
            )
        }
    }

    private func selectRecentEntry(_ entry: RecentFileEntry) {
        if entry.isRemote {
            if viewModel.activeRemoteDocument?.url.absoluteString == entry.path {
                viewModel.selectedRecentPath = entry.path
                return
            }
            viewModel.openRemote(url: entry.fileURL)
            return
        }

        let activePath = viewModel.activeSession?.url.standardizedFileURL.path
        if activePath == entry.path {
            viewModel.selectedRecentPath = entry.path
            return
        }

        _ = viewModel.open(recentEntry: entry)
    }

    private func popOutDraggedPath(_ path: String) -> Bool {
        if let entry = viewModel.recentFilesStore.entries.first(where: { $0.path == path }) {
            popOut(entry: entry)
            return true
        }

        guard let session = popOutSession(for: URL(fileURLWithPath: path)) else {
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
        guard viewModel.mode == .view else { return false }
        if let remoteDoc = viewModel.activeRemoteDocument {
            return !FrontmatterParser().parse(markdown: remoteDoc.content).headings.isEmpty
        }
        guard let session = viewModel.activeSession else { return false }
        return !FrontmatterParser().parse(markdown: session.content).headings.isEmpty
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
        let parsed: ParsedMarkdownDocument
        let baseURL: URL
        let isRemote: Bool

        if let remoteDoc = viewModel.activeRemoteDocument {
            parsed = FrontmatterParser().parse(markdown: remoteDoc.content)
            baseURL = remoteDoc.url.deletingLastPathComponent()
            isRemote = true
        } else if let session = viewModel.activeSession {
            parsed = FrontmatterParser().parse(markdown: session.content)
            baseURL = session.url.deletingLastPathComponent()
            isRemote = false
        } else {
            return false
        }

        let html = RenderedHTMLBuilder().build(
            document: parsed,
            theme: appSettings.theme,
            appearance: appSettings.appearance,
            isRemoteContent: isRemote
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
        .overlay(alignment: .leading) {
            Divider()
        }
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
