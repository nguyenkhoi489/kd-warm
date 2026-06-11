import Foundation

/// XPC contract between the app (client) and the privileged helper (root). This is the WHOLE
/// privileged attack surface — keep it minimal and DNS/resolver-scoped. Phase 5 adds exactly two
/// CA methods and nothing else.
///
/// Reply types are ObjC-compatible primitives (no custom structs across the boundary); the app
/// rebuilds `HelperDNSStatus` from the `dnsStatus` reply tuple.
@objc public protocol HelperXPCProtocol {
    /// Liveness probe; replies with the helper's bundle version.
    func ping(reply: @escaping (String) -> Void)

    /// Write `/etc/resolver/test` + start dnsmasq so `*.test → 127.0.0.1`. Idempotent.
    func enableDNS(reply: @escaping (Bool, String?) -> Void)

    /// Remove `/etc/resolver/test` + stop dnsmasq. Idempotent.
    func disableDNS(reply: @escaping (Bool, String?) -> Void)

    /// Reconcile actual vs desired: purge a stale resolver, restart dnsmasq, re-write the resolver.
    func resetDNS(reply: @escaping (Bool, String?) -> Void)

    /// Status: resolver present? dnsmasq running? name of a process holding :53 (conflict), else nil.
    func dnsStatus(reply: @escaping (Bool, Bool, String?) -> Void)

    /// Helper bundle version — used to reconcile after an app/helper update.
    func helperVersion(reply: @escaping (String) -> Void)
}

/// App-side view of the helper's DNS state, rebuilt from the `dnsStatus` reply.
public struct HelperDNSStatus: Sendable, Equatable {
    public let resolverPresent: Bool
    public let dnsmasqRunning: Bool
    /// Non-nil when another process holds `127.0.0.1:53` (e.g. Herd/Valet).
    public let conflictProcess: String?

    public init(resolverPresent: Bool, dnsmasqRunning: Bool, conflictProcess: String?) {
        self.resolverPresent = resolverPresent
        self.dnsmasqRunning = dnsmasqRunning
        self.conflictProcess = conflictProcess
    }

    /// DNS is fully up: resolver written, dnsmasq running, no port conflict.
    public var isHealthy: Bool { resolverPresent && dnsmasqRunning && conflictProcess == nil }

    public static let unknown = HelperDNSStatus(resolverPresent: false, dnsmasqRunning: false, conflictProcess: nil)
}
