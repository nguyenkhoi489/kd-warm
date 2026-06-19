import SwiftUI
import Combine
import Sparkle

final class UpdaterController: NSObject, ObservableObject, SPUUpdaterDelegate {
    private var updaterController: SPUStandardUpdaterController!
    private var channel: String = ""

    @Published var canCheckForUpdates = false

    override init() {
        super.init()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() { updaterController.updater.checkForUpdates() }

    func setAutomaticChecks(_ enabled: Bool) {
        updaterController.updater.automaticallyChecksForUpdates = enabled
    }

    func setChannel(_ channel: String) {
        self.channel = channel
    }

    func allowedChannels(for updater: SPUUpdater) -> Set<String> {
        channel.isEmpty ? [] : [channel]
    }
}
