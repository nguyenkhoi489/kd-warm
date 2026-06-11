import Foundation

/// Maps a PHP version string to its bundled php-fpm binary and discovers which versions are
/// actually installed in the staged `bin/`.
///
/// Phase 2 vendored a single PHP (8.4) as an unversioned `php-fpm`. Phase 7 adds the other
/// bundled versions (7.4/8.1/8.3) as `php-fpm-<version>`. This phase builds the multi-version
/// pool ARCHITECTURE but only the default version's binary exists, so `availableVersions`
/// honestly reports what can run today — the per-site version picker offers only these.
public enum BundledPHP {
    /// The version shipped by Phase 2 as the unversioned `php-fpm`.
    public static let defaultVersion = "8.4"

    /// All versions the MVP intends to bundle (Phase 7). Used only to label/sort the picker.
    public static let plannedVersions = ["7.4", "8.1", "8.3", "8.4"]

    /// php-fpm binary for `version` inside `bin`. The default version is the unversioned
    /// `php-fpm`; others are `php-fpm-<version>` (added in Phase 7).
    public static func fpmBinary(for version: String, in bin: URL) -> URL {
        version == defaultVersion
            ? bin.appendingPathComponent("php-fpm")
            : bin.appendingPathComponent("php-fpm-\(version)")
    }

    /// Versions whose php-fpm binary actually exists in `bin`, sorted ascending.
    public static func availableVersions(in bin: URL, fileManager: FileManager = .default) -> [String] {
        plannedVersions
            .filter { fileManager.isExecutableFile(atPath: fpmBinary(for: $0, in: bin).path) }
            .sorted()
    }
}
