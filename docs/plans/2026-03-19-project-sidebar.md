# Projects Sidebar Feature

## Context

The sidebar currently only shows a history of recently opened files. The goal is to add a second sidebar mode where users can define **projects** — named collections of directories — and see all markdown files under those directories, kept in sync with the filesystem. This lets the user organize files by project rather than by recency.

## Design Decisions

- **Segmented control** at top of sidebar switches between History and Projects
- **Inline project management**: create, rename, delete projects and add/remove directories all via the sidebar (context menus + inline editing)
- **Files grouped by directory** within each project (collapsible sections)
- **FSEvents** for directory watching (efficient for multiple directories; the app is not sandboxed)
- **Opening a project file adds it to history** (since the user actually views it)
- Files sorted alphabetically within each directory group
- Sidebar tab selection persisted in AppSettings
- **Collapsible directories and subdirectories** — every directory node is a `DisclosureGroup` that can be expanded/collapsed. Directories with more than **10** files are collapsed by default; smaller directories start expanded. Collapse state is ephemeral (not persisted across launches).

## New Files

### 1. `Clearance/Models/Project.swift` — Data model

```swift
struct Project: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var directoryPaths: [String]  // absolute paths
}
```

### 2. `Clearance/Models/ProjectFile.swift` — Runtime directory tree representation

```swift
/// A node in the directory tree: either a directory containing children, or a file leaf.
struct ProjectFileNode: Identifiable, Equatable {
    let path: String
    let name: String           // last path component
    let isDirectory: Bool
    var children: [ProjectFileNode]  // empty for files, sorted for directories
    var id: String { path }
    var fileURL: URL { URL(fileURLWithPath: path) }
}
```

`DirectoryMonitor` builds a tree of `ProjectFileNode` per watched root directory. This supports nested subdirectory collapsing in the sidebar. Files are leaf nodes; directories are branch nodes rendered as `DisclosureGroup`.

### 3. `Clearance/Models/ProjectStore.swift` — Persistence (follows RecentFilesStore pattern)

`ObservableObject` storing `[Project]` as JSON in UserDefaults (key: `"projects"`).

Methods: `addProject(name:)`, `removeProject(id:)`, `renameProject(id:newName:)`, `addDirectory(to:path:)`, `removeDirectory(from:path:)`, `moveProject(from:to:)`.

Each mutation calls `persist()` — same pattern as `RecentFilesStore`.

### 4. `Clearance/Services/DirectoryMonitor.swift` — FSEvents-based file watcher

`ObservableObject` publishing `@Published var treesByDirectory: [String: ProjectFileNode]` — each entry is a tree rooted at a watched directory.

- Single `FSEventStreamRef` monitoring all watched directory paths
- `updateMonitoredDirectories(_ paths: Set<String>)` — tears down and recreates the stream when the set of directories changes
- On FSEvent callback: re-enumerates only the affected directory path(s)
- Enumeration uses `FileManager.enumerator()` with `.skipsHiddenFiles`, filtering to extensions `[md, markdown, txt]` — same logic as existing `WorkspaceViewModel.folderImportURLs`
- Builds a `ProjectFileNode` tree from the flat enumeration results (directories containing at least one markdown file in their subtree are included; empty directories are pruned)
- Small latency (0.5s) to coalesce rapid changes
- Enumeration runs on a background queue, publishes results on main actor

### 5. `Clearance/Views/Sidebar/ProjectsSidebar.swift` — Projects sidebar view

Follows the same structure as `RecentFilesSidebar`:
- Header: "Projects" title + "+" button to create a project
- `List` with `ForEach(projects)` where each project is a `Section`
- Within each project section: recursive `DisclosureGroup` rendering of the `ProjectFileNode` tree — directories render as collapsible groups, files render as leaf rows
- **Collapse behavior**: directories with >10 direct+nested files start collapsed; smaller ones start expanded. A `@State` dictionary tracks user-toggled collapse state per directory path
- File rows match `RecentFilesSidebar` visual style (icon + name + directory path)
- Context menus:
  - Project header: Rename, Add Folder..., Delete
  - Directory header: Remove Folder, Reveal in Finder
  - File row: Open In New Window, Reveal in Finder, Copy Path
- Callbacks passed as closures from parent (same pattern as RecentFilesSidebar)
- Inline rename via `@State var editingProjectID: UUID?` swapping Text for TextField

### 6. `Clearance/Views/Sidebar/SidebarContainerView.swift` — Tab switching wrapper

```swift
enum SidebarTab: String, CaseIterable { case history, projects }
```

Contains the segmented `Picker` at top, then conditionally renders `RecentFilesSidebar` or `ProjectsSidebar`. `RecentFilesSidebar` remains completely unchanged.

## Modified Files

### 7. `Clearance/Services/OpenPanelService.swift`

Add `chooseDirectory() -> URL?` method — `NSOpenPanel` configured with `canChooseDirectories = true`, `canChooseFiles = false`.

### 8. `Clearance/Models/AppSettings.swift`

Add `@Published var sidebarTab: SidebarTab` with UserDefaults persistence (key: `"sidebarTab"`), following the existing pattern for `defaultOpenMode`.

### 9. `Clearance/ViewModels/WorkspaceViewModel.swift`

- Add `projectStore: ProjectStore` and `directoryMonitor: DirectoryMonitor` properties (injected with defaults)
- Add Combine pipeline: observe `projectStore.$projects` → compute union of all `directoryPaths` → call `directoryMonitor.updateMonitoredDirectories(...)`
- Add `openProjectFile(_ file: ProjectFileNode)` — calls existing `open(url:)` which adds to history

### 10. `Clearance/Views/WorkspaceView.swift`

- Replace `RecentFilesSidebar(...)` in `NavigationSplitView` sidebar slot with `SidebarContainerView(...)`
- Wire project callbacks through to view model methods
- Add folder picker call for "Add Folder..." context menu action

## Implementation Order

1. `Project` + `ProjectFileNode` models
2. `ProjectStore` with persistence
3. `DirectoryMonitor` with FSEvents
4. `ProjectsSidebar` view
5. `SidebarContainerView` wrapper
6. `OpenPanelService.chooseDirectory()`
7. `AppSettings.sidebarTab` persistence
8. `WorkspaceViewModel` integration (store + monitor + Combine glue)
9. `WorkspaceView` integration (swap sidebar, wire callbacks)

## Verification

1. Build and run — segmented control appears at top of sidebar
2. Switch to Projects tab — empty state with "+" button
3. Create a project — appears with default name, inline rename works
4. Add a directory via context menu — folder picker opens, files appear grouped under directory
5. Add/remove a `.md` file in the watched directory externally — sidebar updates within ~1 second
6. Click a project file — opens in main view AND appears in History sidebar
7. Remove a directory — files disappear, project remains
8. Delete a project — project and its files removed from sidebar
9. Quit and relaunch — projects and sidebar tab selection are preserved
10. Context menus work: Reveal in Finder, Copy Path, Open In New Window on file rows
11. Directories and subdirectories are collapsible; large directories (>10 files) start collapsed
