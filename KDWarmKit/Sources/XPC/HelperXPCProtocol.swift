import Foundation

/// XPC contract between the app and the privileged helper.
///
/// Stub for Phase 1 — only a liveness probe exists. The concrete privileged surface
/// (writing `/etc/resolver/test`, running dnsmasq, installing the local CA into the
/// System Keychain) plus signature-validated connection acceptance land in Phase 4.
@objc public protocol HelperXPCProtocol {
    /// Liveness probe; replies with the helper's bundle version string.
    func ping(reply: @escaping (String) -> Void)
}

/// Shared identity constants referenced by the app (XPC client) and, from Phase 4,
/// the helper's SMAppService registration + launchd plist label.
public enum HelperIdentity {
    public static let machServiceName = "com.kdwarm.helper"
    public static let bundleIdentifier = "com.kdwarm.helper"
}
