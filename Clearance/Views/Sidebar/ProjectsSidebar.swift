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

    @State private var editingProjectID: UUID?
    @State private var editingName = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Projects")
                    .font(.headline)

                Spacer()

                Button {
                    if let newID = onCreateProject() {
                        editingName = "New Project"
                        editingProjectID = newID
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
                            projectContent(for: project)
                        } header: {
                            projectHeader(for: project)
                        }
                    }
                }
                .listStyle(.sidebar)
                .onChange(of: selectedPath) { _, newPath in
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
            Text(project.name)
                .contextMenu {
                    Button("Rename…") {
                        editingName = project.name
                        editingProjectID = project.id
                    }

                    Button("Add Folder…") {
                        onAddDirectory(project)
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
        ForEach(project.directoryPaths, id: \.self) { dirPath in
            if let tree = treesByDirectory[dirPath] {
                DirectoryNodeView(
                    node: tree,
                    isRoot: true,
                    projectID: project.id,
                    expansionState: expansionState,
                    expandedPaths: expandedPaths,
                    selectedPath: $selectedPath,
                    onOpenInNewWindow: onOpenInNewWindow,
                    onRemoveDirectory: onRemoveDirectory,
                    projects: projects
                )
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

        Button {
            onAddDirectory(project)
        } label: {
            Label("Add Folder…", systemImage: "folder.badge.plus")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .controlSize(.small)
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
private struct DirectoryNodeView: View {
    let node: ProjectFileNode
    let isRoot: Bool
    let projectID: UUID
    let expansionState: SidebarExpansionState
    let expandedPaths: Set<String>
    @Binding var selectedPath: String?
    let onOpenInNewWindow: (ProjectFileNode) -> Void
    let onRemoveDirectory: (Project, String) -> Void
    let projects: [Project]

    var body: some View {
        DisclosureGroup(isExpanded: expansionBinding) {
            ForEach(node.children) { child in
                if child.isDirectory {
                    DirectoryNodeView(
                        node: child,
                        isRoot: false,
                        projectID: projectID,
                        expansionState: expansionState,
                        expandedPaths: expandedPaths,
                        selectedPath: $selectedPath,
                        onOpenInNewWindow: onOpenInNewWindow,
                        onRemoveDirectory: onRemoveDirectory,
                        projects: projects
                    )
                } else {
                    fileRow(for: child)
                }
            }
        } label: {
            Label {
                Text(isRoot ? ProjectsSidebar.abbreviatedPath(node.path) : node.name)
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

    private func fileRow(for node: ProjectFileNode) -> some View {
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
                selectedPath = node.path
                onOpenInNewWindow(node)
            }

            Divider()

            Button("Reveal in Finder") {
                selectedPath = node.path
                NSWorkspace.shared.activateFileViewerSelecting([node.fileURL])
            }

            Button("Copy Path to File") {
                selectedPath = node.path
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(node.path, forType: .string)
            }
        }
        .draggable(node.path)
    }
}
