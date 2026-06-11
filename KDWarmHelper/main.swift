import Foundation

/// Privileged helper entry point. Stands up the Mach-service XPC listener; every incoming
/// connection is gated by `HelperSignatureValidator` (audit-token + pinned code requirement)
/// before the DNS surface is exported. On the dev/ad-hoc build (no Team ID) the validator trusts
/// nobody, so the helper accepts no connections — the live privileged path is gated on Phase 9 signing.
let helperBundleVersion = "0.1.0"

/// The exported XPC object — thin delegation to `HelperDNSManager`. The whole privileged surface.
final class HelperService: NSObject, HelperXPCProtocol {
    private let dns = HelperDNSManager()

    func ping(reply: @escaping (String) -> Void) { reply(helperBundleVersion) }
    func helperVersion(reply: @escaping (String) -> Void) { reply(helperBundleVersion) }

    func enableDNS(reply: @escaping (Bool, String?) -> Void) {
        let r = dns.enableDNS(); reply(r.0, r.1)
    }
    func disableDNS(reply: @escaping (Bool, String?) -> Void) {
        let r = dns.disableDNS(); reply(r.0, r.1)
    }
    func resetDNS(reply: @escaping (Bool, String?) -> Void) {
        let r = dns.resetDNS(); reply(r.0, r.1)
    }
    func dnsStatus(reply: @escaping (Bool, Bool, String?) -> Void) {
        let s = dns.status(); reply(s.resolverPresent, s.dnsmasqRunning, s.conflict)
    }
}

final class HelperListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        guard HelperSignatureValidator.isTrustedClient(connection) else { return false }
        connection.exportedInterface = NSXPCInterface(with: HelperXPCProtocol.self)
        connection.exportedObject = HelperService()
        connection.resume()
        return true
    }
}

let delegate = HelperListenerDelegate()
let listener = NSXPCListener(machServiceName: HelperIdentity.machServiceName)
listener.delegate = delegate
listener.resume()
dispatchMain()
