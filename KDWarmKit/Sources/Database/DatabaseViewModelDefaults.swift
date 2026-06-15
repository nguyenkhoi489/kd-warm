import Foundation

/// Production wiring for `DatabaseViewModel`: how a `ConnectionProfile` resolves to a live driver and
/// its secret. Kept apart from the view model's state machine so tests can inject stubs and the VM
/// file stays focused on the selection/result logic.
public extension DatabaseViewModel {
    /// MySQL is the only engine wired for M1; other kinds resolve to nil → an "unsupported engine"
    /// connection failure until their driver phase lands.
    static let defaultDriver: DriverFactory = { profile, password in
        switch profile.kind {
        case .mysql: return MySQLDriver(profile: profile, password: password)
        default:     return nil
        }
    }

    /// The managed engine is passwordless (`--initialize-insecure`); saved profiles read their secret
    /// from the Keychain by profile id.
    static let defaultPassword: @Sendable (ConnectionProfile) -> String? = { profile in
        if profile.isManaged { return nil }
        return try? KeychainStore().get(account: profile.id.uuidString)
    }
}
