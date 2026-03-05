import SwiftUI

struct WorkspaceView: View {
    @StateObject private var viewModel: WorkspaceViewModel
    @State private var isPopOutDropTargeted = false
    private let popoutWindowController: PopoutWindowController

    init(
        appSettings: AppSettings = AppSettings(),
        popoutWindowController: PopoutWindowController = PopoutWindowController()
    ) {
        _viewModel = StateObject(wrappedValue: WorkspaceViewModel(appSettings: appSettings))
        self.popoutWindowController = popoutWindowController
    }

    var body: some View {
        NavigationSplitView {
            RecentFilesSidebar(
                entries: viewModel.recentFilesStore.entries,
                selectedPath: $viewModel.selectedRecentPath
            ) { entry in
                selectRecentEntry(entry)
            } onOpenInNewWindow: { entry in
                popOut(entry: entry)
            }
        } detail: {
            Group {
                if let session = viewModel.activeSession {
                    DocumentSurfaceView(session: session, mode: $viewModel.mode)
                } else {
                    ContentUnavailableView("Open a Markdown File", systemImage: "doc.text")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            openFile: { viewModel.promptAndOpenFile() },
            showViewMode: { if viewModel.activeSession != nil { viewModel.mode = .view } },
            showEditMode: { if viewModel.activeSession != nil { viewModel.mode = .edit } },
            openInNewWindow: { popOutActiveSession() },
            hasActiveSession: viewModel.activeSession != nil
        ))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Mode", selection: $viewModel.mode) {
                    Label("View", systemImage: "doc.text.magnifyingglass").tag(WorkspaceMode.view)
                    Label("Edit", systemImage: "square.and.pencil").tag(WorkspaceMode.edit)
                }
                .pickerStyle(.segmented)
                .controlSize(.regular)
                .fixedSize()
                .disabled(viewModel.activeSession == nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .clearanceOpenURLs)) { notification in
            guard let urls = notification.object as? [URL],
                  let firstURL = urls.first else {
                return
            }

            viewModel.open(url: firstURL)
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

        popoutWindowController.openWindow(for: session, mode: viewModel.mode)
    }

    private func popOut(entry: RecentFileEntry) {
        if let session = viewModel.open(recentEntry: entry) {
            popoutWindowController.openWindow(for: session, mode: viewModel.mode)
        }
    }

    private func selectRecentEntry(_ entry: RecentFileEntry) {
        let activePath = viewModel.activeSession?.url.standardizedFileURL.path
        if activePath == entry.path {
            viewModel.selectedRecentPath = entry.path
            return
        }

        viewModel.open(recentEntry: entry)
    }

    private func popOutDraggedPath(_ path: String) -> Bool {
        if let entry = viewModel.recentFilesStore.entries.first(where: { $0.path == path }) {
            popOut(entry: entry)
            return true
        }

        let url = URL(fileURLWithPath: path)
        guard let session = viewModel.open(url: url) else {
            return false
        }

        popoutWindowController.openWindow(for: session, mode: viewModel.mode)
        return true
    }
}
