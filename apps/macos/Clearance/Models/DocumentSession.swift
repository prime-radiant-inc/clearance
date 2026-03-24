import Foundation

final class DocumentSession: ObservableObject, Identifiable {
    let id = UUID()
    let url: URL

    @Published var content: String {
        didSet {
            guard isLoaded else {
                return
            }

            isDirty = true
            scheduleAutosave()
        }
    }

    @Published private(set) var isDirty: Bool
    @Published private(set) var hasExternalChanges: Bool

    private let fileIO: FileIO
    private let autosaveDelay: TimeInterval
    private var pendingAutosave: DispatchWorkItem?
    private var lastKnownDiskText: String
    private var isLoaded = false

    init(url: URL, fileIO: FileIO = .live, autosaveDelay: TimeInterval = 0.5) throws {
        self.url = url
        self.fileIO = fileIO
        self.autosaveDelay = autosaveDelay

        let initialText = try fileIO.read(url)
        content = initialText
        isDirty = false
        hasExternalChanges = false
        lastKnownDiskText = initialText
        isLoaded = true
    }

    deinit {
        pendingAutosave?.cancel()
    }

    var displayTitle: String {
        if isDirty {
            return "*\(url.lastPathComponent)"
        }

        return url.lastPathComponent
    }

    func saveNow() throws {
        pendingAutosave?.cancel()
        try fileIO.write(content, url)
        lastKnownDiskText = content
        isDirty = false
        hasExternalChanges = false
    }

    func reloadFromDisk() throws {
        pendingAutosave?.cancel()

        let latestText = try fileIO.read(url)
        isLoaded = false
        content = latestText
        isLoaded = true
        lastKnownDiskText = latestText
        isDirty = false
        hasExternalChanges = false
    }

    func checkForExternalChanges() {
        guard let diskText = try? fileIO.read(url),
              diskText != lastKnownDiskText else {
            return
        }

        hasExternalChanges = true
    }

    func acknowledgeExternalChangesKeepingCurrent() {
        if let diskText = try? fileIO.read(url) {
            lastKnownDiskText = diskText
        }

        hasExternalChanges = false
    }

    private func scheduleAutosave() {
        pendingAutosave?.cancel()

        let task = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            do {
                try self.fileIO.write(self.content, self.url)
                self.lastKnownDiskText = self.content
                self.isDirty = false
                self.hasExternalChanges = false
            } catch {
                // Keep dirty state so a later save can retry.
                self.isDirty = true
            }
        }

        pendingAutosave = task
        DispatchQueue.main.asyncAfter(deadline: .now() + autosaveDelay, execute: task)
    }
}
