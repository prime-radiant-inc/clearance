import Sparkle

@MainActor
final class SparkleUpdateController {
    private let updaterController: SPUStandardUpdaterController?

    init() {
        let configuration = SparkleConfiguration()
        if configuration.isComplete {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        } else {
            updaterController = nil
        }
    }

    var canCheckForUpdates: Bool {
        updaterController != nil
    }

    func checkForUpdates() {
        updaterController?.checkForUpdates(nil)
    }
}
