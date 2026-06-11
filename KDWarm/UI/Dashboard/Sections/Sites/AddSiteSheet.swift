import SwiftUI
import AppKit
import KDWarmKit

/// "Add Site" sheet: choose a folder (defaults to ~/Sites/WWW), confirm the editable domain
/// (default `<dirname>.test`, TLD-validated) and PHP version, then register it.
struct AddSiteSheet: View {
    @ObservedObject var registry: SiteRegistry
    let availableVersions: [String]
    @Environment(\.dismiss) private var dismiss

    @State private var folder: URL?
    @State private var domain = ""
    @State private var phpVersion = BundledPHP.defaultVersion
    @State private var error: String?

    var body: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space3) {
            Text("Add Site").font(KDFont.title)

            HStack {
                Text(folder?.path ?? "No folder selected")
                    .font(KDFont.mono).foregroundStyle(folder == nil ? .secondary : .primary)
                    .lineLimit(1).truncationMode(.middle)
                Spacer()
                Button("Choose Folder…", action: chooseFolder)
            }

            if folder != nil {
                Grid(alignment: .leading, verticalSpacing: KDSpacing.space2) {
                    GridRow {
                        Text("Domain").foregroundStyle(.secondary)
                        TextField("name.test", text: $domain).font(KDFont.mono).frame(width: 240)
                    }
                    GridRow {
                        Text("PHP").foregroundStyle(.secondary)
                        Picker("", selection: $phpVersion) {
                            ForEach(availableVersions, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden().fixedSize()
                    }
                }
            }

            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(KDFont.footnote).foregroundStyle(Color.KDStatus.error)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Add Site", action: addSite)
                    .keyboardShortcut(.defaultAction)
                    .disabled(folder == nil || domain.isEmpty)
            }
        }
        .padding(KDSpacing.space4)
        .frame(width: 460)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = AppSupportPaths.defaultSitesRoot
        panel.prompt = "Choose"
        if panel.runModal() == .OK, let url = panel.url {
            folder = url
            domain = "\(SiteInspector.slug(url.lastPathComponent)).\(registry.tld)"
            error = nil
        }
    }

    private func addSite() {
        guard let folder else { return }
        let wanted = domain.trimmingCharacters(in: .whitespaces).lowercased()
        do {
            try registry.validateDomain(wanted)           // fail fast before registering
            let site = try registry.add(folder: folder, phpVersion: phpVersion)
            if site.domain != wanted { try registry.editDomain(site, to: wanted) }
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
