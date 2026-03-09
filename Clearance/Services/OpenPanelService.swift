import AppKit
import UniformTypeIdentifiers

@MainActor
protocol OpenPanelServicing {
    func chooseMarkdownFile() -> URL?
    func chooseFolder() -> (url: URL, useFolderNames: Bool)?
}

struct OpenPanelService: OpenPanelServicing {
    @MainActor
    func chooseMarkdownFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        let markdownType = UTType(filenameExtension: "md") ?? .plainText
        panel.allowedContentTypes = [markdownType, .plainText]
        panel.prompt = "Open"

        return panel.runModal() == .OK ? panel.url : nil
    }

    @MainActor
    func chooseFolder() -> (url: URL, useFolderNames: Bool)? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.prompt = "Import"

        let checkbox = NSButton(checkboxWithTitle: "Use folder name as label instead of file name", target: nil, action: nil)
        checkbox.state = .off
        checkbox.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(checkbox)

        NSLayoutConstraint.activate([
            checkbox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            checkbox.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalToConstant: 40)
        ])

        panel.accessoryView = container

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return (url: url, useFolderNames: checkbox.state == .on)
    }
}
