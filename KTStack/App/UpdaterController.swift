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

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        NSLog("KTStack updater: aborted: \(error)")
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        NSLog("KTStack updater: failed to download \(item.displayVersionString): \(error)")
    }

    func updater(_ updater: SPUUpdater, willInstallUpdate item: SUAppcastItem) {
        NSLog("KTStack updater: will install \(item.displayVersionString)")
    }

    func updaterWillRelaunchApplication(_ updater: SPUUpdater) {
        NSLog("KTStack updater: will relaunch application")
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        if let error {
            NSLog("KTStack updater: update cycle finished with error: \(error)")
        }
    }
}
