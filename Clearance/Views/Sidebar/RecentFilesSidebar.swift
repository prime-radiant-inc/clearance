import AppKit
import SwiftUI

struct RecentFilesSidebar: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let entries: [RecentFileEntry]
    @Binding var selectedPath: String?
    @Binding var sidebarGrouping: SidebarGrouping
    let onOpenFile: () -> Void
    let onSelect: (RecentFileEntry) -> Void
    let onOpenInNewWindow: (RecentFileEntry) -> Void
    let onRemoveFromSidebar: (RecentFileEntry) -> Void

    @State private var expandedSections: [String: Bool] = [:]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onOpenFile) {
                    Label("Open Markdown…", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                Spacer()
                Picker("", selection: $sidebarGrouping) {
                    ForEach(SidebarGrouping.allCases) { grouping in
                        Image(systemName: grouping.symbolName)
                            .tag(grouping)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 72)
                .controlSize(.small)
                .help("Sidebar grouping")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            List(selection: $selectedPath) {
                ForEach(groupedEntries) { section in
                    Section(isExpanded: sectionBinding(for: section.id)) {
                        ForEach(section.entries) { entry in
                            row(for: entry, showDirectory: sidebarGrouping != .byFolder)
                        }
                    } header: {
                        if let subtitle = section.subtitle {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(section.title)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.primary)
                                Text(subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        } else {
                            Text(section.title)
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
            .padding(.top, 4)
            .animation(
                accessibilityReduceMotion ? nil : .snappy(duration: 0.26),
                value: entries.map { "\($0.path)|\($0.lastOpenedAt.timeIntervalSinceReferenceDate)" }
            )
        }
    }

    private func sectionBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedSections[id] ?? true },
            set: { newValue in
                var transaction = Transaction()
                transaction.animation = nil
                withTransaction(transaction) {
                    expandedSections[id] = newValue
                }
            }
        )
    }

    private var groupedEntries: [RecentFilesSection] {
        switch sidebarGrouping {
        case .byDate:
            return entriesGroupedByDate
        case .byFolder:
            return entriesGroupedByFolder
        }
    }

    private var entriesGroupedByDate: [RecentFilesSection] {
        var buckets: [RecentFileBucket: [RecentFileEntry]] = [:]
        for entry in entries {
            buckets[RecentFileBucket.bucket(for: entry.lastOpenedAt), default: []].append(entry)
        }

        return RecentFileBucket.allCases.compactMap { bucket in
            guard let sectionEntries = buckets[bucket], !sectionEntries.isEmpty else {
                return nil
            }

            return RecentFilesSection(
                bucket: bucket,
                entries: sectionEntries
            )
        }
    }

    private static let otherKey = "_other"

    private var entriesGroupedByFolder: [RecentFilesSection] {
        var folderOrder: [String] = []
        var folderEntries: [String: [RecentFileEntry]] = [:]

        for entry in entries {
            let key: String
            if entry.fileURL.isFileURL, let projectRoot = ProjectRootResolver.projectRoot(for: entry.path) {
                key = projectRoot
            } else {
                key = Self.otherKey
            }

            if folderEntries[key] == nil {
                folderOrder.append(key)
            }
            folderEntries[key, default: []].append(entry)
        }

        return folderOrder.compactMap { folder -> RecentFilesSection? in
            guard let sectionEntries = folderEntries[folder], !sectionEntries.isEmpty else {
                return nil
            }

            if folder == Self.otherKey {
                return RecentFilesSection(
                    id: Self.otherKey,
                    title: "Other",
                    subtitle: nil,
                    entries: sectionEntries
                )
            }

            let components = folder.split(separator: "/")
            let displayName = components.last.map(String.init) ?? folder

            return RecentFilesSection(
                id: folder,
                title: displayName,
                subtitle: folder,
                entries: sectionEntries
            )
        }
    }

    private func row(for entry: RecentFileEntry, showDirectory: Bool = true) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: entry.fileURL.isFileURL ? "doc.text" : "globe")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.displayName)
                    .font(.body)
                    .lineLimit(1)
                if showDirectory {
                    Text(entry.directoryPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .tag(entry.path)
        .contextMenu {
            contextMenuActions(for: entry)
        }
        .draggable(entry.path)
    }

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

private struct RecentFilesSection: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let entries: [RecentFileEntry]

    init(bucket: RecentFileBucket, entries: [RecentFileEntry]) {
        self.id = bucket.rawValue
        self.title = bucket.rawValue
        self.subtitle = nil
        self.entries = entries
    }

    init(id: String, title: String, subtitle: String?, entries: [RecentFileEntry]) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.entries = entries
    }
}

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

        if date >= startOfToday {
            return .today
        }

        if date >= startOfYesterday && date < startOfToday {
            return .yesterday
        }

        if date >= startOfThisWeek {
            return .thisWeek
        }

        if date >= startOfLastWeek {
            return .lastWeek
        }

        if date >= startOfThisMonth {
            return .thisMonth
        }

        if date >= startOfLastMonth {
            return .lastMonth
        }

        return .older
    }
}
