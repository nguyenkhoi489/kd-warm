import Foundation
import Combine

/// Drives the Database section: holds the live driver for the selected connection plus the
/// selection chain (connection → database → table) and the current result. `@MainActor` so it only
/// ever publishes from the main actor; every driver call is `async` and returns `Sendable` values,
/// so results cross back from the NIO event loop without a data race (the driver never touches
/// `@Published` state itself).
///
/// A monotonic `generation` token guards against a slow in-flight result from a superseded
/// selection: rapidly switching connections/tables or re-running SQL discards the older result
/// instead of letting it clobber the newer state.
@MainActor
public final class DatabaseViewModel: ObservableObject {

    /// Live state of the selected connection. `failed` carries the typed `DatabaseError` so the view
    /// can route `engineNotInstalled`/`engineNotRunning` to the install/start flow rather than show a
    /// dead-end "connection refused".
    public enum Connection: Equatable {
        case idle
        case connecting
        case connected
        case failed(DatabaseError)
    }

    /// Where the current result came from. A single-table browse has a well-defined target table the
    /// row-edit phase keys edits off; an arbitrary query/JOIN does not, so it stays read-only.
    public enum ResultSource: Equatable {
        case none
        case table(database: String, table: String)
        case query
    }

    @Published public private(set) var connection: Connection = .idle
    @Published public private(set) var selectedProfile: ConnectionProfile?
    @Published public private(set) var databases: [DatabaseInfo] = []
    @Published public private(set) var selectedDatabase: String?
    @Published public private(set) var tables: [TableInfo] = []
    @Published public private(set) var selectedTable: TableInfo?
    @Published public private(set) var result: QueryResult?
    @Published public private(set) var resultError: String?
    @Published public private(set) var resultSource: ResultSource = .none
    @Published public private(set) var isBusy = false
    @Published public private(set) var pageOffset = 0
    /// True while the latest table page came back full (== `pageSize`), so a next page may exist.
    @Published public private(set) var hasMorePages = false

    /// Rows per table page. Bounded default keeps an unbounded `SELECT *` from materializing a huge
    /// table in memory; pagination walks the rest.
    public var pageSize = 100

    /// Editing is only valid against a single-table browse result — a SQL-runner/JOIN result has no
    /// well-defined target table. The row-CRUD phase gates writes on this.
    public var isResultEditable: Bool {
        if case .table = resultSource { return true }
        return false
    }

    public typealias DriverFactory = @Sendable (ConnectionProfile, String?) -> RelationalDriver?

    private let makeDriver: DriverFactory
    private let passwordFor: @Sendable (ConnectionProfile) -> String?
    private var driver: RelationalDriver?

    /// Bumped on every new top-level operation; an async continuation whose token no longer matches
    /// is stale and bails before publishing.
    private var generation = 0

    public init(makeDriver: @escaping DriverFactory = DatabaseViewModel.defaultDriver,
                passwordFor: @escaping @Sendable (ConnectionProfile) -> String? = DatabaseViewModel.defaultPassword) {
        self.makeDriver = makeDriver
        self.passwordFor = passwordFor
    }

    // MARK: - Connection

    /// Open `profile`, verify it serves queries, and load its databases. Resets the selection chain
    /// first so a previous connection's tree never lingers under a new one.
    public func select(profile: ConnectionProfile) async {
        let token = beginOperation()
        selectedProfile = profile
        databases = []; tables = []; selectedDatabase = nil; selectedTable = nil
        result = nil; resultError = nil; resultSource = .none; pageOffset = 0; hasMorePages = false
        connection = .connecting

        guard let driver = makeDriver(profile, passwordFor(profile)) else {
            connection = .failed(.connection("Unsupported engine: \(profile.kind.rawValue)"))
            isBusy = false
            return
        }
        self.driver = driver
        do {
            try await driver.ping()
            let dbs = try await driver.listDatabases()
            guard token == generation else { return }
            databases = dbs
            connection = .connected
        } catch {
            guard token == generation else { return }
            connection = .failed(Self.asDatabaseError(error))
        }
        if token == generation { isBusy = false }
    }

    // MARK: - Schema

    public func select(database: String) async {
        guard let driver else { return }
        let token = beginOperation()
        selectedDatabase = database
        tables = []; selectedTable = nil; result = nil; resultError = nil; resultSource = .none
        do {
            let loaded = try await driver.listTables(database: database)
            guard token == generation else { return }
            tables = loaded
        } catch {
            guard token == generation else { return }
            resultError = Self.asDatabaseError(error).message
        }
        if token == generation { isBusy = false }
    }

    public func select(table: TableInfo) async {
        guard selectedDatabase != nil else { return }
        selectedTable = table
        pageOffset = 0
        await loadPage()
    }

    // MARK: - Pagination

    public func nextPage() async {
        guard hasMorePages else { return }
        pageOffset += pageSize
        await loadPage()
    }

    public func previousPage() async {
        guard pageOffset > 0 else { return }
        pageOffset = max(0, pageOffset - pageSize)
        await loadPage()
    }

    private func loadPage() async {
        guard let driver, let database = selectedDatabase, let table = selectedTable else { return }
        let token = beginOperation()
        do {
            let page = try await driver.paginatedRows(
                database: database, table: table.name, limit: pageSize, offset: pageOffset)
            guard token == generation else { return }
            result = page
            resultError = nil
            resultSource = .table(database: database, table: table.name)
            hasMorePages = page.rowCount == pageSize
        } catch {
            guard token == generation else { return }
            result = nil
            resultError = Self.asDatabaseError(error).message
            resultSource = .none
        }
        if token == generation { isBusy = false }
    }

    // MARK: - SQL runner

    /// Run arbitrary SQL against the selected database. The result is read-only (`.query` source) —
    /// a JOIN/expression result has no single editable target table.
    public func runSQL(_ sql: String) async {
        guard let driver else { return }
        let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let token = beginOperation()
        do {
            let r = try await driver.query(trimmed, database: selectedDatabase)
            guard token == generation else { return }
            result = r
            resultError = nil
            resultSource = .query
            hasMorePages = false
        } catch {
            guard token == generation else { return }
            result = nil
            resultError = Self.asDatabaseError(error).message
            resultSource = .none
        }
        if token == generation { isBusy = false }
    }

    // MARK: - Helpers

    private func beginOperation() -> Int {
        generation += 1
        isBusy = true
        return generation
    }

    private static func asDatabaseError(_ error: Error) -> DatabaseError {
        (error as? DatabaseError) ?? .connection(error.localizedDescription)
    }
}
