import Foundation

struct ReleaseNotesCatalog {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    var documentURL: URL? {
        bundle.url(forResource: "CHANGELOG", withExtension: "md")
    }

    var currentVersion: String? {
        guard let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return nil
        }

        let trimmedVersion = version.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedVersion.isEmpty ? nil : trimmedVersion
    }
}
