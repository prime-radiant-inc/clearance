import AppKit
import SwiftUI

struct RecentFilesSidebar: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let entries: [RecentFileEntry]
    @Binding var selectedPath: String?
    let onOpenFile: () -> Void
    let onImportFolder: () -> Void
    let onSelect: (RecentFileEntry) -> Void
    let onOpenInNewWindow: (RecentFileEntry) -> Void
    let onRemoveFromSidebar: (RecentFileEntry) -> Void
    let onClearSection: ([RecentFileEntry]) -> Void

    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            listSection
            Divider()
            footerSection
        }
    }

    private var footerSection: some View {
        HStack {
            let total = entries.count
            let shown = filteredEntries.count
            if !searchText.isEmpty && shown != total {
                Text("\(shown) of \(total) files")
            } else {
                Text("\(total) file\(total == 1 ? "" : "s")")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Responsive button row: side-by-side when space allows, stacked when narrow
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    SidebarActionButton("Open Markdown…", systemImage: "folder.badge.plus", action: onOpenFile)
                        .frame(minWidth: 90, maxWidth: .infinity)
                    SidebarActionButton("Import Folder…", systemImage: "folder.fill", action: onImportFolder)
                        .frame(minWidth: 90, maxWidth: .infinity)
                }
                VStack(spacing: 4) {
                    SidebarActionButton("Open Markdown…", systemImage: "folder.badge.plus", action: onOpenFile)
                        .frame(maxWidth: .infinity)
                    SidebarActionButton("Import Folder…", systemImage: "folder.fill", action: onImportFolder)
                        .frame(maxWidth: .infinity)
                }
            }

            SidebarSearchField(text: $searchText)
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 10)
    }

    // MARK: - List

    private var listSection: some View {
        List(selection: $selectedPath) {
            ForEach(groupedEntries) { section in
                Section {
                    ForEach(section.entries) { entry in
                        RecentFileRow(entry: entry) {
                            selectedPath = entry.path
                            onRemoveFromSidebar(entry)
                        }
                        .tag(entry.path)
                        .contextMenu {
                            contextMenuActions(for: entry)
                        }
                        .draggable(entry.path)
                    }
                } header: {
                    SectionHeader(title: section.title) {
                        onClearSection(section.entries)
                    }
                }
            }
        }
        .contextMenu(forSelectionType: String.self) { selectedPaths in
            if let path = selectedPaths.first,
               let entry = entries.first(where: { $0.path == path }) {
                contextMenuActions(for: entry)
            }
        }
        .onChange(of: selectedPath) { _, newPath in
            guard let newPath,
                  let entry = entries.first(where: { $0.path == newPath }) else {
                return
            }
            onSelect(entry)
        }
        .listStyle(.sidebar)
        .animation(
            accessibilityReduceMotion ? nil : .snappy(duration: 0.26),
            value: entries.count
        )
    }

    // MARK: - Filtering

    private var filteredEntries: [RecentFileEntry] {
        guard !searchText.isEmpty else { return entries }
        let query = searchText.lowercased()
        return entries.filter {
            $0.displayName.lowercased().contains(query) ||
            $0.fileURL.lastPathComponent.lowercased().contains(query) ||
            $0.directoryPath.lowercased().contains(query)
        }
    }

    private var groupedEntries: [RecentFilesSection] {
        var buckets: [RecentFileBucket: [RecentFileEntry]] = [:]
        for entry in filteredEntries {
            buckets[RecentFileBucket.bucket(for: entry.lastOpenedAt), default: []].append(entry)
        }

        return RecentFileBucket.allCases.compactMap { bucket in
            guard let sectionEntries = buckets[bucket], !sectionEntries.isEmpty else {
                return nil
            }
            return RecentFilesSection(bucket: bucket, entries: sectionEntries)
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private func contextMenuActions(for entry: RecentFileEntry) -> some View {
        if entry.fileURL.isFileURL {
            Button("Open In New Window") {
                selectedPath = entry.path
                onOpenInNewWindow(entry)
            }

            Divider()

            Button("Reveal in Finder") {
                selectedPath = entry.path
                NSWorkspace.shared.activateFileViewerSelecting([entry.fileURL])
            }

            Button("Copy Path to File") {
                selectedPath = entry.path
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(entry.path, forType: .string)
            }

            Divider()

            Button("Remove from History") {
                selectedPath = entry.path
                onRemoveFromSidebar(entry)
            }
        } else {
            Button("Copy URL") {
                selectedPath = entry.path
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(entry.fileURL.absoluteString, forType: .string)
            }

            Divider()

            Button("Remove from History") {
                selectedPath = entry.path
                onRemoveFromSidebar(entry)
            }
        }
    }
}

// MARK: - Action button

private struct SidebarActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    @State private var isHovered = false

    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11.5))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(isHovered ? Color.primary : Color.secondary)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Search field

private struct SidebarSearchField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            TextField("Filter files…", text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isFocused)

            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(
                    isFocused ? Color.accentColor.opacity(0.6) : Color(nsColor: .separatorColor),
                    lineWidth: isFocused ? 1.5 : 0.5
                )
        )
    }
}

// MARK: - Section header

private struct SectionHeader: View {
    let title: String
    let onClear: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button(action: onClear) {
                Text("Clear")
                    .font(.caption)
                    .foregroundStyle(isHovered ? Color.primary : Color.secondary)
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
        }
    }
}

// MARK: - File row

private struct RecentFileRow: View {
    let entry: RecentFileEntry
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: entry.fileURL.isFileURL ? "doc.text" : "globe")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.body)
                    .lineLimit(1)
                Text(entry.directoryPath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .help("Remove from History")
            .opacity(isHovered ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
}

// MARK: - Section model

private struct RecentFilesSection: Identifiable {
    let bucket: RecentFileBucket
    let entries: [RecentFileEntry]

    var id: String { bucket.rawValue }
    var title: String { bucket.rawValue }
}

// MARK: - Bucket

private enum RecentFileBucket: String, CaseIterable {
    case today = "Today"
    case yesterday = "Yesterday"
    case thisWeek = "This Week"
    case lastWeek = "Last Week"
    case thisMonth = "This Month"
    case lastMonth = "Last Month"
    case older = "Older"

    static func bucket(for date: Date, now: Date = .now, calendar: Calendar = .current) -> RecentFileBucket {
        let startOfToday = calendar.startOfDay(for: now)
        let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday

        let startOfThisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfToday
        let startOfLastWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: startOfThisWeek) ?? startOfThisWeek

        let startOfThisMonth = calendar.dateInterval(of: .month, for: now)?.start ?? startOfToday
        let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth) ?? startOfThisMonth

        if date >= startOfToday { return .today }
        if date >= startOfYesterday && date < startOfToday { return .yesterday }
        if date >= startOfThisWeek { return .thisWeek }
        if date >= startOfLastWeek { return .lastWeek }
        if date >= startOfThisMonth { return .thisMonth }
        if date >= startOfLastMonth { return .lastMonth }
        return .older
    }
}
