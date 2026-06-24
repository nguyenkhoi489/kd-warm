import SwiftUI
import AppKit
import KTStackKit

@MainActor
final class RestoreBackupModel: ObservableObject {
    enum Stage: Equatable { case idle, ready, running, success, failed }

    @Published private(set) var backupFile: URL?
    @Published private(set) var kind: WordPressBackupKind?
    @Published var siteName = ""
    @Published var phpVersion = BundledPHP.defaultVersion
    @Published var secure = true
    @Published var trusted = false
    @Published private(set) var stage: Stage = .idle
    @Published private(set) var phase: RestorePhase?
    @Published private(set) var message = ""
    @Published private(set) var warnings: [String] = []
    @Published private(set) var resultSite: Site?
    @Published var error: String?

    private var task: Task<Void, Never>?

    var canRestore: Bool {
        backupFile != nil && kind != nil && !siteName.isEmpty && trusted && stage != .running
    }

    func selectFile(_ url: URL, installed: [String]) {
        do {
            let detected = try WordPressBackupInspector().inspect(url)
            kind = detected
            backupFile = url
            if siteName.isEmpty { siteName = Self.suggestName(from: url) }
            if !installed.contains(phpVersion) { phpVersion = installed.first ?? BundledPHP.defaultVersion }
            error = nil
            stage = .ready
        } catch {
            self.error = error.localizedDescription
            kind = nil
            backupFile = nil
            stage = .idle
        }
    }

    func restore(registry: SiteRegistry, server: LocalServerController) {
        guard let backupFile, canRestore else { return }
        stage = .running
        error = nil
        warnings = []
        phase = .detecting
        message = ""

        let request = RestoreRequest(backupFile: backupFile, siteName: siteName,
                                     phpVersion: phpVersion, secure: secure)
        let paths = AppSupportPaths()
        let mysql = MySQLController(paths: paths, agents: LaunchAgentManager(paths: paths))
        let mkcert = MkcertRunner(mkcert: paths.mkcertBinary, caroot: paths.caDir)
        let httpsProvisioner = SiteHTTPSProvisioner(paths: paths, tld: registry.tld,
                                                    mkcert: mkcert,
                                                    certMinter: CertMinter(paths: paths, runner: mkcert))
        let service = WordPressRestoreService(
            paths: paths,
            ensureEngine: { try await mysql.start() },
            register: { folder, database in
                try await MainActor.run {
                    try registry.add(folder: folder, phpVersion: request.phpVersion,
                                     respectProjectMarkers: false, databaseName: database)
                }
            },
            unregister: { site in await MainActor.run { registry.remove(site) } },
            applyServerConfig: { await MainActor.run { server.reconcileAfterRuntimeChange() } },
            enableHTTPS: { site in
                try httpsProvisioner.enableHTTPS(for: site)
                await MainActor.run { registry.setSecure(site, true) }
            })

        task = Task {
            do {
                let outcome = try await service.restore(request) { event in
                    Task { @MainActor in
                        self.phase = event.phase
                        self.message = event.message
                    }
                }
                self.resultSite = outcome.site
                self.warnings = outcome.warnings
                self.stage = .success
            } catch is CancellationError {
                self.error = "Restore cancelled."
                self.stage = .failed
            } catch {
                self.error = error.localizedDescription
                self.stage = .failed
            }
        }
    }

    func cancel() { task?.cancel() }

    static func suggestName(from url: URL) -> String {
        let stem = url.deletingPathExtension().lastPathComponent
        let head = stem.split(separator: "-").prefix(2).joined(separator: "-")
        return head.isEmpty ? stem : head
    }
}
