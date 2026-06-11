import Foundation

/// Inspects a registered folder to derive how it should be served: document root, default
/// domain, and site type (php / static / node). Pure value logic — no disk writes — so it is
/// unit-testable against a temp dir.
public struct SiteInspector {
    public struct Result: Equatable, Sendable {
        public let docroot: URL
        public let defaultDomain: String
        public let type: SiteType
    }

    /// Document-root candidates, in priority order. First existing dir wins; else the folder root.
    static let docrootCandidates = ["public", "web", "public_html"]

    public init() {}

    public func inspect(folder: URL, tld: String = "test", fileManager: FileManager = .default) -> Result {
        let docroot = resolveDocroot(folder: folder, fileManager: fileManager)
        let type = classify(folder: folder, docroot: docroot, fileManager: fileManager)
        let domain = "\(Self.slug(folder.lastPathComponent)).\(tld)"
        return Result(docroot: docroot, defaultDomain: domain, type: type)
    }

    private func resolveDocroot(folder: URL, fileManager: FileManager) -> URL {
        for candidate in Self.docrootCandidates {
            let dir = folder.appendingPathComponent(candidate, isDirectory: true)
            var isDir: ObjCBool = false
            if fileManager.fileExists(atPath: dir.path, isDirectory: &isDir), isDir.boolValue {
                return dir
            }
        }
        return folder
    }

    /// Classify by markers, checking the resolved docroot first then the folder root:
    /// `index.php` → php; `package.json` (and no index.php) → node; otherwise static.
    private func classify(folder: URL, docroot: URL, fileManager: FileManager) -> SiteType {
        func has(_ name: String, in dir: URL) -> Bool {
            fileManager.fileExists(atPath: dir.appendingPathComponent(name).path)
        }
        if has("index.php", in: docroot) || has("index.php", in: folder) || has("artisan", in: folder) {
            return .php
        }
        if has("package.json", in: folder) {
            return .node
        }
        return .staticSite
    }

    /// Lowercase, hyphenate, strip anything but `[a-z0-9-]` — safe for a `.test` hostname label.
    public static func slug(_ raw: String) -> String {
        let lowered = raw.lowercased()
        var out = ""
        var lastHyphen = false
        for ch in lowered {
            if ch.isLetter || ch.isNumber {
                out.append(ch); lastHyphen = false
            } else if !lastHyphen {
                out.append("-"); lastHyphen = true
            }
        }
        let trimmed = out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "site" : trimmed
    }
}
