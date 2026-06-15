import SwiftUI
import AppKit
import KDWarmKit

/// Renders a `QueryResultSet` in an AppKit `NSTableView` — SwiftUI's `Table` can't take columns that
/// are only known at runtime. Columns are rebuilt when the result's column list changes; rows reload
/// on every new result. View-based cells reuse a single identifier so a few hundred rows scroll
/// smoothly, and SQL NULLs render distinctly from empty strings.
struct ResultsGridView: NSViewRepresentable {
    let result: QueryResultSet

    func makeCoordinator() -> Coordinator { Coordinator(result: result) }

    func makeNSView(context: Context) -> NSScrollView {
        let table = NSTableView()
        table.usesAlternatingRowBackgroundColors = true
        table.allowsColumnResizing = true
        table.rowHeight = 20
        table.dataSource = context.coordinator
        table.delegate = context.coordinator
        context.coordinator.table = table
        context.coordinator.rebuildColumns(for: result)

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.apply(result)
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        private(set) var result: QueryResultSet
        weak var table: NSTableView?

        init(result: QueryResultSet) { self.result = result }

        /// Reload for a new result, rebuilding columns only when the column set actually changed
        /// (re-running the same query keeps the existing columns, so just the rows refresh).
        func apply(_ newResult: QueryResultSet) {
            let columnsChanged = newResult.columns != result.columns
            result = newResult
            if columnsChanged { rebuildColumns(for: newResult) }
            table?.reloadData()
        }

        func rebuildColumns(for result: QueryResultSet) {
            guard let table else { return }
            for column in table.tableColumns { table.removeTableColumn(column) }
            for (index, name) in result.columns.enumerated() {
                let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col-\(index)"))
                column.title = name
                column.minWidth = 60
                column.width = 140
                table.addTableColumn(column)
            }
        }

        func numberOfRows(in tableView: NSTableView) -> Int { result.rows.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?,
                       row: Int) -> NSView? {
            guard let tableColumn,
                  let columnIndex = tableView.tableColumns.firstIndex(of: tableColumn),
                  row < result.rows.count,
                  columnIndex < result.rows[row].count else { return nil }

            let identifier = NSUserInterfaceItemIdentifier("cell")
            let field = (tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField)
                ?? Self.makeCell(identifier: identifier)

            if let value = result.rows[row][columnIndex] {
                field.stringValue = value
                field.textColor = .labelColor
            } else {
                field.stringValue = "NULL"
                field.textColor = .tertiaryLabelColor
            }
            return field
        }

        private static func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTextField {
            let field = NSTextField(labelWithString: "")
            field.identifier = identifier
            field.lineBreakMode = .byTruncatingTail
            field.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            return field
        }
    }
}
