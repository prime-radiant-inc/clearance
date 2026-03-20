import AppKit
import SwiftUI

struct ProjectsSidebar: View {
    let projects: [Project]
    let treesByDirectory: [String: ProjectFileNode]
    @Binding var selectedPath: String?
    let expansionState: SidebarExpansionState
    let expandedPaths: Set<String>
    let onSelectFile: (ProjectFileNode) -> Void
    let onOpenInNewWindow: (ProjectFileNode) -> Void
    let onCreateProject: () -> UUID?
    let onRenameProject: (Project, String) -> Void
    let onDeleteProject: (Project) -> Void
    let onAddDirectory: (Project) -> Void
    let onRemoveDirectory: (Project, String) -> Void
    let onExcludeDirectory: (Project, String) -> Void
    let onIncludeDirectory: (Project, String) -> Void
    let onSetProjectFileTypes: (Project, [String]?) -> Void
    let defaultFileTypes: Set<String>

    @State private var editingProjectID: UUID?
    @State private var editingName = ""
    @State private var selectedProjectID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Projects")
                    .font(.headline)

                Spacer()

                if let projectID = selectedProjectID,
                   let project = projects.first(where: { $0.id == projectID }) {
                    Button {
                        onAddDirectory(project)
                    } label: {
                        Label("Add Folder", systemImage: "folder.badge.plus")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }

                Button {
                    if let newID = onCreateProject() {
                        editingName = "New Project"
                        editingProjectID = newID
                        selectedProjectID = newID
                    }
                } label: {
                    Label("New Project", systemImage: "plus")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            if projects.isEmpty {
                ContentUnavailableView {
                    Label("No Projects", systemImage: "folder")
                } description: {
                    Text("Click + to create a project.")
                }
            } else {
                List(selection: $selectedPath) {
                    ForEach(projects) { project in
                        Section {
                            DisclosureGroup(isExpanded: projectExpansionBinding(for: project)) {
                                projectContent(for: project)
                            } label: {
                                projectHeader(for: project)
                            }
                            .onAppear {
                                DispatchQueue.main.async {
                                    expansionState.expandIfUnknown("project:\(project.id)")
                                }
                            }
                        }
                    }
                }
                .listStyle(.sidebar)
                .onChange(of: selectedPath) { _, newPath in
                    DispatchQueue.main.async {
                        selectedProjectID = nil
                    }

                    guard let newPath else {
                        return
                    }

                    let fileNode = findFileNode(path: newPath)
                    if let fileNode, !fileNode.isDirectory {
                        onSelectFile(fileNode)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func projectHeader(for project: Project) -> some View {
        if editingProjectID == project.id {
            TextField("Project Name", text: $editingName)
                .textFieldStyle(.plain)
                .onSubmit {
                    let trimmed = editingName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        onRenameProject(project, trimmed)
                    }
                    editingProjectID = nil
                }
                .onExitCommand {
                    editingProjectID = nil
                }
        } else {
            HStack(spacing: 0) {
                Text(project.name)
                    .foregroundStyle(.primary)
                if !project.directoryPaths.isEmpty {
                    Text(" — ")
                        .foregroundStyle(.tertiary)
                    Text(Self.abbreviatedPath(commonParentPath(for: project)))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(selectedProjectID == project.id
                              ? Color.accentColor.opacity(0.2)
                              : Color.clear)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedProjectID == project.id {
                        selectedProjectID = nil
                    } else {
                        selectedProjectID = project.id
                    }
                }
                .contextMenu {
                    Button("Rename…") {
                        editingName = project.name
                        editingProjectID = project.id
                    }

                    Button("Add Folder…") {
                        onAddDirectory(project)
                    }

                    if !project.directoryPaths.isEmpty {
                        Menu("Remove Folder") {
                            ForEach(project.directoryPaths, id: \.self) { path in
                                Button(Self.abbreviatedPath(path)) {
                                    onRemoveDirectory(project, path)
                                }
                            }
                        }
                    }

                    if !project.excludedPaths.isEmpty {
                        Menu("Re-include Folder") {
                            ForEach(project.excludedPaths, id: \.self) { path in
                                Button(Self.abbreviatedPath(path)) {
                                    onIncludeDirectory(project, path)
                                }
                            }
                        }
                    }

                    Divider()

                    Menu("File Types") {
                        let effectiveTypes = project.enabledFileTypes.map(Set.init) ?? defaultFileTypes
                        ForEach(AppSettings.allFileTypes, id: \.extension) { fileType in
                            let isEnabled = effectiveTypes.contains(fileType.extension)
                            Button {
                                var newTypes = effectiveTypes
                                if isEnabled {
                                    guard newTypes.count > 1 else { return }
                                    newTypes.remove(fileType.extension)
                                } else {
                                    newTypes.insert(fileType.extension)
                                }
                                onSetProjectFileTypes(project, Array(newTypes))
                            } label: {
                                if isEnabled {
                                    Label(fileType.label, systemImage: "checkmark")
                                } else {
                                    Text(fileType.label)
                                }
                            }
                        }

                        Divider()

                        Button("Use Defaults") {
                            onSetProjectFileTypes(project, nil)
                        }
                        .disabled(project.enabledFileTypes == nil)
                    }

                    Divider()

                    Button("Delete Project") {
                        onDeleteProject(project)
                    }
                }
        }
    }

    @ViewBuilder
    private func projectContent(for project: Project) -> some View {
        let commonParent = commonParentPath(for: project)

        ForEach(project.directoryPaths, id: \.self) { dirPath in
            if let tree = treesByDirectory[dirPath] {
                let showAsNested = project.directoryPaths.count > 1 && dirPath != commonParent
                if showAsNested {
                    DirectoryNodeView(
                        node: tree,
                        isRoot: true,
                        displayName: relativePath(dirPath, relativeTo: commonParent),
                        projectID: project.id,
                        expansionState: expansionState,
                        expandedPaths: expandedPaths,
                        selectedPath: $selectedPath,
                        onOpenInNewWindow: onOpenInNewWindow,
                        onRemoveDirectory: onRemoveDirectory,
                        onExcludeDirectory: onExcludeDirectory,
                        projects: projects
                    )
                } else {
                    ForEach(tree.children) { child in
                        if child.isDirectory {
                            DirectoryNodeView(
                                node: child,
                                isRoot: false,
                                displayName: nil,
                                projectID: project.id,
                                expansionState: expansionState,
                                expandedPaths: expandedPaths,
                                selectedPath: $selectedPath,
                                onOpenInNewWindow: onOpenInNewWindow,
                                onRemoveDirectory: onRemoveDirectory,
                                onExcludeDirectory: onExcludeDirectory,
                                projects: projects
                            )
                        } else {
                            DirectoryNodeView.fileRow(
                                for: child,
                                selectedPath: $selectedPath,
                                onOpenInNewWindow: onOpenInNewWindow
                            )
                        }
                    }
                }
            } else {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(Self.abbreviatedPath(dirPath))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func projectExpansionBinding(for project: Project) -> Binding<Bool> {
        let key = "project:\(project.id)"
        return Binding(
            get: { expandedPaths.contains(key) },
            set: { expansionState.setExpanded(key, expanded: $0) }
        )
    }

    private func commonParentPath(for project: Project) -> String {
        let paths = project.directoryPaths
        guard let first = paths.first else {
            return ""
        }

        guard paths.count > 1 else {
            return first
        }

        let components = paths.map { $0.split(separator: "/", omittingEmptySubsequences: false) }
        let minCount = components.map(\.count).min() ?? 0
        var commonCount = 0
        for i in 0..<minCount {
            let component = components[0][i]
            if components.allSatisfy({ $0[i] == component }) {
                commonCount = i + 1
            } else {
                break
            }
        }

        let commonComponents = components[0].prefix(commonCount)
        let result = commonComponents.joined(separator: "/")
        return result.isEmpty ? "/" : result
    }

    private func relativePath(_ path: String, relativeTo base: String) -> String {
        if path.hasPrefix(base) {
            let relative = String(path.dropFirst(base.count))
            if relative.hasPrefix("/") {
                return String(relative.dropFirst())
            }
            return relative.isEmpty ? (path as NSString).lastPathComponent : relative
        }

        return (path as NSString).lastPathComponent
    }

    private func projectOwning(path: String) -> Project? {
        projects.first { project in
            project.directoryPaths.contains { path.hasPrefix($0) }
        }
    }

    private func findFileNode(path: String) -> ProjectFileNode? {
        for (_, tree) in treesByDirectory {
            if let found = findInTree(tree, path: path) {
                return found
            }
        }

        return nil
    }

    private func findInTree(_ node: ProjectFileNode, path: String) -> ProjectFileNode? {
        if node.path == path {
            return node
        }

        for child in node.children {
            if let found = findInTree(child, path: path) {
                return found
            }
        }

        return nil
    }

    fileprivate static func abbreviatedPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }

        return path
    }
}

/// Separate struct to allow recursive DisclosureGroup without opaque return type issues.
struct DirectoryNodeView: View {
    let node: ProjectFileNode
    let isRoot: Bool
    let displayName: String?
    let projectID: UUID
    let expansionState: SidebarExpansionState
    let expandedPaths: Set<String>
    @Binding var selectedPath: String?
    let onOpenInNewWindow: (ProjectFileNode) -> Void
    let onRemoveDirectory: (Project, String) -> Void
    let onExcludeDirectory: (Project, String) -> Void
    let projects: [Project]

    var body: some View {
        DisclosureGroup(isExpanded: expansionBinding) {
            ForEach(node.children) { child in
                if child.isDirectory {
                    DirectoryNodeView(
                        node: child,
                        isRoot: false,
                        displayName: nil,
                        projectID: projectID,
                        expansionState: expansionState,
                        expandedPaths: expandedPaths,
                        selectedPath: $selectedPath,
                        onOpenInNewWindow: onOpenInNewWindow,
                        onRemoveDirectory: onRemoveDirectory,
                        onExcludeDirectory: onExcludeDirectory,
                        projects: projects
                    )
                } else {
                    Self.fileRow(for: child, selectedPath: $selectedPath, onOpenInNewWindow: onOpenInNewWindow)
                }
            }
        } label: {
            Label {
                Text(displayName ?? node.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } icon: {
                Image(systemName: "folder")
                    .foregroundStyle(.secondary)
            }
            .contextMenu {
                if isRoot {
                    Button("Remove Folder") {
                        onRemoveDirectory(
                            projects.first { $0.id == projectID }!,
                            node.path
                        )
                    }
                }

                Button("Exclude from Project") {
                    if let project = projects.first(where: { $0.id == projectID }) {
                        onExcludeDirectory(project, node.path)
                    }
                }

                Button("Reveal in Finder") {
                    NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: node.path)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.async {
                expansionState.expandIfUnknown(node.path)
            }
        }
    }

    private var expansionBinding: Binding<Bool> {
        Binding(
            get: { expandedPaths.contains(node.path) },
            set: { expansionState.setExpanded(node.path, expanded: $0) }
        )
    }

    static func fileRow(
        for node: ProjectFileNode,
        selectedPath: Binding<String?>,
        onOpenInNewWindow: @escaping (ProjectFileNode) -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "doc.text")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .leading)

            Text(node.name)
                .font(.body)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .tag(node.path)
        .contextMenu {
            Button("Open In New Window") {
                selectedPath.wrappedValue = node.path
                onOpenInNewWindow(node)
            }

            Divider()

            Button("Reveal in Finder") {
                selectedPath.wrappedValue = node.path
                NSWorkspace.shared.activateFileViewerSelecting([node.fileURL])
            }

            Button("Copy Path to File") {
                selectedPath.wrappedValue = node.path
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(node.path, forType: .string)
            }
        }
        .draggable(node.path)
    }
}
