import Foundation
import Combine

/// Orchestrates the multi-site web stack: nginx + one php-fpm pool per active PHP version,
/// driven by the `SiteRegistry`. On start it stages binaries, generates a vhost per registered
/// site, reconciles the pool set, and boots nginx. While running, any registry change (add /
/// remove / edit-domain / version / folder-watch re-inspect) regenerates configs, reconciles
/// pools, and hot-reloads nginx.
///
/// Children are dev-shim processes killed on app quit (Phase 6 promotes them to launchd).
@MainActor
public final class LocalServerController: ObservableObject {
    @Published public private(set) var nginxStatus: ServiceStatus = .stopped
    @Published public private(set) var phpStatus: ServiceStatus = .stopped
    @Published public private(set) var isBusy = false
    @Published public private(set) var lastError: String?

    public let httpPort = 80
    public let registry: SiteRegistry

    // These collaborators are Sendable and used from the off-main `applyConfiguration` work, so
    // they are explicitly nonisolated (avoids a Swift 6 main-actor isolation error).
    nonisolated private let paths: AppSupportPaths
    nonisolated private let nginx: NginxController
    nonisolated private let pools: PHPFPMPoolManager
    nonisolated private let generator: SiteConfigGenerator
    nonisolated private let stager: BinaryStager
    nonisolated private let preflight = PortPreflight()
    nonisolated private let watcher = RegisteredSiteWatcher()
    private var didSeed = false
    private var pendingReconcile = false

    public init(bundleBinDir: URL, paths: AppSupportPaths = AppSupportPaths()) {
        self.paths = paths
        self.registry = SiteRegistry(storeURL: paths.sitesRegistryFile)
        self.nginx = NginxController(paths: paths)
        self.pools = PHPFPMPoolManager(paths: paths)
        self.generator = SiteConfigGenerator(paths: paths)
        self.stager = BinaryStager(bundleBinDir: bundleBinDir, paths: paths)

        nginx.onExit = { [weak self] state in
            Task { @MainActor in self?.handleUnexpectedExit("Nginx", state) }
        }
        pools.onPoolExit = { [weak self] version, state in
            Task { @MainActor in self?.handleUnexpectedExit("PHP-FPM \(version)", state) }
        }
        registry.onChange = { [weak self] in self?.onRegistryChanged() }
        watcher.onChange = { [weak self] folder in
            Task { @MainActor in self?.handleFolderChange(folder) }
        }
    }

    public var isRunning: Bool { nginxStatus == .running }

    /// PHP versions whose binary is actually bundled (the per-site picker offers only these).
    public var availableVersions: [String] {
        let v = BundledPHP.availableVersions(in: paths.bin)
        return v.isEmpty ? [BundledPHP.defaultVersion] : v
    }

    public func toggle() { isRunning ? stop() : start() }

    public func start() {
        guard !isBusy, !isRunning else { return }
        isBusy = true; lastError = nil
        nginxStatus = .starting; phpStatus = .starting
        ensureSeed()
        let sites = registry.sites
        let port = httpPort
        Task.detached(priority: .userInitiated) { [stager, self] in
            do {
                try stager.stageIfNeeded()
                let missing = try await self.applyConfiguration(sites: sites, port: port, startNginx: true)
                await self.finish(missing: missing, error: nil)
            } catch {
                self.pools.stopAll(); self.nginx.stop()
                await self.finish(missing: [], error: error.localizedDescription)
            }
        }
    }

    public func stop() {
        guard !isBusy else { return }
        isBusy = true
        Task.detached(priority: .userInitiated) { [nginx, pools, self] in
            nginx.stop()
            pools.stopAll()
            await MainActor.run {
                self.nginxStatus = .stopped; self.phpStatus = .stopped; self.isBusy = false
                self.watcher.stop()
            }
        }
    }

    /// Synchronous, short-grace teardown for `applicationWillTerminate` (no orphaned children).
    public func shutdownForQuit() {
        nginx.stop(grace: 0.5)
        pools.stopAll(grace: 0.5)
        watcher.stop()
    }

    // MARK: - Reconcile

    private func onRegistryChanged() {
        guard isRunning else { refreshWatches(); return }
        guard !isBusy else { pendingReconcile = true; return }
        reconcile()
    }

    private func reconcile() {
        isBusy = true
        let sites = registry.sites
        let port = httpPort
        Task.detached(priority: .userInitiated) { [self] in
            do {
                let missing = try await self.applyConfiguration(sites: sites, port: port, startNginx: false)
                await self.finish(missing: missing, error: nil)
            } catch {
                await self.finish(missing: [], error: error.localizedDescription)
            }
        }
    }

    /// Generate vhosts → reconcile pools → wait for sockets → start or reload nginx. Returns the
    /// required PHP versions whose binary isn't bundled yet (surfaced as a non-fatal warning).
    private nonisolated func applyConfiguration(sites: [Site], port: Int, startNginx: Bool) async throws -> [String] {
        let changed = try generator.generate(sites: sites, port: port)
        let missing = try pools.reconcile(required: SiteConfigGenerator.requiredVersions(for: sites))
        for version in pools.activeVersions {
            try await Self.waitForSocket(pools.socket(for: version))
        }
        if startNginx {
            switch preflight.check(port: port) {
            case .available: break
            case .inUse(_, let m), .blocked(let m): throw NSError(domain: "KDWarm", code: 2,
                userInfo: [NSLocalizedDescriptionKey: m])
            }
            try nginx.start()
        } else if changed {
            do { try nginx.reload() }
            catch { NSLog("KDWarm: nginx reload failed: \(error.localizedDescription)") }
        }
        return missing
    }

    // MARK: - State

    private func finish(missing: [String], error: String?) {
        isBusy = false
        if let error { lastError = error }
        else if !missing.isEmpty {
            lastError = "PHP \(missing.joined(separator: ", ")) not bundled yet (arrives in Phase 7); those sites won't serve."
        }
        recomputeStatus()
        refreshWatches()
        if pendingReconcile { pendingReconcile = false; reconcile() }
    }

    private func recomputeStatus() {
        nginxStatus = nginx.isRunning ? .running : .stopped
        let active = pools.activeVersions
        let allUp = !active.isEmpty && active.allSatisfy { pools.isRunning(version: $0) }
        let anyPHP = registry.sites.contains { $0.type == .php }
        phpStatus = allUp ? .running : (anyPHP && nginx.isRunning ? .error : .stopped)
    }

    private func handleUnexpectedExit(_ who: String, _ state: ManagedProcess.State) {
        if !isBusy, case .failed(let reason) = state {
            lastError = "\(who) exited unexpectedly: \(reason)"
        }
        recomputeStatus()
    }

    private func handleFolderChange(_ folder: URL) {
        // Re-inspect only the matching registered site; registry.onChange drives the reconcile.
        for site in registry.sites where site.path == folder.path {
            registry.reinspect(site)
        }
    }

    private func refreshWatches() {
        watcher.watch(registry.sites.map { URL(fileURLWithPath: $0.path) })
    }

    /// Seed a demo PHP site on first run so a fresh install has something to serve.
    private func ensureSeed() {
        guard !didSeed, registry.sites.isEmpty else { didSeed = true; return }
        didSeed = true
        let demo = AppSupportPaths.defaultSitesRoot.appendingPathComponent("demo", isDirectory: true)
        try? Self.provisionSampleSite(at: demo.appendingPathComponent("public", isDirectory: true), domain: "demo.test")
        try? registry.add(folder: demo)
    }

    private nonisolated static func waitForSocket(_ url: URL, timeout: TimeInterval = 5) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path) { return }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw NSError(domain: "KDWarm", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "php-fpm socket did not appear in time."])
    }

    private nonisolated static func provisionSampleSite(at docroot: URL, domain: String) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: docroot, withIntermediateDirectories: true)
        let index = docroot.appendingPathComponent("index.php")
        guard !fm.fileExists(atPath: index.path) else { return }
        let body = """
        <?php
        // KDWarm demo site — served at http://\(domain).
        echo "<h1>KDWarm · \(domain) is live</h1>";
        phpinfo();
        """
        try body.write(to: index, atomically: true, encoding: .utf8)
    }
}
