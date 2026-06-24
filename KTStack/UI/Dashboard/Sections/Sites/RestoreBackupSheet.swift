import SwiftUI
import UniformTypeIdentifiers
import KTStackKit

struct RestoreBackupSheet: View {
    @ObservedObject var registry: SiteRegistry
    @ObservedObject var server: LocalServerController
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = RestoreBackupModel()
    @State private var showPicker = false

    private var allowedTypes: [UTType] {
        [.zip, UTType(filenameExtension: "wpress") ?? .data]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space3) {
            Text("Restore from Backup").font(KDFont.title)

            switch model.stage {
            case .idle, .ready, .failed:
                form
            case .running:
                progress
            case .success:
                successView
            }
        }
        .padding(KDSpacing.space4)
        .frame(width: 560)
        .fileImporter(isPresented: $showPicker, allowedContentTypes: allowedTypes) { result in
            if case .success(let url) = result {
                let scoped = url.startAccessingSecurityScopedResource()
                model.selectFile(url, installed: server.availableVersions)
                if scoped { url.stopAccessingSecurityScopedResource() }
            }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space3) {
            filePicker
            if model.kind != nil {
                nameField
                phpPicker
                Toggle("Serve over HTTPS", isOn: $model.secure)
                trustNotice
            }
            if let error = model.error {
                Label(error, systemImage: "xmark.octagon")
                    .font(KDFont.footnote).foregroundStyle(Color.KDStatus.error)
            }
            controls
        }
    }

    private var filePicker: some View {
        HStack(spacing: KDSpacing.space2) {
            Button("Choose Backup…") { showPicker = true }
            if let kind = model.kind, let file = model.backupFile {
                KTPill(text: kind.label)
                Text(file.lastPathComponent)
                    .font(KDFont.footnote).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            } else {
                Text("Duplicator .zip or All-in-One WP Migration .wpress")
                    .font(KDFont.footnote).foregroundStyle(.secondary)
            }
        }
    }

    private var nameField: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Site name").font(KDFont.footnote).foregroundStyle(.secondary)
            TextField("my-site", text: $model.siteName)
                .textFieldStyle(.roundedBorder)
        }
    }

    private var phpPicker: some View {
        HStack {
            Text("PHP version").font(KDFont.footnote).foregroundStyle(.secondary)
            Picker("", selection: $model.phpVersion) {
                ForEach(server.availableVersions, id: \.self) { version in
                    Text(BundledPHP.isEndOfLife(version) ? "\(version) (EOL)" : version).tag(version)
                }
            }
            .labelsHidden()
            .frame(width: 140)
            if server.availableVersions.isEmpty {
                Text("No PHP installed — install a runtime first.")
                    .font(KDFont.footnote).foregroundStyle(Color.KDStatus.error)
            } else if BundledPHP.isEndOfLife(model.phpVersion) {
                Text("This version is end-of-life.")
                    .font(KDFont.footnote).foregroundStyle(Color.KDStatus.warning)
            }
        }
    }

    private var trustNotice: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space1) {
            Label("A backup can contain executable PHP (installer, plugins, mu-plugins). Restore only backups you trust.",
                  systemImage: "exclamationmark.shield")
                .font(KDFont.footnote).foregroundStyle(Color.KDStatus.warning)
            Toggle("I trust this backup", isOn: $model.trusted)
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space3) {
            HStack(spacing: KDSpacing.space2) {
                ProgressView().controlSize(.small)
                Text(model.phase.map { "\($0.rawValue.capitalized)…" } ?? "Working…").font(KDFont.headline)
            }
            Text(model.message).font(KDFont.footnote).foregroundStyle(.secondary)
                .lineLimit(2).truncationMode(.middle)
            HStack {
                Spacer()
                Button("Cancel") { model.cancel() }.keyboardShortcut(.cancelAction)
            }
        }
    }

    private var successView: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space3) {
            Label("Restored \(model.resultSite?.domain ?? "site")", systemImage: "checkmark.seal")
                .font(KDFont.headline).foregroundStyle(Color.KDStatus.running)
            ForEach(model.warnings, id: \.self) { warning in
                Label(warning, systemImage: "exclamationmark.triangle")
                    .font(KDFont.footnote).foregroundStyle(Color.KDStatus.warning)
            }
            HStack {
                Spacer()
                if let site = model.resultSite {
                    Button("Open Site") { KTSiteActions.openInBrowser(site) }
                }
                Button("Done") { dismiss() }.keyboardShortcut(.defaultAction)
            }
        }
    }

    private var controls: some View {
        HStack {
            Spacer()
            Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            Button("Restore") { model.restore(registry: registry, server: server) }
                .keyboardShortcut(.defaultAction)
                .disabled(!model.canRestore)
        }
    }
}
