import Foundation
import MySQLNIO
import NIOCore
import NIOSSL

/// A query result reduced to what a grid needs: ordered column names + rows of optional strings
/// (`nil` == SQL NULL, so the grid can style it distinctly from an empty string). Heterogeneous
/// column types are flattened to their text representation here; the typed `Cell` model arrives
/// with the real relational driver.
public struct QueryResultSet: Sendable, Equatable {
    public let columns: [String]
    public let rows: [[String?]]

    public init(columns: [String], rows: [[String?]]) {
        self.columns = columns
        self.rows = rows
    }

    public var rowCount: Int { rows.count }

    /// Build from column metadata captured independently of the rows, plus the text-protocol rows.
    /// Columns come from the result-set definition (not `rows.first`), so a zero-row result still
    /// carries its headers — the grid can show "no matching rows" under real column titles instead
    /// of collapsing to an empty state. Reads `values` positionally so duplicate column names from a
    /// join still map one-to-one.
    public init(columns: [String], textRows: [MySQLRow]) {
        self.columns = columns
        self.rows = textRows.map { Self.textCells($0.values) }
    }

    /// One text-protocol row's raw value buffers → display strings. A `nil` buffer is SQL NULL and
    /// stays `nil`; everything else is the UTF-8 text MySQL already serialized. Pure (no driver
    /// state) so the NULL/value mapping is unit-testable without a live engine.
    public static func textCells(_ values: [ByteBuffer?]) -> [String?] {
        values.map { buffer in
            guard var buffer else { return nil }
            return buffer.readString(length: buffer.readableBytes)
        }
    }
}

/// Minimal MySQL connect-and-query path used by the database editor's first slice. Opens one
/// short-lived connection over the shared event-loop group, runs a statement off the main thread,
/// and maps the result. The pooled, profile-driven driver layers on top of this in the relational
/// driver phase; the connect + text-row mapping proven here is the kept core.
public enum MySQLProbe {
    /// TLS for the managed loopback engine. The engine auto-generates a self-signed cert, so the
    /// trust anchor is locality ("our own engine on 127.0.0.1") and verification is disabled. TLS is
    /// REQUIRED even on loopback: MySQLNIO cannot authenticate a passwordless `caching_sha2_password`
    /// account over plaintext — it always sends a non-empty scramble, which the empty-password root
    /// account rejects — but the cleartext-over-TLS full-auth path succeeds.
    public static var loopbackTLS: TLSConfiguration {
        var config = TLSConfiguration.makeClientConfiguration()
        config.certificateVerification = .none
        return config
    }

    static func isLoopback(_ host: String) -> Bool {
        host == "127.0.0.1" || host == "::1" || host == "localhost"
    }

    /// TLS chosen by destination, so verification is only ever disabled for our own loopback engine.
    /// A non-loopback host falls back to a fully verifying client config — a future
    /// `run(host: "remote-db")` cannot silently accept an unverified certificate; per-profile TLS is
    /// passed explicitly by the relational driver instead.
    static func defaultTLS(forHost host: String) -> TLSConfiguration {
        isLoopback(host) ? loopbackTLS : .makeClientConfiguration()
    }

    public static func run(
        sql: String,
        host: String = "127.0.0.1",
        port: Int = 3306,
        username: String = "root",
        password: String? = nil,
        database: String = "mysql",
        tlsConfiguration: TLSConfiguration? = nil
    ) async throws -> QueryResultSet {
        let tls = tlsConfiguration ?? defaultTLS(forHost: host)
        let group = try EventLoopProvider.shared.group()
        let address = try SocketAddress.makeAddressResolvingHost(host, port: port)
        let connection = try await MySQLConnection.connect(
            to: address,
            username: username,
            database: database,
            password: password,
            tlsConfiguration: tls,
            on: group.next()
        ).get()

        let command = MySQLTextQueryCommand(sql: sql)
        do {
            try await connection.send(command, logger: connection.logger).get()
        } catch {
            // Query failed: close best-effort and surface the original error.
            try? await connection.close().get()
            throw error
        }
        // Success path closes outside the catch, so a close failure here is reported on its own and
        // never double-closes the connection.
        try await connection.close().get()
        return QueryResultSet(columns: command.columns.map(\.name), textRows: command.rows)
    }
}
