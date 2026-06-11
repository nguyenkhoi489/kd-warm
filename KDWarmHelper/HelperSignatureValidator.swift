import Foundation
import Security

/// Validates that an incoming XPC connection comes from the genuine KDWarm app, using the peer's
/// audit token + a pinned code-signing requirement (`HelperIdentity.clientRequirement`).
///
/// Deferred-live: the dev/ad-hoc build has no Team ID, so `hasSigningIdentity` is false and EVERY
/// caller is refused — the helper performs no privileged work until Phase 9 configures Developer
/// ID signing. The audit-token + `SecCode` path below is the real release implementation, exercised
/// once a Team ID exists. (Audit token, not PID, so there is no PID-reuse race.)
enum HelperSignatureValidator {
    /// NSXPCConnection exposes `auditToken` as SPI (not in public headers). Bridge to it through an
    /// `@objc` protocol — the standard technique for race-free peer validation.
    @objc private protocol AuditTokenProvider {
        var auditToken: audit_token_t { get }
    }

    static func isTrustedClient(_ connection: NSXPCConnection) -> Bool {
        guard HelperIdentity.hasSigningIdentity else { return false }   // dev build: trust nobody
        guard let requirement = makeRequirement(HelperIdentity.clientRequirement) else { return false }

        var token = unsafeBitCast(connection, to: AuditTokenProvider.self).auditToken
        let tokenData = Data(bytes: &token, count: MemoryLayout<audit_token_t>.size) as CFData

        var code: SecCode?
        let copyStatus = SecCodeCopyGuestWithAttributes(
            nil, [kSecGuestAttributeAudit: tokenData] as CFDictionary, [], &code)
        guard copyStatus == errSecSuccess, let code else { return false }

        return SecCodeCheckValidity(code, [], requirement) == errSecSuccess
    }

    private static func makeRequirement(_ string: String) -> SecRequirement? {
        var requirement: SecRequirement?
        let status = SecRequirementCreateWithString(string as CFString, [], &requirement)
        return status == errSecSuccess ? requirement : nil
    }
}
