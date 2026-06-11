import SwiftUI

struct MailSectionView: View {
    var body: some View {
        EmptyStateView(
            symbol: "envelope",
            title: "Mailpit is off",
            message: "Start Mailpit to catch outgoing mail from your sites and read it in an embedded viewer.",
            actionTitle: "Start Mailpit"
        ) {}
        .navigationTitle("Mail")
    }
}
