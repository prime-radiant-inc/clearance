import AppKit
import SwiftUI

@main
struct ClearanceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appSettings: AppSettings
    @State private var hasCheckedForUpdatedReleaseNotes = false
    private let sparkleUpdateController = SparkleUpdateController()
    private let popoutWindowController = PopoutWindowController()

    init() {
        LegacyDefaultsMigration().migrateIfNeeded()
        _appSettings = StateObject(wrappedValue: AppSettings())
    }

    var body: some Scene {
        WindowGroup {
            WorkspaceView(
                appSettings: appSettings,
                popoutWindowController: popoutWindowController
            )
            .preferredColorScheme(preferredColorScheme)
            .onAppear {
                showUpdatedReleaseNotesIfNeeded()
            }
            .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        }
        .windowToolbarStyle(.unified)
        .commands {
            ClearanceCommands(
                sparkleUpdateController: sparkleUpdateController,
                showReleaseNotes: { showReleaseNotes() }
            )
        }

        Settings {
            SettingsView(settings: appSettings)
                .preferredColorScheme(preferredColorScheme)
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appSettings.appearance {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    private func showUpdatedReleaseNotesIfNeeded() {
        guard !hasCheckedForUpdatedReleaseNotes else {
            return
        }

        hasCheckedForUpdatedReleaseNotes = true

        let catalog = ReleaseNotesCatalog()
        guard let releaseNotesURL = catalog.documentURL,
              let currentVersion = catalog.currentVersion,
              appSettings.releaseNotesVersionToPresent(currentVersion: currentVersion) != nil else {
            return
        }

        DispatchQueue.main.async {
            requestDocumentOpen(releaseNotesURL)
        }
    }

    private func showReleaseNotes() {
        let catalog = ReleaseNotesCatalog()
        guard let releaseNotesURL = catalog.documentURL else {
            return
        }

        requestDocumentOpen(releaseNotesURL)
    }

    private func requestDocumentOpen(_ url: URL) {
        NotificationCenter.default.post(name: .clearanceOpenURLs, object: [url])
    }
}

struct WorkspaceCommandActions {
    let newFile: () -> Void
    let openFile: () -> Void
    let toggleOutline: () -> Void
    let showViewMode: () -> Void
    let showEditMode: () -> Void
    let openInNewWindow: () -> Void
    let undoInDocument: () -> Bool
    let redoInDocument: () -> Bool
    let goBack: () -> Void
    let goForward: () -> Void
    let findInDocument: () -> Bool
    let findPreviousInDocument: () -> Bool
    let printDocument: () -> Bool
    let hasActiveDocument: Bool
    let hasActiveSession: Bool
    let canUndoInDocument: Bool
    let canRedoInDocument: Bool
    let canGoBack: Bool
    let canGoForward: Bool
    let hasVisibleOutline: Bool
    let canShowOutline: Bool
    let makeTextBigger: () -> Void
    let makeTextSmaller: () -> Void
    let resetTextSize: () -> Void
    let canZoomText: Bool
}

struct RenderedTextZoomCommand {
    let title: String
    let keyEquivalent: KeyEquivalent
    let modifiers: EventModifiers
}

enum NewDocumentCommand {
    static let title = "New…"
    static let keyEquivalent: KeyEquivalent = "n"
    static let modifiers: EventModifiers = .command
}

enum RenderedTextZoomCommands {
    static let actualSize = RenderedTextZoomCommand(
        title: "Actual Size",
        keyEquivalent: "0",
        modifiers: .command
    )

    static let zoomIn = RenderedTextZoomCommand(
        title: "Zoom In",
        keyEquivalent: "=",
        modifiers: .command
    )

    static let zoomOut = RenderedTextZoomCommand(
        title: "Zoom Out",
        keyEquivalent: "-",
        modifiers: .command
    )
}

private struct WorkspaceCommandActionsKey: FocusedValueKey {
    typealias Value = WorkspaceCommandActions
}

extension FocusedValues {
    var workspaceCommandActions: WorkspaceCommandActions? {
        get { self[WorkspaceCommandActionsKey.self] }
        set { self[WorkspaceCommandActionsKey.self] = newValue }
    }
}

private struct ClearanceCommands: Commands {
    @FocusedValue(\.workspaceCommandActions) private var actions
    private let sparkleUpdateController: SparkleUpdateController
    private let showReleaseNotes: () -> Void

    init(
        sparkleUpdateController: SparkleUpdateController,
        showReleaseNotes: @escaping () -> Void
    ) {
        self.sparkleUpdateController = sparkleUpdateController
        self.showReleaseNotes = showReleaseNotes
    }

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Clearance") {
                showAboutPanel()
            }
        }

        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {
                sparkleUpdateController.checkForUpdates()
            }
            .disabled(!sparkleUpdateController.canCheckForUpdates)

            Button("Show Release Notes") {
                showReleaseNotes()
            }
        }

        CommandGroup(replacing: .newItem) {
            Button(NewDocumentCommand.title) {
                actions?.newFile()
            }
            .keyboardShortcut(
                NewDocumentCommand.keyEquivalent,
                modifiers: NewDocumentCommand.modifiers
            )
            .disabled(actions == nil)

            Button("Open…") {
                actions?.openFile()
            }
            .keyboardShortcut("o")
            .disabled(actions == nil)

            Button("Open In New Window") {
                actions?.openInNewWindow()
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])
            .disabled(actions?.hasActiveSession != true)
        }

        CommandGroup(replacing: .printItem) {
            Button("Print…") {
                if let printDocument = actions?.printDocument {
                    _ = printDocument()
                } else {
                    _ = performPrint()
                }
            }
            .keyboardShortcut("p")
            .disabled(actions?.hasActiveDocument != true)
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                if let undoInDocument = actions?.undoInDocument {
                    if !undoInDocument() {
                        _ = performUndo()
                    }
                } else {
                    _ = performUndo()
                }
            }
            .keyboardShortcut("z")
            .disabled(actions?.canUndoInDocument != true)

            Button("Redo") {
                if let redoInDocument = actions?.redoInDocument {
                    if !redoInDocument() {
                        _ = performRedo()
                    }
                } else {
                    _ = performRedo()
                }
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(actions?.canRedoInDocument != true)
        }

        CommandMenu("Navigate") {
            Button("Back") {
                actions?.goBack()
            }
            .keyboardShortcut("[")
            .disabled(actions?.canGoBack != true)

            Button("Forward") {
                actions?.goForward()
            }
            .keyboardShortcut("]")
            .disabled(actions?.canGoForward != true)
        }

        CommandGroup(after: .textEditing) {
            Divider()

            Button("Find…") {
                if let findInDocument = actions?.findInDocument {
                    if !findInDocument() {
                        _ = performFind()
                    }
                } else {
                    _ = performFind()
                }
            }
            .keyboardShortcut("f")
            .disabled(actions?.hasActiveDocument != true)

            Button("Find Previous") {
                if let findPreviousInDocument = actions?.findPreviousInDocument {
                    if !findPreviousInDocument() {
                        _ = performFindPrevious()
                    }
                } else {
                    _ = performFindPrevious()
                }
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(actions?.hasActiveDocument != true)
        }

        CommandGroup(after: .sidebar) {
            Button("View Mode") {
                actions?.showViewMode()
            }
            .keyboardShortcut("1")
            .disabled(actions?.hasActiveDocument != true)

            Button("Edit Mode") {
                actions?.showEditMode()
            }
            .keyboardShortcut("2")
            .disabled(actions?.hasActiveSession != true)

            Divider()

            Button(actions?.hasVisibleOutline == true ? "Hide Outline" : "Show Outline") {
                actions?.toggleOutline()
            }
            .disabled(actions?.canShowOutline != true)

            Divider()

            Button(RenderedTextZoomCommands.actualSize.title) {
                actions?.resetTextSize()
            }
            .keyboardShortcut(
                RenderedTextZoomCommands.actualSize.keyEquivalent,
                modifiers: RenderedTextZoomCommands.actualSize.modifiers
            )
            .disabled(actions?.canZoomText != true)

            Button(RenderedTextZoomCommands.zoomIn.title) {
                actions?.makeTextBigger()
            }
            .keyboardShortcut(
                RenderedTextZoomCommands.zoomIn.keyEquivalent,
                modifiers: RenderedTextZoomCommands.zoomIn.modifiers
            )
            .disabled(actions?.canZoomText != true)

            Button(RenderedTextZoomCommands.zoomOut.title) {
                actions?.makeTextSmaller()
            }
            .keyboardShortcut(
                RenderedTextZoomCommands.zoomOut.keyEquivalent,
                modifiers: RenderedTextZoomCommands.zoomOut.modifiers
            )
            .disabled(actions?.canZoomText != true)
        }
    }

    private func performFind() -> Bool {
        let findMenuItem = NSMenuItem()
        findMenuItem.tag = NSTextFinder.Action.showFindInterface.rawValue
        if NSApp.sendAction(#selector(NSResponder.performTextFinderAction(_:)), to: nil, from: findMenuItem) {
            return true
        }

        let legacyFindMenuItem = NSMenuItem()
        legacyFindMenuItem.tag = Int(NSFindPanelAction.showFindPanel.rawValue)
        return NSApp.sendAction(#selector(NSTextView.performFindPanelAction(_:)), to: nil, from: legacyFindMenuItem)
    }

    private func performFindPrevious() -> Bool {
        let findMenuItem = NSMenuItem()
        findMenuItem.tag = NSTextFinder.Action.previousMatch.rawValue
        return NSApp.sendAction(#selector(NSResponder.performTextFinderAction(_:)), to: nil, from: findMenuItem)
    }

    private func performPrint() -> Bool {
        NSApp.sendAction(#selector(NSView.printView(_:)), to: nil, from: nil)
    }

    private func performUndo() -> Bool {
        NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
    }

    private func performRedo() -> Bool {
        NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
    }

    private func showAboutPanel() {
        let centeredParagraph = NSMutableParagraphStyle()
        centeredParagraph.alignment = .center

        let credits = NSMutableAttributedString()

        if let websiteURL = URL(string: "https://primeradiant.com") {
            credits.append(NSAttributedString(
                string: "https://primeradiant.com",
                attributes: [
                    .link: websiteURL,
                    .paragraphStyle: centeredParagraph
                ]
            ))
        }

        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits
        ])
    }
}
