import SwiftUI
import KDWarmKit

/// Sheet for inserting or editing one row (chosen over fiddly inline NSTableView editing for v1).
/// One field per column from the browsed table; nullable columns get a NULL toggle so a SQL NULL is
/// distinct from an empty string. In edit mode the primary-key columns are shown read-only — they
/// form the WHERE key and aren't part of the SET. Values bind as text; the server coerces them into
/// each column's declared type.
struct RowEditorView: View {
    @EnvironmentObject private var vm: DatabaseViewModel
    @Environment(\.dismiss) private var dismiss
    let mode: TableDataView.EditorMode

    @State private var fields: [String: Field] = [:]

    private struct Field { var text: String; var isNull: Bool }

    private var isInsert: Bool { if case .insert = mode { return true } else { return false } }
    private var title: String { isInsert ? "Add Row" : "Edit Row" }

    var body: some View {
        VStack(spacing: 0) {
            Text(title).font(KDFont.title).padding(KDSpacing.space3)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: KDSpacing.space2) {
                    ForEach(vm.currentColumns) { column in fieldRow(column) }
                }
                .padding(KDSpacing.space3)
            }
            Divider()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { save() }.keyboardShortcut(.defaultAction).disabled(vm.isBusy)
            }
            .padding(KDSpacing.space3)
        }
        .frame(width: 420, height: 460)
        .onAppear(perform: loadFields)
    }

    @ViewBuilder
    private func fieldRow(_ column: ColumnInfo) -> some View {
        let readOnly = !isInsert && column.isPrimaryKey
        let binding = fieldBinding(column.name)
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: KDSpacing.space2) {
                Text(column.name).font(KDFont.body)
                if column.isPrimaryKey {
                    Text("PK").font(KDFont.footnote).foregroundStyle(.tertiary)
                }
                Spacer()
                Text(column.dataType).font(KDFont.footnote).foregroundStyle(.tertiary)
            }
            HStack(spacing: KDSpacing.space2) {
                TextField("", text: binding.text)
                    .textFieldStyle(.roundedBorder).font(KDFont.mono)
                    .disabled(readOnly || binding.wrappedValue.isNull)
                if column.isNullable && !readOnly {
                    Toggle("NULL", isOn: binding.isNull).toggleStyle(.checkbox)
                        .font(KDFont.footnote)
                }
            }
        }
    }

    // MARK: - State

    private func loadFields() {
        var initial: [String: Field] = [:]
        let row = currentRowCells
        for (index, column) in vm.currentColumns.enumerated() {
            let cell = row?[safe: index]
            initial[column.name] = Field(text: cell?.displayText ?? "",
                                         isNull: cell.map { $0 == .null } ?? false)
        }
        fields = initial
    }

    /// The cells of the row being edited (positional), or nil for insert.
    private var currentRowCells: [Cell]? {
        guard case .edit(let rowIndex) = mode,
              let result = vm.result, rowIndex < result.rows.count else { return nil }
        return result.rows[rowIndex]
    }

    private func fieldBinding(_ name: String) -> Binding<Field> {
        Binding(
            get: { fields[name] ?? Field(text: "", isNull: false) },
            set: { fields[name] = $0 })
    }

    private func save() {
        let values = buildValues()
        Task {
            switch mode {
            case .insert:        await vm.insertRow(values)
            case .edit(let row): await vm.updateRow(at: row, values: values)
            }
            dismiss()   // errors surface via the section's edit-error alert after the sheet closes
        }
    }

    /// Translate the editor fields into column values. In edit mode the PK columns are excluded (they
    /// key the row, not the SET). On insert, a blank, non-NULL field for a column with a default /
    /// auto-increment is omitted so the server supplies the value.
    private func buildValues() -> [ColumnValue] {
        var out: [ColumnValue] = []
        for column in vm.currentColumns {
            if !isInsert && column.isPrimaryKey { continue }
            let field = fields[column.name] ?? Field(text: "", isNull: false)
            if field.isNull {
                out.append(ColumnValue(column: column.name, value: .null))
            } else if isInsert && field.text.isEmpty && (column.defaultValue != nil || column.isNullable) {
                continue
            } else {
                out.append(ColumnValue(column: column.name, value: .text(field.text)))
            }
        }
        return out
    }
}

private extension Array {
    /// Bounds-checked subscript so a positional row/column mismatch yields nil instead of trapping.
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
