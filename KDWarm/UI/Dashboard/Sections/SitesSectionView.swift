import SwiftUI
import KDWarmKit

/// Sites dashboard: the list of registered sites + Add/Remove and the temporary `/etc/hosts`
/// note (automatic DNS arrives in Phase 4). Observes both the server (status) and the registry
/// (the site list) so it re-renders on either change.
struct SitesSectionView: View {
    @EnvironmentObject private var server: LocalServerController

    var body: some View {
        SitesContent(server: server, registry: server.registry)
    }
}

private struct SitesContent: View {
    @ObservedObject var server: LocalServerController
    @ObservedObject var registry: SiteRegistry
    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if registry.sites.isEmpty {
                EmptyStateView(
                    symbol: "globe",
                    title: "No sites yet",
                    message: "Add a folder under ~/Sites/WWW to serve it at <name>.test.",
                    actionTitle: "Add Site…"
                ) { showAddSheet = true }
            } else {
                list
            }
            if let error = server.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(KDFont.footnote)
                    .foregroundStyle(Color.KDStatus.warning)
                    .padding(KDSpacing.space2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            hostsHint
        }
        .navigationTitle("Sites")
        .sheet(isPresented: $showAddSheet) {
            AddSiteSheet(registry: registry, availableVersions: server.availableVersions)
        }
    }

    private var toolbar: some View {
        HStack(spacing: KDSpacing.space2) {
            Button(server.isRunning ? "Stop Server" : "Start Server") { server.toggle() }
                .disabled(server.isBusy)
            StatusPill(server.nginxStatus, text: server.isRunning ? "nginx" : "offline")
            Spacer()
            Button { showAddSheet = true } label: { Label("Add Site", systemImage: "plus") }
        }
        .padding(KDSpacing.space2)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(registry.sites) { site in
                    SiteRowView(
                        site: site,
                        availableVersions: server.availableVersions,
                        canOpen: server.isRunning,
                        onOpen: { open(site) },
                        onRemove: { registry.remove(site) },
                        onEditDomain: { try registry.editDomain(site, to: $0) },
                        onSetVersion: { registry.setPHPVersion(site, to: $0) })
                    Divider()
                }
            }
        }
    }

    private var hostsHint: some View {
        Text("Until Phase 4 automates DNS, each site needs a line in /etc/hosts: `127.0.0.1 <domain>`.")
            .font(KDFont.footnote)
            .foregroundStyle(.secondary)
            .padding(KDSpacing.space2)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func open(_ site: Site) {
        guard let url = URL(string: "http://\(site.domain)/") else { return }
        NSWorkspace.shared.open(url)
    }
}
