import SwiftUI

struct SitesSectionView: View {
    var body: some View {
        EmptyStateView(
            symbol: "globe",
            title: "No sites yet",
            message: "Register a folder under ~/Sites/WWW to serve it at <name>.test with trusted local TLS.",
            actionTitle: "Add Site…"
        ) {}
        .navigationTitle("Sites")
    }
}
