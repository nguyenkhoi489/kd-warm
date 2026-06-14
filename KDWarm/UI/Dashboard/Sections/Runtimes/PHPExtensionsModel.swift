import Foundation
import KDWarmKit

/// View-model for one PHP version's extension manager sheet. Publishes a row per catalog extension
/// (built-in status-only + optional install/uninstall) with live `php -m` status, and drives the
/// install/uninstall lifecycle: `PHPExtensionInstaller` → restart that version's php-fpm pool (a
/// `dlopen`'d `.so` only (un)loads on a master restart) → re-probe status. Transient per-extension
/// busy/progress/error are kept SEPARATE from the rows so a status refresh never clobbers them.
@MainActor
final class PHPExtensionsModel: ObservableObject {
    struct Row: Identifiable {
        let ext: PHPExtension
        let status: PHPExtensionStatus
        var id: String { ext.id }
    }

    let version: String
    @Published private(set) var rows: [Row] = []
    @Published private(set) var busy: Set<String> = []
    @Published private(set) var progress: [String: Double] = [:]
    @Published private(set) var errors: [String: String] = [:]

    private let paths: AppSupportPaths
    private let installer: PHPExtensionInstaller
    private let catalog: PHPExtensionCatalog

    init(version: String, paths: AppSupportPaths = AppSupportPaths()) {
        self.version = version
        self.paths = paths
        self.installer = PHPExtensionInstaller(paths: paths)
        self.catalog = PHPExtensionCatalog(paths: paths)
    }

    /// Rebuild rows from live status. `status(...)` runs `php -m`, so resolve off the main thread; the
    /// optional set sorts first (actionable), built-ins after (status-only), each alphabetical.
    func refresh() async {
        let catalog = self.catalog
        let version = self.version
        let statuses: [String: PHPExtensionStatus] = await Task.detached(priority: .utility) {
            var map: [String: PHPExtensionStatus] = [:]
            for ext in PHPExtensionCatalog.descriptors {
                map[ext.id] = catalog.status(ext, phpVersion: version)
            }
            return map
        }.value
        rows = PHPExtensionCatalog.descriptors
            .map { Row(ext: $0, status: statuses[$0.id] ?? .unavailable) }
            .sorted { a, b in
                if a.ext.isBuiltIn != b.ext.isBuiltIn { return !a.ext.isBuiltIn }   // optional first
                return a.ext.displayName.localizedCaseInsensitiveCompare(b.ext.displayName) == .orderedAscending
            }
    }

    func install(_ extID: String, reloadPool: (String) async throws -> Void) async {
        guard !busy.contains(extID) else { return }
        begin(extID)
        do {
            let result = try await installer.install(extID, phpVersion: version) { [weak self] prog in
                Task { @MainActor in self?.progress[extID] = prog.fraction }
            }
            try await reloadPool(version)
            PHPModules.invalidate(version: version)
            await refresh()
            // A `.so` that lands on disk but fails to load shows up as `.installedButFailedToLoad` in
            // the refreshed status; surface the captured Warning so it isn't a silent half-install.
            if case .installedButFailedToLoad(let warning) = result {
                errors[extID] = warning ?? "Installed but the extension failed to load."
            }
        } catch {
            errors[extID] = error.localizedDescription
        }
        end(extID)
    }

    func uninstall(_ extID: String, reloadPool: (String) async throws -> Void) async {
        guard !busy.contains(extID) else { return }
        begin(extID)
        do {
            try installer.uninstall(extID, phpVersion: version)
            try await reloadPool(version)          // RESTART, not reload — unloads the live .so
            PHPModules.invalidate(version: version)
            await refresh()
        } catch {
            errors[extID] = error.localizedDescription
        }
        end(extID)
    }

    private func begin(_ extID: String) { busy.insert(extID); errors[extID] = nil; progress[extID] = nil }
    private func end(_ extID: String) { busy.remove(extID); progress[extID] = nil }
}
