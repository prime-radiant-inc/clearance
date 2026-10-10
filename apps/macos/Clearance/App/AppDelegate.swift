import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let dockVisibilityController: DockVisibilityController

    override init() {
        dockVisibilityController = .shared
        super.init()
    }

    init(dockVisibilityController: DockVisibilityController) {
        self.dockVisibilityController = dockVisibilityController
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        dockVisibilityController.updateActivationPolicy()
        Self.cleanupRenderedPreviewDirectories(for: NSDocumentController.shared.recentDocumentURLs)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        dockVisibilityController.openURLs(urls)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if dockVisibilityController.hideDockIconWhenNoDocuments {
            // Utility windows must not prevent Finder from restoring the workspace.
            return !dockVisibilityController.showWorkspace()
        }
        return !flag
    }

    func applicationWillTerminate(_ notification: Notification) {
        RenderedHTMLLoadHandle.removeActiveStagedDirectories()
    }

    static func cleanupRenderedPreviewDirectories(for documentURLs: [URL]) {
        let directoryURLs = Set(documentURLs.compactMap { documentURL -> URL? in
            guard documentURL.isFileURL else {
                return nil
            }

            return documentURL.hasDirectoryPath ? documentURL : documentURL.deletingLastPathComponent()
        })

        for directoryURL in directoryURLs {
            RenderedHTMLLoadHandle.sweepOrphanedStagedDirectories(in: directoryURL)
        }
    }
}

extension Notification.Name {
    static let clearanceOpenURLs = Notification.Name("clearance.openURLs")
    static let clearanceOpenReadOnlyMarkdownURL = Notification.Name("clearance.openReadOnlyMarkdownURL")
}
