import Foundation

/// Renders one nginx vhost per registered site into `sites-enabled/<domain>.conf`, using the
/// template that matches each site's type (PHP → fastcgi to its version socket; static/node →
/// `try_files`, no fastcgi). Output is deterministic and idempotent: regenerating identical
/// input rewrites nothing, so the orchestrator can skip a needless `nginx -s reload`.
public struct SiteConfigGenerator {
    private let paths: AppSupportPaths
    private let writer = NginxConfigWriter()
    private let tls = NginxTLSVhostWriter()

    public init(paths: AppSupportPaths) {
        self.paths = paths
    }

    /// vhost text for a site, by type + secure flag. A secured site (with a minted leaf present)
    /// gets an HTTPS server (`0.0.0.0:443`) + an `:80 → :443` redirect; otherwise a plain http server.
    /// PHP routes to `run/php-fpm-<version>.sock`.
    public func vhostText(for site: Site, port: Int) -> String {
        let root = URL(fileURLWithPath: site.docroot)
        let socket = site.type == .php ? paths.phpFpmSocket(site.phpVersion) : nil

        if site.secure, certPresent(for: site) {
            return tls.redirectVhost(domain: site.domain) + "\n\n"
                + tls.secureVhost(domain: site.domain, root: root,
                                  certFile: paths.siteCert(site.domain), keyFile: paths.siteKey(site.domain),
                                  phpFpmSocket: socket)
        }
        switch site.type {
        case .php:
            return writer.vhost(domain: site.domain, root: root, phpFpmSocket: socket!, port: port)
        case .staticSite, .node:
            return writer.vhostStatic(domain: site.domain, root: root, port: port)
        }
    }

    /// A secured site needs both leaf files present to emit an https vhost (else fall back to http).
    private func certPresent(for site: Site) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: paths.siteCert(site.domain).path)
            && fm.fileExists(atPath: paths.siteKey(site.domain).path)
    }

    /// Write the master config + one vhost per valid site, and delete vhosts for sites no longer
    /// present. Returns `true` if anything on disk changed (caller reloads nginx only then).
    /// Invalid sites (bad domain/path) are skipped so one bad entry can't break the others.
    @discardableResult
    public func generate(sites: [Site], port: Int = 80) throws -> Bool {
        var changed = false
        changed = try writeIfChanged(writer.masterConfig(paths: paths), to: paths.nginxConf) || changed

        // Every registered site's vhost filename — KEEP all of these on the orphan sweep, even a
        // site we skip writing this pass (bad docroot). Only a site truly REMOVED from the
        // registry should have its vhost deleted; a transient skip must not silently delete a
        // valid site's config.
        var registeredFiles = Set<String>()
        for site in sites where NginxConfigWriter.isValidDomain(site.domain) {
            registeredFiles.insert(paths.vhost(site.domain).lastPathComponent)
        }

        for site in sites {
            guard NginxConfigWriter.isValidDomain(site.domain),
                  NginxConfigWriter.isSafePath(site.docroot) else {
                NSLog("KDWarm: skipping site with invalid domain/path: \(site.domain)")
                continue
            }
            changed = try writeIfChanged(vhostText(for: site, port: port), to: paths.vhost(site.domain)) || changed
        }

        changed = removeOrphanVhosts(keeping: registeredFiles) || changed
        return changed
    }

    /// PHP versions that at least one PHP site needs — drives `PHPFPMPoolManager.reconcile`.
    public static func requiredVersions(for sites: [Site]) -> Set<String> {
        Set(sites.filter { $0.type == .php }.map(\.phpVersion))
    }

    // MARK: - Private

    private func writeIfChanged(_ content: String, to url: URL) throws -> Bool {
        if let existing = try? String(contentsOf: url, encoding: .utf8), existing == content {
            return false
        }
        try content.write(to: url, atomically: true, encoding: .utf8)
        return true
    }

    /// Remove `*.conf` in sites-enabled that no current site wants. Returns whether any were removed.
    private func removeOrphanVhosts(keeping desired: Set<String>) -> Bool {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: paths.sitesEnabled,
                                                      includingPropertiesForKeys: nil) else { return false }
        var removed = false
        for file in files where file.pathExtension == "conf" && !desired.contains(file.lastPathComponent) {
            try? fm.removeItem(at: file)
            removed = true
        }
        return removed
    }
}
