import Foundation
import MySQLNIO
import NIOCore

/// Row-level writes for `MySQLDriver`. Each composes a parameterized statement via `SQLDialect`,
/// binds values (never interpolated), and runs inside a transaction that commits only when exactly
/// one row changed — a corrupt/non-unique key or a stale row rolls back instead of silently mutating
/// many rows. Kept apart from the read path so each file stays focused.
extension MySQLDriver {

    public func insert(database: String, table: String, values: [ColumnValue]) async throws {
        let statement = try dialect.insert(schema: database, table: table, values: values)
        try await executeWrite(statement, database: database)
    }

    public func update(database: String, table: String,
                       values: [ColumnValue], key: [ColumnValue]) async throws {
        let statement = try dialect.update(schema: database, table: table, values: values, key: key)
        try await executeWrite(statement, database: database)
    }

    public func delete(database: String, table: String, key: [ColumnValue]) async throws {
        let statement = try dialect.delete(schema: database, table: table, key: key)
        try await executeWrite(statement, database: database)
    }

    /// Run a single-row write transactionally, committing only on `affectedRows == 1`. A statement
    /// that would touch a different number of rows is rolled back and surfaced — the integrity backstop
    /// behind the dialect's keyless-write refusal. The connection is closed on every path.
    private func executeWrite(_ statement: DMLStatement, database: String) async throws {
        try preflightManagedEngine()
        let connection = try await connect(database: database)
        do {
            _ = try await connection.simpleQuery("START TRANSACTION").get()
            let affected = AffectedRowsBox()
            let binds = statement.binds.map(MySQLCellMapper.mysqlData(for:))
            _ = try await connection.query(statement.sql, binds,
                                           onMetadata: { affected.value = $0.affectedRows }).get()
            guard affected.value == 1 else {
                _ = try? await connection.simpleQuery("ROLLBACK").get()
                try? await connection.close().get()
                throw DatabaseError.connection(
                    "Affected \(affected.value) rows; rolled back (expected exactly 1).")
            }
            _ = try await connection.simpleQuery("COMMIT").get()
            try await connection.close().get()
        } catch let error as DatabaseError {
            throw error                                  // already mapped + connection handled above
        } catch {
            _ = try? await connection.simpleQuery("ROLLBACK").get()
            try? await connection.close().get()
            throw MySQLErrorMapper.map(error, isManaged: profile.isManaged)
        }
    }
}

/// A reference box so the `onMetadata` callback (invoked on the event loop) can hand the affected-row
/// count back to the awaiting caller; the future's completion establishes the happens-before, so the
/// read after `.get()` sees the written value.
private final class AffectedRowsBox: @unchecked Sendable {
    var value: UInt64 = 0
}
