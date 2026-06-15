import SwiftUI
import KDWarmKit

/// Right-pane "Data" tab: the paginated row browser for the selected table. Renders the grid only
/// for a table-browse result (`resultSource == .table`) so a SQL-runner result never leaks in under
/// pagination controls that don't apply to it.
struct TableDataView: View {
    @EnvironmentObject private var vm: DatabaseViewModel

    var body: some View {
        VStack(spacing: 0) {
            pager
            Divider()
            grid
        }
    }

    @ViewBuilder
    private var grid: some View {
        if let result = vm.result, vm.isResultEditable {
            ResultsGridView(result: result)
        } else if vm.selectedTable == nil {
            EmptyStateView(symbol: "tablecells",
                           title: "No table selected",
                           message: "Pick a table in the schema tree to browse its rows.")
        } else if let error = vm.resultError {
            EmptyStateView(symbol: "exclamationmark.triangle",
                           title: "Couldn’t load rows", message: error)
        } else {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var pager: some View {
        HStack(spacing: KDSpacing.space2) {
            if let table = vm.selectedTable {
                Label(table.name, systemImage: table.isView ? "eye" : "tablecells")
                    .font(KDFont.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            if let result = vm.result, vm.isResultEditable, result.rowCount > 0 {
                Text("rows \(vm.pageOffset + 1)–\(vm.pageOffset + result.rowCount)")
                    .font(KDFont.footnote).foregroundStyle(.secondary)
            }
            Button { Task { await vm.previousPage() } } label: { Image(systemName: "chevron.left") }
                .disabled(vm.pageOffset == 0 || vm.isBusy || vm.selectedTable == nil)
            Button { Task { await vm.nextPage() } } label: { Image(systemName: "chevron.right") }
                .disabled(!vm.hasMorePages || vm.isBusy)
        }
        .padding(KDSpacing.space2)
    }
}
