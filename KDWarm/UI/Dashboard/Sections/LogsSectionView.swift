import SwiftUI

struct LogsSectionView: View {
    var body: some View {
        EmptyStateView(
            symbol: "text.alignleft",
            title: "No logs to show",
            message: "Per-service and per-site log tails will stream here once services are running.",
            actionTitle: nil
        )
        .navigationTitle("Logs")
    }
}
