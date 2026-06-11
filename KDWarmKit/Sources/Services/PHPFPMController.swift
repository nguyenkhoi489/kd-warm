import Foundation

/// Starts/stops one php-fpm master + pool, supervised by `ManagedProcess`. `poolName` doubles
/// as the pool key and socket suffix (`run/php-fpm-<poolName>.sock`); `PHPFPMPoolManager` keys
/// pools by PHP version, so `poolName` is the version (e.g. "8.4") and `executable` the matching
/// versioned binary.
///
/// Phase 2 runs the master as a foreground dev-shim child (`-F`), killed when the app quits.
/// Phase 6 promotes this to a launchd-managed service that persists across app quit.
public final class PHPFPMController: @unchecked Sendable {
    public let poolName: String
    private let paths: AppSupportPaths
    private let executable: URL
    private let poolWriter: PHPFPMPoolWriter
    private let lock = NSLock()
    private var managed: ManagedProcess?

    /// Called off the main thread when the master exits.
    public var onExit: (@Sendable (ManagedProcess.State) -> Void)?

    /// - Parameter executable: the php-fpm binary for this pool's version; defaults to the
    ///   unversioned `bin/php-fpm` (Phase 2's PHP 8.4).
    public init(paths: AppSupportPaths,
                poolName: String = BundledPHP.defaultVersion,
                executable: URL? = nil,
                poolWriter: PHPFPMPoolWriter = PHPFPMPoolWriter()) {
        self.paths = paths
        self.poolName = poolName
        self.executable = executable ?? paths.phpFpmBinary
        self.poolWriter = poolWriter
    }

    public var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }
        return managed?.isRunning ?? false
    }

    /// Render the pool config and launch the foreground master.
    public func start() throws {
        lock.lock()
        guard managed == nil else { lock.unlock(); return }
        lock.unlock()

        let poolConf = try poolWriter.write(paths: paths, poolName: poolName)
        // Stale socket from a crash would make nginx see a dead socket — clear it first.
        try? FileManager.default.removeItem(at: paths.phpFpmSocket(poolName))

        let proc = ManagedProcess(
            label: "php-fpm[\(poolName)]",
            executable: executable,
            arguments: ["-p", paths.root.path, "-y", poolConf.path, "-F"],
            workingDirectory: paths.root,
            logFile: paths.phpFpmLog(poolName))
        proc.onTerminate = { [weak self] state in
            self?.lock.lock(); self?.managed = nil; self?.lock.unlock()
            self?.onExit?(state)
        }
        try proc.start()

        lock.lock(); managed = proc; lock.unlock()
    }

    public func stop(grace: TimeInterval = 3.0) {
        lock.lock(); let p = managed; managed = nil; lock.unlock()
        p?.stop(gracePeriod: grace)
        try? FileManager.default.removeItem(at: paths.phpFpmSocket(poolName))
    }
}
