import SwiftUI

enum SidebarTab: String, CaseIterable {
    case projects = "Projects"
    case history = "History"
}

struct SidebarContainerView: View {
    @Binding var selectedTab: SidebarTab
    @State private var pickerTab: SidebarTab?

    let recentEntries: [RecentFileEntry]
    @Binding var selectedRecentPath: String?
    let onOpenFile: () -> Void
    let onDropURL: (URL) -> Bool
    let onSelectRecentEntry: (RecentFileEntry) -> Void
    let onOpenRecentInNewWindow: (RecentFileEntry) -> Void
    let onRemoveFromHistory: (RecentFileEntry) -> Void

    let projects: [Project]
    let treesByDirectory: [String: ProjectFileNode]
    @Binding var selectedProjectFilePath: String?
    let expansionState: SidebarExpansionState
    let expandedPaths: Set<String>
    let onSelectProjectFile: (ProjectFileNode) -> Void
    let onOpenProjectFileInNewWindow: (ProjectFileNode) -> Void
    let onCreateProject: () -> UUID?
    let onRenameProject: (Project, String) -> Void
    let onDeleteProject: (Project) -> Void
    let onAddDirectory: (Project) -> Void
    let onRemoveDirectory: (Project, String) -> Void
    let onExcludeDirectory: (Project, String) -> Void
    let onIncludeDirectory: (Project, String) -> Void
    let onSetProjectFileTypes: (Project, [String]?) -> Void
    let defaultFileTypes: Set<String>

    private var activeTab: SidebarTab {
        pickerTab ?? selectedTab
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: Binding(
                get: { pickerTab ?? selectedTab },
                set: { newTab in
                    pickerTab = newTab
                    DispatchQueue.main.async {
                        selectedTab = newTab
                    }
                }
            )) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 10)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .onChange(of: selectedTab) { _, newTab in
                pickerTab = nil
            }

            ZStack {
                RecentFilesSidebar(
                    entries: recentEntries,
                    selectedPath: $selectedRecentPath,
                    onOpenFile: onOpenFile,
                    onDropURL: onDropURL,
                    onSelect: onSelectRecentEntry,
                    onOpenInNewWindow: onOpenRecentInNewWindow,
                    onRemoveFromSidebar: onRemoveFromHistory
                )
                .opacity(activeTab == .history ? 1 : 0)
                .accessibilityHidden(activeTab != .history)

                ProjectsSidebar(
                    projects: projects,
                    treesByDirectory: treesByDirectory,
                    selectedPath: $selectedProjectFilePath,
                    expansionState: expansionState,
                    expandedPaths: expandedPaths,
                    onSelectFile: onSelectProjectFile,
                    onOpenInNewWindow: onOpenProjectFileInNewWindow,
                    onCreateProject: onCreateProject,
                    onRenameProject: onRenameProject,
                    onDeleteProject: onDeleteProject,
                    onAddDirectory: onAddDirectory,
                    onRemoveDirectory: onRemoveDirectory,
                    onExcludeDirectory: onExcludeDirectory,
                    onIncludeDirectory: onIncludeDirectory,
                    onSetProjectFileTypes: onSetProjectFileTypes,
                    defaultFileTypes: defaultFileTypes
                )
                .opacity(activeTab == .projects ? 1 : 0)
                .accessibilityHidden(activeTab != .projects)
            }
        }
    }
}
