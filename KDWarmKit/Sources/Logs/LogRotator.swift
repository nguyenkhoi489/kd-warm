import Foundation

/// Size-based rotation for app-support logs so a long-running dev box doesn't fill the disk. When a
/// log exceeds `maxBytes` it is rolled to `<name>.1`, `<name>.2`, … (older ones shifted up, the
/// oldest beyond `keep` deleted) and the live file is truncated to empty. Cheap to call on every
/// service start and on a periodic check; it never touches a file under the size threshold and never
/// blocks the tail viewer (truncation is in-place, so the reader's offset just resets).
public struct LogRotator: Sendable {
    public let maxBytes: Int
    public let keep: Int

    public init(maxBytes: Int = 5 * 1024 * 1024, keep: Int = 3) {
        self.maxBytes = maxBytes
        self.keep = keep
    }

    /// Rotate every `*.log` in `logs/` (and `logs/sites/`) that is over the size threshold.
    public func rotateOversized(in paths: AppSupportPaths) {
        for dir in [paths.logs, paths.logsSites] {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { continue }
            for file in files where file.pathExtension == "log" {
                rotateIfNeeded(file)
            }
        }
    }

    /// Rotate a single log if it is over `maxBytes`.
    public func rotateIfNeeded(_ url: URL) {
        let fm = FileManager.default
        let size = ((try? fm.attributesOfItem(atPath: url.path))?[.size] as? Int) ?? 0
        guard size > maxBytes else { return }

        // Drop the oldest, shift the rest up (.2→.3, .1→.2), current→.1.
        try? fm.removeItem(at: url.appendingPathExtension("\(keep)"))
        for n in stride(from: keep - 1, through: 1, by: -1) {
            let from = url.appendingPathExtension("\(n)")
            guard fm.fileExists(atPath: from.path) else { continue }
            try? fm.moveItem(at: from, to: url.appendingPathExtension("\(n + 1)"))
        }
        try? fm.copyItem(at: url, to: url.appendingPathExtension("1"))
        // Truncate the live file in place (copytruncate). Safe here because rotation runs at web-server
        // START (services down / about to (re)open their logs), and nginx/php-fpm open logs with
        // O_APPEND — so a writer holding the fd keeps appending at EOF after truncation (no sparse hole).
        try? Data().write(to: url)
    }
}
