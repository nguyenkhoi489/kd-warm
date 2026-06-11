import SwiftUI

struct ServicesSectionView: View {
    var body: some View {
        EmptyStateView(
            symbol: "server.rack",
            title: "No services running",
            message: "Nginx, PHP-FPM, databases, and Mailpit will appear here once they are installed and started.",
            actionTitle: "Start Core Services"
        ) {}
        .navigationTitle("Services")
    }
}
