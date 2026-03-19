# Projects Sidebar

The Projects sidebar lets you organize markdown files into named projects. Each project is a collection of directories — Clearance watches those directories for changes and keeps the file list up to date automatically.

## Getting Started

1. Switch to the **Projects** tab using the segmented control at the top of the sidebar.
2. Click the **+** button to create a new project. Type a name and press Return.
3. Select the project by clicking its name, then click the **folder icon** that appears in the toolbar to add a directory.
4. Markdown files in that directory (and its subdirectories) appear in the sidebar immediately.

## Managing Projects

- **Rename** — right-click a project name and choose *Rename*, then type the new name.
- **Delete** — right-click a project name and choose *Delete*.
- **Reorder** — drag projects up or down in the list.

## Managing Directories

- **Add a directory** — select a project, then click the folder icon in the toolbar. Pick a folder in the file chooser.
- **Remove a directory** — right-click the directory header within a project and choose *Remove Folder*.
- **Reveal in Finder** — right-click a directory header and choose *Reveal in Finder*.

When a project has multiple directories, Clearance finds their common parent path and displays it next to the project name (e.g., **Bells — ~/hacks/bells/plans**). The file tree is rooted at the level below that common parent so you don't see redundant nesting.

## Working with Files

Click any file to open it. The file is also added to your **History** so it appears in the History tab.

Right-click a file for additional options:

- **Open In New Window**
- **Reveal in Finder**
- **Copy Path**

## Expand and Collapse

- Click the disclosure arrow next to a project name to collapse or expand the entire project.
- Click the disclosure arrow next to any subdirectory to collapse or expand it.
- Directories with more than 10 files start collapsed by default; smaller directories start expanded.
- Expand/collapse state is remembered while the app is running.

## Live Updates

Clearance watches your project directories for changes. If you add, rename, move, or delete markdown files outside of the app, the sidebar updates automatically within about a second.

## Persistence

Your projects and their directories are saved automatically. Quit and relaunch Clearance and everything will be right where you left it. The selected sidebar tab (History or Projects) is also remembered across launches.
