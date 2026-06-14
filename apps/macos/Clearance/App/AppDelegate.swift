import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.cleanupRenderedPreviewDirectories(for: NSDocumentController.shared.recentDocumentURLs)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        NotificationCenter.default.post(name: .clearanceOpenURLs, object: urls)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        !flag
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
    static let clearanceShowHelp = Notification.Name("clearance.showHelp")
}
