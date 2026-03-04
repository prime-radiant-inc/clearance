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

    private let fileIO: FileIO
    private let autosaveDelay: TimeInterval
    private var pendingAutosave: DispatchWorkItem?
    private var isLoaded = false

    init(url: URL, fileIO: FileIO = .live, autosaveDelay: TimeInterval = 0.5) throws {
        self.url = url
        self.fileIO = fileIO
        self.autosaveDelay = autosaveDelay

        let initialText = try fileIO.read(url)
        content = initialText
        isDirty = false
        isLoaded = true
    }

    deinit {
        pendingAutosave?.cancel()
    }

    func saveNow() throws {
        pendingAutosave?.cancel()
        try fileIO.write(content, url)
        isDirty = false
    }

    private func scheduleAutosave() {
        pendingAutosave?.cancel()

        let task = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            do {
                try self.fileIO.write(self.content, self.url)
                self.isDirty = false
            } catch {
                // Keep dirty state so a later save can retry.
                self.isDirty = true
            }
        }

        pendingAutosave = task
        DispatchQueue.main.asyncAfter(deadline: .now() + autosaveDelay, execute: task)
    }
}
