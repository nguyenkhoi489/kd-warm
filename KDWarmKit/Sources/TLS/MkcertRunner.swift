import Foundation

/// Thin wrapper over the vendored `mkcert` binary — the single source of cert material. mkcert
/// already handles the parts that silently break hand-rolled X.509 (SAN, `EKU=serverAuth`,
/// `basicConstraints CA:TRUE`, trust-store install), so KDWarm never mints certs in Swift.
///
/// `CAROOT` is pinned to the app-support `config/ca/` dir, so the CA key/cert live there (key 600,
/// never over XPC). `mkcert -install` writes the System Keychain (GUI admin prompt) AND the
/// Firefox/NSS store (`certutil`, user-level, skipped when Firefox is absent). The privileged
/// helper offers an equivalent System-Keychain install for the signed Phase 9 path.
public struct MkcertRunner {
    public let mkcert: URL
    public let caroot: URL

    public init(mkcert: URL, caroot: URL) {
        self.mkcert = mkcert
        self.caroot = caroot
    }

    /// True once the CA has been generated (rootCA.pem present in CAROOT).
    public var caExists: Bool {
        FileManager.default.fileExists(atPath: caroot.appendingPathComponent("rootCA.pem").path)
    }

    /// Generate (if needed) + install the CA into the System Keychain and Firefox/NSS. Idempotent.
    public func install() throws { try run(["-install"]) }

    /// Remove the CA from the trust stores (browsers warn again). Leaves the CA material on disk.
    public func uninstall() throws { try run(["-uninstall"]) }

    /// Mint a leaf for `domain` into the given files (signed by the CAROOT CA; SAN/EKU by mkcert).
    public func mint(domain: String, certFile: URL, keyFile: URL) throws {
        try FileManager.default.createDirectory(at: certFile.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try run(Self.mintArgs(domain: domain, certFile: certFile, keyFile: keyFile))
    }

    /// Exposed for testing — the exact mint argument vector.
    public static func mintArgs(domain: String, certFile: URL, keyFile: URL) -> [String] {
        ["-cert-file", certFile.path, "-key-file", keyFile.path, domain]
    }

    @discardableResult
    private func run(_ args: [String]) throws -> String {
        let proc = Process()
        proc.executableURL = mkcert
        proc.arguments = args
        proc.environment = ["CAROOT": caroot.path, "PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try FileManager.default.createDirectory(at: caroot, withIntermediateDirectories: true,
                                                attributes: [.posixPermissions: 0o700])
        try proc.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        let output = String(data: data, encoding: .utf8) ?? ""
        guard proc.terminationStatus == 0 else {
            throw NSError(domain: "KDWarm.mkcert", code: Int(proc.terminationStatus),
                          userInfo: [NSLocalizedDescriptionKey: "mkcert \(args.first ?? "") failed: \(output)"])
        }
        return output
    }
}
