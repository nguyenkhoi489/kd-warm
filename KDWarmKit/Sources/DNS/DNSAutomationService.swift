import Foundation
import Combine

/// App-side DNS automation. When a signing identity exists (Phase 9) it drives the privileged
/// helper over XPC; otherwise it uses the `sudo` fallback — so `.test` DNS works either way.
/// Status is derived from the filesystem (resolver file + `:53` ownership), so the UI reflects
/// reality without the helper being approved.
///
/// NOTE: on the current dev/ad-hoc build `usesHelper` is false, so the XPC branch never runs — the
/// fallback is the live path. The helper branch is wired (not dead) and goes live in Phase 9.
@MainActor
public final class DNSAutomationService: ObservableObject {
    public enum Status: Equatable, Sendable {
        case unknown
        case disabled                 // no /etc/resolver/test
        case enabled                  // resolver present
        case conflict(String)         // a foreign process holds :53
    }

    @Published public private(set) var status: Status = .unknown
    @Published public private(set) var isBusy = false
    @Published public private(set) var lastError: String?

    /// True once the build can use the live SMAppService helper (Phase 9); false on dev → fallback.
    public let usesHelper = HelperIdentity.hasSigningIdentity

    nonisolated private let fallback: SudoFallbackInstaller
    nonisolated private let port53 = Port53ConflictDetector()
    nonisolated private let helper = HelperConnection()

    public init(bundledDnsmasq: URL) {
        self.fallback = SudoFallbackInstaller(bundledDnsmasq: bundledDnsmasq)
        refresh()
    }

    private enum Op { case enable, disable, reset }

    /// Recompute status from the live system state.
    public func refresh() {
        if let conflict = port53.check() { status = .conflict(conflict.process); return }
        status = FileManager.default.fileExists(atPath: DNSConstants.resolverPath) ? .enabled : .disabled
    }

    public var isEnabled: Bool { status == .enabled }

    public func enable() { perform(.enable) }
    public func disable() { perform(.disable) }
    /// Reconcile a stale/hijacked state — one root invocation (single admin prompt).
    public func reset() { perform(.reset) }

    // MARK: - Private

    private func perform(_ op: Op) {
        guard !isBusy else { return }
        if op != .disable, let conflict = port53.check() {
            lastError = conflict.message; status = .conflict(conflict.process); return
        }
        isBusy = true; lastError = nil
        let usesHelper = self.usesHelper
        let fallback = self.fallback
        let helper = self.helper
        Task.detached(priority: .userInitiated) {
            var failure: String?
            do {
                if usesHelper { try await Self.viaHelper(helper, op) }
                else { try Self.viaFallback(fallback, op) }
            } catch {
                failure = error.localizedDescription
            }
            await MainActor.run {
                self.isBusy = false
                if let failure { self.lastError = failure }
                self.refresh()
            }
        }
    }

    nonisolated private static func viaFallback(_ f: SudoFallbackInstaller, _ op: Op) throws {
        switch op {
        case .enable:  try f.runInstallWithAdminPrivileges()
        case .disable: try f.runUninstallWithAdminPrivileges()
        case .reset:   try f.runResetWithAdminPrivileges()
        }
    }

    /// Live XPC path (Phase 9). Bridges the callback-based helper reply into async, resuming once.
    nonisolated private static func viaHelper(_ helper: HelperConnection, _ op: Op) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let guard1 = ResumeOnce(cont)
            guard let proxy = helper.remoteProxy({ guard1.fail($0) }) else {
                guard1.fail(NSError(domain: "KDWarm", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "Privileged helper is not available."]))
                return
            }
            let reply: @Sendable (Bool, String?) -> Void = { ok, msg in
                if ok { guard1.succeed() }
                else { guard1.fail(NSError(domain: "KDWarm", code: -2,
                                           userInfo: [NSLocalizedDescriptionKey: msg ?? "Helper DNS action failed."])) }
            }
            switch op {
            case .enable:  proxy.enableDNS(reply: reply)
            case .disable: proxy.disableDNS(reply: reply)
            case .reset:   proxy.resetDNS(reply: reply)
            }
        }
    }

    /// Guards a CheckedContinuation against the double-resume that an XPC error-handler + reply can
    /// otherwise cause (which would crash).
    private final class ResumeOnce: @unchecked Sendable {
        private let cont: CheckedContinuation<Void, Error>
        private let lock = NSLock()
        private var done = false
        init(_ cont: CheckedContinuation<Void, Error>) { self.cont = cont }
        func succeed() { fire { cont.resume() } }
        func fail(_ error: Error) { fire { cont.resume(throwing: error) } }
        private func fire(_ block: () -> Void) {
            lock.lock(); defer { lock.unlock() }
            guard !done else { return }
            done = true; block()
        }
    }
}
