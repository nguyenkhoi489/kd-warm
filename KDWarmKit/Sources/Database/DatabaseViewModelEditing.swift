import Foundation

/// Row mutations for `DatabaseViewModel`, kept apart from the read-path state machine. Each guards
/// editability, runs the write off-main via the driver, and reloads the current page so the grid
/// reflects the change; failures surface in `editError` (an alert) rather than wiping the result.
public extension DatabaseViewModel {

    /// Insert a row from the editor's values. Reloads the current page on success so the new row shows.
    func insertRow(_ values: [ColumnValue]) async {
        await performWrite { driver, database, table in
            try await driver.insert(database: database, table: table, values: values)
        }
    }

    /// Update the row at `rowIndex` (in the current page) to `values`, keyed on its primary key.
    func updateRow(at rowIndex: Int, values: [ColumnValue]) async {
        guard let key = keyForRow(rowIndex) else {
            editError = "Can't identify this row to update (no usable primary key)."
            return
        }
        await performWrite { driver, database, table in
            try await driver.update(database: database, table: table, values: values, key: key)
        }
    }

    /// Delete the row at `rowIndex` (in the current page), keyed on its primary key.
    func deleteRow(at rowIndex: Int) async {
        guard let key = keyForRow(rowIndex) else {
            editError = "Can't identify this row to delete (no usable primary key)."
            return
        }
        await performWrite { driver, database, table in
            try await driver.delete(database: database, table: table, key: key)
        }
    }

    /// Shared write path: guard editability, run the mutation, then reload the page. A failure surfaces
    /// in `editError` rather than clearing the grid.
    private func performWrite(
        _ op: (RelationalDriver, String, String) async throws -> Void) async {
        guard canEditRows, let driver, let database = selectedDatabase, let table = selectedTable
        else { return }
        editError = nil
        isBusy = true
        do {
            try await op(driver, database, table.name)
            await loadPage()
        } catch {
            editError = Self.asDatabaseError(error).message
            isBusy = false
        }
    }

    /// The primary-key column→value pairs for a row in the current page, used to target exactly that
    /// row. Nil if the row index is out of range or a PK column isn't present in the result.
    private func keyForRow(_ rowIndex: Int) -> [ColumnValue]? {
        guard let result, rowIndex >= 0, rowIndex < result.rows.count else { return nil }
        let names = result.columnNames
        var key: [ColumnValue] = []
        for pk in primaryKeyColumns {
            guard let idx = names.firstIndex(of: pk.name) else { return nil }
            key.append(ColumnValue(column: pk.name, value: result.rows[rowIndex][idx]))
        }
        return key.isEmpty ? nil : key
    }
}
