import Foundation

/// Per-engine SQL composition. A strategy from the start (not MySQL-only) so PostgreSQL/SQLite add a
/// quote char rather than reshaping the type. Identifiers (table/column names) can't be bound
/// parameters, so `quoteIdent` is the sole defense against identifier injection — it doubles the
/// engine's quote char and rejects characters that doubling can't neutralize.
public struct SQLDialect: Sendable {
    /// The character the engine wraps identifiers in: backtick for MySQL, double-quote for the
    /// SQL-standard engines (PostgreSQL/SQLite).
    public let quote: Character

    public static func forKind(_ kind: DatabaseKind) -> SQLDialect {
        switch kind {
        case .mysql:                       return SQLDialect(quote: "`")
        case .postgres, .sqlite, .mongodb: return SQLDialect(quote: "\"")
        }
    }

    /// Quote an identifier safely. Doubles every embedded quote char so it can't terminate the quoted
    /// identifier, and rejects NUL/newline/empty: NUL can truncate at the C-string boundary inside the
    /// server and a newline has no escape inside a quoted identifier, so neither is ever a legitimate
    /// name — fail closed rather than emit a string that doubling can't make safe.
    public func quoteIdent(_ identifier: String) throws -> String {
        guard !identifier.isEmpty else {
            throw DatabaseError.connection("Empty SQL identifier")
        }
        guard !identifier.contains("\u{0}"), !identifier.contains(where: \.isNewline) else {
            throw DatabaseError.connection("Illegal character in SQL identifier")
        }
        let escaped = identifier.replacingOccurrences(of: String(quote), with: String(repeating: quote, count: 2))
        return "\(quote)\(escaped)\(quote)"
    }

    /// `schema.table`, both parts quoted independently.
    public func qualifiedTable(schema: String, table: String) throws -> String {
        "\(try quoteIdent(schema)).\(try quoteIdent(table))"
    }

    /// Append `LIMIT … OFFSET …` to a SELECT. `limit` is clamped to ≥ 1 (a zero/negative limit is
    /// either malformed or a silently-unbounded scan) and `offset` to ≥ 0. Both are integers, so no
    /// quoting/binding is needed — there's no injection surface.
    public func paginate(_ sql: String, limit: Int, offset: Int) -> String {
        let safeLimit = max(1, limit)
        let safeOffset = max(0, offset)
        return "\(sql) LIMIT \(safeLimit) OFFSET \(safeOffset)"
    }

    // MARK: - DML composition (parameterized)

    /// `INSERT INTO schema.table (cols…) VALUES (?, …)`. Column names are identifier-quoted; values
    /// are never interpolated — they ride as ordered binds the driver parameter-binds, so a value can
    /// never break out into SQL.
    public func insert(schema: String, table: String, values: [ColumnValue]) throws -> DMLStatement {
        guard !values.isEmpty else {
            throw DatabaseError.connection("INSERT needs at least one column")
        }
        let qualified = try qualifiedTable(schema: schema, table: table)
        let columns = try values.map { try quoteIdent($0.column) }.joined(separator: ", ")
        let placeholders = Array(repeating: "?", count: values.count).joined(separator: ", ")
        return DMLStatement(sql: "INSERT INTO \(qualified) (\(columns)) VALUES (\(placeholders))",
                            binds: values.map(\.value))
    }

    /// `UPDATE schema.table SET col = ?, … WHERE key = ? AND …`. The key set ANDs every key column —
    /// a composite primary key is the common case. Binds are SET values first, then key values.
    public func update(schema: String, table: String,
                       values: [ColumnValue], key: [ColumnValue]) throws -> DMLStatement {
        guard !values.isEmpty else {
            throw DatabaseError.connection("UPDATE needs at least one column to set")
        }
        try requireUsableKey(key)
        let qualified = try qualifiedTable(schema: schema, table: table)
        let setClause = try values.map { "\(try quoteIdent($0.column)) = ?" }.joined(separator: ", ")
        let whereClause = try key.map { "\(try quoteIdent($0.column)) = ?" }.joined(separator: " AND ")
        return DMLStatement(sql: "UPDATE \(qualified) SET \(setClause) WHERE \(whereClause)",
                            binds: values.map(\.value) + key.map(\.value))
    }

    /// `DELETE FROM schema.table WHERE key = ? AND …`. Refuses an empty key — a keyless DELETE would
    /// wipe the whole table, which the dialect never emits.
    public func delete(schema: String, table: String, key: [ColumnValue]) throws -> DMLStatement {
        try requireUsableKey(key)
        let qualified = try qualifiedTable(schema: schema, table: table)
        let whereClause = try key.map { "\(try quoteIdent($0.column)) = ?" }.joined(separator: " AND ")
        return DMLStatement(sql: "DELETE FROM \(qualified) WHERE \(whereClause)",
                            binds: key.map(\.value))
    }

    /// A usable row key is non-empty and NULL-free: an empty key would match every row, and `col = ?`
    /// bound to NULL never matches in SQL (NULL comparison is unknown), so a NULL key can't target a row.
    private func requireUsableKey(_ key: [ColumnValue]) throws {
        guard !key.isEmpty else {
            throw DatabaseError.connection("Refusing an UPDATE/DELETE with no key (would affect every row)")
        }
        guard !key.contains(where: { $0.value == .null }) else {
            throw DatabaseError.connection("A NULL key can't identify a single row")
        }
    }
}

/// A parameterized DML statement: SQL carrying `?` placeholders plus the ordered values to bind.
/// Separating binds from SQL is the value-injection defense — identifiers are quoted via `quoteIdent`,
/// values are bound, neither is interpolated.
public struct DMLStatement: Sendable, Equatable {
    public let sql: String
    public let binds: [Cell]

    public init(sql: String, binds: [Cell]) {
        self.sql = sql
        self.binds = binds
    }
}
