import SwiftUI

struct RuntimesSectionView: View {
    var body: some View {
        EmptyStateView(
            symbol: "cpu",
            title: "No runtimes configured",
            message: "Bundled PHP (7.4 / 8.1 / 8.3 / 8.4) and Node 22 LTS, plus on-demand Python, Go, Ruby, and Java, will be managed here.",
            actionTitle: "Manage Runtimes"
        ) {}
        .navigationTitle("Runtimes")
    }
}
