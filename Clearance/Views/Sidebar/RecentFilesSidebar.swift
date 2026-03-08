import AppKit
import SwiftUI

struct RecentFilesSidebar: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let entries: [RecentFileEntry]
    @Binding var selectedPath: String?
    let onOpenFile: () -> Void
    let onSelect: (RecentFileEntry) -> Void
    let onOpenInNewWindow: (RecentFileEntry) -> Void
    let onRemoveFromSidebar: (RecentFileEntry) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onOpenFile) {
                    Label("Open Markdown…", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)

            Divider()

            List(selection: $selectedPath) {
                ForEach(groupedEntries) { section in
                    Section(section.title) {
                        ForEach(section.entries) { entry in
                            row(for: entry)
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
                value: entries.map { "\($0.path)|\($0.lastOpenedAt.timeIntervalSinceReferenceDate)" }
            )
        }
    }

    private var groupedEntries: [RecentFilesSection] {
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

    private func row(for entry: RecentFileEntry) -> some View {
        HStack(alignment: .top, spacing: 8) {
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .tag(entry.path)
        .contextMenu {
            contextMenuActions(for: entry)
        }
        .draggable(entry.fileURL)
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
    let bucket: RecentFileBucket
    let entries: [RecentFileEntry]

    var id: String { bucket.rawValue }
    var title: String { bucket.rawValue }
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
