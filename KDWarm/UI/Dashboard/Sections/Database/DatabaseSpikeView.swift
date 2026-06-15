import SwiftUI
import KDWarmKit

#if DEBUG
/// DEBUG harness that drives the database editor's first vertical slice end to end: connect to the
/// managed MySQL over the shared event-loop group, run a statement off the main thread, and render
/// the result in the AppKit grid. It de-risks the driver + grid before the real Database section
/// exists; that section reuses `MySQLProbe`/`ResultsGridView` and drops this driver harness.
struct DatabaseSpikeView: View {
    @State private var sql = "SHOW DATABASES"
    @State private var result = QueryResultSet(columns: [], rows: [])
    @State private var status = "Idle"
    @State private var isRunning = false

    private let catalog = ServiceBinaryCatalog(paths: AppSupportPaths())

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            content
        }
        .navigationTitle("Database (spike)")
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space2) {
            HStack(spacing: KDSpacing.space2) {
                TextField("SQL", text: $sql, axis: .vertical)
                    .font(KDFont.mono)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .onSubmit { run(sql) }
                Button("Run") { run(sql) }
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(isRunning || sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("500 rows") {
                    run("SELECT * FROM information_schema.COLUMNS LIMIT 500")
                }
                .disabled(isRunning)
            }
            HStack(spacing: KDSpacing.space2) {
                if isRunning { ProgressView().controlSize(.small) }
                Text(status).font(KDFont.footnote).foregroundStyle(.secondary)
                Spacer()
                if !catalog.isInstalled(.mysql) {
                    Label("MySQL engine not installed", systemImage: "exclamationmark.triangle")
                        .font(KDFont.footnote).foregroundStyle(.orange)
                }
            }
        }
        .padding(KDSpacing.space3)
    }

    @ViewBuilder
    private var content: some View {
        if result.columns.isEmpty {
            VStack(spacing: KDSpacing.space2) {
                Spacer()
                Text("Run a query to see results.")
                    .font(KDFont.body).foregroundStyle(.secondary)
                Text("Start MySQL in Services first if the connection fails.")
                    .font(KDFont.footnote).foregroundStyle(.tertiary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ResultsGridView(result: result)
        }
    }

    private func run(_ statement: String) {
        guard !isRunning else { return }   // onSubmit isn't gated by the button's .disabled
        Task { @MainActor in
            isRunning = true
            status = "Running…"
            do {
                let set = try await MySQLProbe.run(sql: statement)
                result = set
                status = "\(set.rowCount) rows · \(set.columns.count) columns"
            } catch {
                // Reflected description: NIO/MySQL errors often have an unhelpful localizedDescription.
                status = "Error: \(String(reflecting: error))"
            }
            isRunning = false
        }
    }
}
#endif
