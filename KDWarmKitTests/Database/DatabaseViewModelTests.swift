import XCTest
@testable import KDWarmKit

/// Logic coverage for the Database section's view model, driven against a stub `RelationalDriver`
/// (no live engine). Covers the selection chain (connection → database → table), the SQL runner's
/// result/error split, pagination offset advance, and the generation guard that discards a stale
/// in-flight result when the selection is superseded mid-flight.
@MainActor
final class DatabaseViewModelTests: XCTestCase {

    /// Records each call and returns canned results. `databasesDelay` lets a test interleave a slow
    /// connect with a faster one to exercise the stale-result guard.
    private final class StubDriver: RelationalDriver, @unchecked Sendable {
        let kind: DatabaseKind = .mysql
        let tag: String
        var databasesDelay: Duration = .zero
        var queryShouldThrow: DatabaseError?
        private(set) var paginateCalls: [(database: String, table: String, limit: Int, offset: Int)] = []

        init(tag: String) { self.tag = tag }

        func ping() async throws {}

        func listDatabases() async throws -> [DatabaseInfo] {
            if databasesDelay > .zero { try? await Task.sleep(for: databasesDelay) }
            return [DatabaseInfo(name: "db_\(tag)")]
        }

        func listTables(database: String) async throws -> [TableInfo] {
            [TableInfo(name: "users"), TableInfo(name: "orders")]
        }

        func columns(database: String, table: String) async throws -> [ColumnInfo] { [] }

        func query(_ sql: String, database: String?) async throws -> QueryResult {
            if let queryShouldThrow { throw queryShouldThrow }
            return QueryResult(columns: [ColumnMeta(name: "n")], rows: [[.int(1)]])
        }

        func paginatedRows(database: String, table: String,
                           limit: Int, offset: Int) async throws -> QueryResult {
            paginateCalls.append((database, table, limit, offset))
            // Return a full page so the VM reports `hasMorePages`.
            let rows = (0..<limit).map { _ in [Cell.int(Int64(offset))] }
            return QueryResult(columns: [ColumnMeta(name: "id")], rows: rows)
        }
    }

    private func makeVM(_ driver: StubDriver) -> DatabaseViewModel {
        DatabaseViewModel(makeDriver: { _, _ in driver }, passwordFor: { _ in nil })
    }

    func testSelectingConnectionLoadsDatabases() async {
        let vm = makeVM(StubDriver(tag: "a"))
        await vm.select(profile: .managedMySQL)
        XCTAssertEqual(vm.connection, .connected)
        XCTAssertEqual(vm.databases.map(\.name), ["db_a"])
        XCTAssertFalse(vm.isBusy)
    }

    func testSelectingTableLoadsFirstPage() async {
        let vm = makeVM(StubDriver(tag: "a"))
        await vm.select(profile: .managedMySQL)
        await vm.select(database: "db_a")
        XCTAssertEqual(vm.tables.map(\.name), ["users", "orders"])

        await vm.select(table: TableInfo(name: "users"))
        XCTAssertEqual(vm.pageOffset, 0)
        XCTAssertEqual(vm.result?.rowCount, vm.pageSize)
        XCTAssertTrue(vm.isResultEditable)            // single-table browse → editable target
        XCTAssertTrue(vm.hasMorePages)
    }

    func testRunningSQLPopulatesResult() async {
        let vm = makeVM(StubDriver(tag: "a"))
        await vm.select(profile: .managedMySQL)
        await vm.runSQL("SELECT 1")
        XCTAssertEqual(vm.result?.columns.map(\.name), ["n"])
        XCTAssertNil(vm.resultError)
        XCTAssertFalse(vm.isResultEditable)           // arbitrary query → read-only
    }

    func testRunningInvalidSQLSurfacesError() async {
        let driver = StubDriver(tag: "a")
        driver.queryShouldThrow = .syntax("bad SQL")
        let vm = makeVM(driver)
        await vm.select(profile: .managedMySQL)
        await vm.runSQL("SELEKT 1")
        XCTAssertNil(vm.result)
        XCTAssertEqual(vm.resultError, DatabaseError.syntax("bad SQL").message)
    }

    func testPaginationAdvancesOffset() async {
        let driver = StubDriver(tag: "a")
        let vm = makeVM(driver)
        vm.pageSize = 10
        await vm.select(profile: .managedMySQL)
        await vm.select(database: "db_a")
        await vm.select(table: TableInfo(name: "users"))
        await vm.nextPage()
        XCTAssertEqual(vm.pageOffset, 10)
        await vm.previousPage()
        XCTAssertEqual(vm.pageOffset, 0)
        // first page, next page, prev page → three paginated reads at offsets 0, 10, 0.
        XCTAssertEqual(driver.paginateCalls.map(\.offset), [0, 10, 0])
    }

    func testUnsupportedEngineFailsCleanly() async {
        // Factory returns nil for a non-MySQL kind → an explicit connection failure, not a crash.
        let vm = DatabaseViewModel(makeDriver: { _, _ in nil }, passwordFor: { _ in nil })
        let pg = ConnectionProfile(name: "pg", kind: .postgres, host: "h", port: 5432,
                                   user: "u", database: "d")
        await vm.select(profile: pg)
        if case .failed = vm.connection {} else { XCTFail("expected failed connection") }
        XCTAssertFalse(vm.isBusy)
    }

    func testStaleConnectResultIsDiscarded() async {
        // A slow connection started first must not clobber a faster one that supersedes it.
        let slow = StubDriver(tag: "slow"); slow.databasesDelay = .milliseconds(120)
        let fast = StubDriver(tag: "fast")
        var next: StubDriver = slow
        let vm = DatabaseViewModel(makeDriver: { _, _ in next }, passwordFor: { _ in nil })

        async let first: Void = vm.select(profile: .managedMySQL)
        // Let the slow select reach its awaiting listDatabases, then supersede it.
        try? await Task.sleep(for: .milliseconds(20))
        next = fast
        await vm.select(profile: .managedMySQL)
        await first

        XCTAssertEqual(vm.databases.map(\.name), ["db_fast"])   // fast won; slow discarded
        XCTAssertEqual(vm.connection, .connected)
    }
}
