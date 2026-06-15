import Foundation
import MySQLNIO
import NIOCore

/// One text-protocol query whose column headers survive a zero-row result. MySQLNIO's public
/// `simpleQuery`/`query` both attach column definitions to each `MySQLRow`, so an empty result
/// (`WHERE 1=0`, empty table, filtered join) drops every header — the grid then can't tell
/// "no matching rows" from "nothing ran". The wire protocol always sends the column-definition
/// packets *before* any row, so this command keeps them in `columns` regardless of row count.
///
/// Mirrors MySQLNIO's own `MySQLSimpleQueryCommand` state machine (the only correct way to drive
/// `COM_QUERY` over the text protocol); the single deviation is retaining `columns` for the caller.
final class MySQLTextQueryCommand: MySQLCommand, @unchecked Sendable {
    private enum State {
        case ready
        case columns(remaining: UInt64)
        case rows
        case done
    }

    let sql: String
    private var state: State = .ready
    private(set) var columns: [MySQLProtocol.ColumnDefinition41] = []
    private(set) var rows: [MySQLRow] = []

    init(sql: String) { self.sql = sql }

    func activate(capabilities: MySQLProtocol.CapabilityFlags) throws -> MySQLCommandState {
        let query = try MySQLPacket.encode(MySQLProtocol.COM_QUERY(query: sql), capabilities: capabilities)
        return MySQLCommandState(response: [query])
    }

    func handle(packet: inout MySQLPacket,
                capabilities: MySQLProtocol.CapabilityFlags) throws -> MySQLCommandState {
        guard !packet.isError else {
            state = .done
            let err = try packet.decode(MySQLProtocol.ERR_Packet.self, capabilities: capabilities)
            switch err.errorCode {
            case .DUP_ENTRY:   throw MySQLError.duplicateEntry(err.errorMessage)
            case .PARSE_ERROR: throw MySQLError.invalidSyntax(err.errorMessage)
            default:           throw MySQLError.server(err)
            }
        }

        switch state {
        case .ready:
            // A bare OK with no result set (INSERT/UPDATE/DDL) — no columns, no rows.
            if packet.isOK {
                state = .done
                return MySQLCommandState(done: true)
            }
            let response = try packet.decode(MySQLProtocol.COM_QUERY_Response.self, capabilities: capabilities)
            state = .columns(remaining: response.columnCount)
            return MySQLCommandState()

        case .columns(let remaining):
            let column = try packet.decode(MySQLProtocol.ColumnDefinition41.self, capabilities: capabilities)
            columns.append(column)
            // Columns are now captured independently of how many rows follow (possibly zero).
            state = columns.count == numericCast(remaining) ? .rows : .columns(remaining: remaining)
            return MySQLCommandState()

        case .rows:
            // With CLIENT_DEPRECATE_EOF negotiated the terminator is an OK packet; older servers
            // send EOF. Either ends the result set.
            guard !packet.isEOF, !packet.isOK else {
                state = .done
                return MySQLCommandState(done: true)
            }
            let data = try MySQLProtocol.TextResultSetRow.decode(from: &packet, columnCount: columns.count)
            rows.append(MySQLRow(format: .text, columnDefinitions: columns, values: data.values))
            return MySQLCommandState()

        case .done:
            throw MySQLError.protocolError
        }
    }
}
