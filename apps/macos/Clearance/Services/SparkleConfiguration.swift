import Foundation

struct SparkleConfiguration {
    let feedURL: String
    let publicEDKey: String

    init(bundle: Bundle = .main) {
        self.init(
            feedURL: bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String,
            publicEDKey: bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        )
    }

    init(feedURL: String?, publicEDKey: String?) {
        self.feedURL = feedURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.publicEDKey = publicEDKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var isComplete: Bool {
        !feedURL.isEmpty && !publicEDKey.isEmpty
    }
}
