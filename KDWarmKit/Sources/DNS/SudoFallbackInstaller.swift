import Foundation

/// One-time `sudo` path to enable `.test` DNS WITHOUT the SMAppService helper — the safety net for
/// when the user misses/declines the background-item approval. It performs the SAME root operations
/// as the helper (copy dnsmasq to a root dir, write config + `/etc/resolver/test` + a launchd daemon
/// plist, bootstrap dnsmasq), sourced from the same `DNSConstants`, so behaviour can't diverge.
///
/// Security: every value interpolated into the root-run script is single-quote-escaped (`shellQuote`),
/// and the script is staged in a freshly-created `0700` per-run directory (no fixed, predictable path
/// another same-user process could swap before root reads it).
public struct SudoFallbackInstaller {
    /// The bundled dnsmasq to copy into the root support dir (`KDWarm.app/Contents/Resources/bin/dnsmasq`).
    public let bundledDnsmasq: URL

    public init(bundledDnsmasq: URL) {
        self.bundledDnsmasq = bundledDnsmasq
    }

    /// Root install script — idempotent: re-running re-bootstraps with the current config.
    public func installScript() -> String { "#!/bin/bash\nset -euo pipefail\n" + installBody() }

    /// Root uninstall script — full cleanup (reverses installScript).
    public func uninstallScript() -> String { "#!/bin/bash\nset -uo pipefail\n" + uninstallBody() }

    /// Combined reset: uninstall then install in ONE root invocation (single admin prompt).
    public func resetScript() -> String {
        "#!/bin/bash\nset -uo pipefail\n" + uninstallBody() + "\nset -e\n" + installBody()
    }

    // MARK: - Script bodies (no shebang) — composed by the public scripts above.

    private func installBody() -> String {
        """
        mkdir -p \(q("\(DNSConstants.supportDir)/bin"))
        cp \(q(bundledDnsmasq.path)) \(q(DNSConstants.dnsmasqBinaryPath))
        chmod 0755 \(q(DNSConstants.dnsmasqBinaryPath))

        cat > \(q(DNSConstants.dnsmasqConfPath)) <<'KDWARM_CONF'
        \(DNSConstants.dnsmasqConf)
        KDWARM_CONF

        mkdir -p /etc/resolver
        cat > \(q(DNSConstants.resolverPath)) <<'KDWARM_RESOLVER'
        \(DNSConstants.resolverContents)KDWARM_RESOLVER

        cat > \(q(DNSConstants.daemonPlistPath)) <<'KDWARM_PLIST'
        \(DNSConstants.daemonPlist)
        KDWARM_PLIST
        chmod 0644 \(q(DNSConstants.daemonPlistPath))

        launchctl bootout system/\(DNSConstants.daemonLabel) 2>/dev/null || true
        launchctl bootstrap system \(q(DNSConstants.daemonPlistPath))
        echo "KDWarm DNS enabled — *.\(DNSConstants.tld) resolves to 127.0.0.1"
        """
    }

    private func uninstallBody() -> String {
        """
        launchctl bootout system/\(DNSConstants.daemonLabel) 2>/dev/null || true
        rm -f \(q(DNSConstants.resolverPath)) \(q(DNSConstants.daemonPlistPath)) \(q(DNSConstants.dnsmasqConfPath))
        rm -f \(q(DNSConstants.dnsmasqBinaryPath))
        echo "KDWarm DNS disabled — *.\(DNSConstants.tld) no longer resolves locally"
        """
    }

    /// Single-quote-escape a value for safe interpolation into the root shell script.
    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
    private func q(_ value: String) -> String { Self.shellQuote(value) }

    // MARK: - Staging + execution

    /// Write all three scripts into a FRESH `0700` per-run dir (no predictable path to swap), and
    /// return their URLs.
    @discardableResult
    public func writeScripts(to dir: URL) throws -> (install: URL, uninstall: URL, reset: URL) {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        let install = dir.appendingPathComponent("install.sh")
        let uninstall = dir.appendingPathComponent("uninstall.sh")
        let reset = dir.appendingPathComponent("reset.sh")
        try installScript().write(to: install, atomically: true, encoding: .utf8)
        try uninstallScript().write(to: uninstall, atomically: true, encoding: .utf8)
        try resetScript().write(to: reset, atomically: true, encoding: .utf8)
        for s in [install, uninstall, reset] {
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: s.path)
        }
        return (install, uninstall, reset)
    }

    /// A fresh, unguessable, user-only staging dir for one run.
    public static func freshStagingDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("kdwarm-dns-\(UUID().uuidString)")
    }

    public func runInstallWithAdminPrivileges() throws {
        try runAsAdmin(try writeScripts(to: Self.freshStagingDir()).install.path)
    }
    public func runUninstallWithAdminPrivileges() throws {
        try runAsAdmin(try writeScripts(to: Self.freshStagingDir()).uninstall.path)
    }
    public func runResetWithAdminPrivileges() throws {
        try runAsAdmin(try writeScripts(to: Self.freshStagingDir()).reset.path)
    }

    /// Run `bash <scriptPath>` via a GUI admin-authentication prompt. `scriptPath` lives in a
    /// freshly-created UUID dir under the user's `$TMPDIR` (no shell metacharacters by construction);
    /// it is additionally AppleScript-string-escaped and shell-quoted via `quoted form of`, so the
    /// root invocation is safe even if the path ever changed shape.
    private func runAsAdmin(_ scriptPath: String) throws {
        let asEscaped = scriptPath
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let osa = "do shell script \"/bin/bash \" & quoted form of \"\(asEscaped)\" with administrator privileges"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", osa]
        try proc.run()
        proc.waitUntilExit()
        if proc.terminationStatus != 0 {
            throw NSError(domain: "KDWarm", code: Int(proc.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "Admin authorization was cancelled or failed."])
        }
    }
}
