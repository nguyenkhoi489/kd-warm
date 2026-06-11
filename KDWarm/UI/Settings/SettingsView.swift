import SwiftUI
import KDWarmKit

/// Settings scene placeholder (design-guidelines §10): `TabView` of `Form`s. Real
/// preference bindings land alongside the subsystems they configure in later phases.
struct SettingsView: View {
    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }
            servicesTab
                .tabItem { Label("Services", systemImage: "server.rack") }
        }
        .frame(width: 480, height: 320)
    }

    private var generalTab: some View {
        Form {
            LabeledContent("Sites root", value: "~/Sites/WWW")
            LabeledContent("Default TLD", value: ".test")
            Toggle("Launch KDWarm at login", isOn: .constant(false)).disabled(true)
        }
        .formStyle(.grouped)
        .padding(KDSpacing.space4)
    }

    private var servicesTab: some View {
        Form {
            LabeledContent("Reverse proxy", value: "Nginx")
            LabeledContent("Local DNS", value: "dnsmasq · /etc/resolver/test")
            LabeledContent("Local TLS", value: "mkcert (vendored)")
        }
        .formStyle(.grouped)
        .padding(KDSpacing.space4)
    }
}
