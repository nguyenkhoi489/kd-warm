import SwiftUI
import KDWarmKit

/// The Database dashboard section: a three-pane browser (connections | schema | data/query) over
/// `DatabaseViewModel`. Read-focused for M1 — browse paginated rows and run arbitrary SQL; row
/// editing arrives in the row-CRUD phase. When a connection fails because the managed engine is
/// absent or stopped, the right pane routes to the install/start flow instead of a dead-end error.
struct DatabaseSectionView: View {
    @EnvironmentObject private var vm: DatabaseViewModel
    @EnvironmentObject private var services: ServiceManager
    @State private var rightTab: RightTab = .data

    enum RightTab: String, CaseIterable, Identifiable {
        case data = "Data"
        case query = "Query"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            HSplitView {
                ConnectionSidebarView()
                SchemaTreeView()
                rightPane.frame(minWidth: 360)
            }
        }
        .navigationTitle("Database")
    }

    private var toolbar: some View {
        HStack(spacing: KDSpacing.space3) {
            Text(vm.selectedProfile?.name ?? "No connection").font(KDFont.headline)
            connectionStatus
            Spacer()
            Picker("", selection: $rightTab) {
                ForEach(RightTab.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().frame(width: 160)
            .disabled(vm.connection != .connected)
        }
        .padding(KDSpacing.space3)
    }

    @ViewBuilder
    private var connectionStatus: some View {
        switch vm.connection {
        case .connecting:
            HStack(spacing: KDSpacing.space1) {
                ProgressView().controlSize(.small)
                Text("Connecting…").font(KDFont.footnote).foregroundStyle(.secondary)
            }
        case .connected:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .font(KDFont.footnote).foregroundStyle(.green)
        case .failed:
            Label("Disconnected", systemImage: "exclamationmark.triangle.fill")
                .font(KDFont.footnote).foregroundStyle(.orange)
        case .idle:
            EmptyView()
        }
    }

    @ViewBuilder
    private var rightPane: some View {
        switch vm.connection {
        case .connected:
            switch rightTab {
            case .data:  TableDataView()
            case .query: QueryEditorView()
            }
        case .connecting:
            ProgressView("Connecting…").frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let error):
            failureGate(error)
        case .idle:
            EmptyStateView(symbol: "cylinder.split.1x2",
                           title: "Database",
                           message: "Pick a connection on the left to browse tables and run SQL.")
        }
    }

    /// Route engine-not-installed/not-running to the existing service install/start flow rather than
    /// surfacing a bare "connection refused". Other failures (auth, TLS) offer a plain retry.
    @ViewBuilder
    private func failureGate(_ error: DatabaseError) -> some View {
        switch error {
        case .engineNotInstalled:
            EmptyStateView(symbol: "shippingbox",
                           title: "MySQL isn’t installed",
                           message: "Install the managed MySQL engine, then reconnect.",
                           actionTitle: "Install MySQL…",
                           action: { services.install(.mysql) })
        case .engineNotRunning:
            EmptyStateView(symbol: "play.circle",
                           title: "MySQL isn’t running",
                           message: "Start the MySQL engine, then reconnect.",
                           actionTitle: "Start MySQL",
                           action: { services.toggle(.mysql) })
        default:
            EmptyStateView(symbol: "exclamationmark.triangle",
                           title: "Connection failed",
                           message: error.message,
                           actionTitle: "Retry",
                           action: retry)
        }
    }

    private func retry() {
        guard let profile = vm.selectedProfile else { return }
        Task { await vm.select(profile: profile) }
    }
}
