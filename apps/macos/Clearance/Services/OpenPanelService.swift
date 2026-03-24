import AppKit
import UniformTypeIdentifiers

@MainActor
protocol OpenPanelServicing {
    func chooseMarkdownFile() -> URL?
    func chooseNewMarkdownFileLocation() -> URL?
}

struct OpenPanelService: OpenPanelServicing {
    @MainActor
    func chooseMarkdownFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        let markdownType = UTType(filenameExtension: "md") ?? .plainText
        panel.allowedContentTypes = [markdownType, .plainText]
        panel.prompt = "Open"

        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    func chooseNewMarkdownFileLocation() -> URL? {
        let panel = NSSavePanel()
        let markdownType = UTType(filenameExtension: "md") ?? .plainText
        panel.allowedContentTypes = [markdownType]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = "Untitled.md"
        panel.prompt = "Create"

        return panel.runModal() == .OK ? panel.url : nil
    }
}
