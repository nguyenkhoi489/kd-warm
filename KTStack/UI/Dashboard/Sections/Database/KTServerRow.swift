import SwiftUI
import KTStackKit

enum KTDatabaseVisuals {
    static func engineLabel(_ kind: DatabaseKind) -> String {
        switch kind {
        case .mysql: return "MySQL"
        case .postgres: return "PostgreSQL"
        case .sqlite: return "SQLite"
        case .mongodb: return "MongoDB"
        }
    }
}

struct KTServerRow: View {
    let profile: ConnectionProfile
    let status: ServerStatus
    let onOpen: () -> Void
    let onBackup: () -> Void
    let onRestore: () -> Void

    @State private var hovering = false

    private var isOnline: Bool { status == .online }

    var body: some View {
        HStack(spacing: 14) {
            KTIconTile(tint: KTEngineTint.of(profile.kind.rawValue), size: 40, radius: 11) {
                Image(systemName: profile.kind == .mongodb ? "leaf.fill" : "cylinder.split.1x2")
                    .font(.system(size: 18, weight: .medium))
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 9) {
                    Text(profile.name).font(.jbMono(14.5, .regular)).foregroundStyle(KTColor.ink)
                    KTBadge(text: KTDatabaseVisuals.engineLabel(profile.kind),
                            tint: KTEngineTint.of(profile.kind.rawValue), radius: 6)
                    if profile.isManaged {
                        Text("bundled").font(KTType.sub).foregroundStyle(KTColor.faint)
                    }
                }
                statusLine
            }
            Spacer(minLength: 8)
            KTButton(title: "Open", kind: .primary, action: onOpen).disabled(!isOnline)
            ghostIcon("tray.and.arrow.down", help: "Backup now", action: onBackup)
                .disabled(!isOnline)
                .opacity(isOnline ? 1 : 0.5)
            Menu {
                Button("Open in Editor", systemImage: "tablecells", action: onOpen).disabled(!isOnline)
                Button("Backup Now", systemImage: "tray.and.arrow.down", action: onBackup).disabled(!isOnline)
                Button("Restore from Backups…", systemImage: "clock.arrow.circlepath", action: onRestore)
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 15, weight: .regular))
                    .foregroundStyle(KTColor.muted).frame(width: 32, height: 30).contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 32)
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 18)
        .background(hovering ? KTColor.rowHover : Color.clear)
        .onHover { hovering = $0 }
    }

    private var statusLine: some View {
        HStack(spacing: 7) {
            KTDot(color: dotColor, size: 6)
            Text(statusText).font(KTType.sub).foregroundStyle(KTColor.muted)
        }
    }

    private var dotColor: Color {
        switch status {
        case .online:     return KTColor.runDot
        case .connecting: return Color(hex: 0xFF9F0A)
        case .offline:    return KTColor.stopDot
        }
    }

    private var statusText: String {
        switch status {
        case .online:     return "Online · \(endpoint)"
        case .connecting: return "Connecting… · \(endpoint)"
        case .offline:    return profile.isManaged ? "Offline · engine not running" : "Offline"
        }
    }

    private var endpoint: String {
        if profile.kind == .sqlite {
            return (profile.filePath as NSString?)?.lastPathComponent ?? "file"
        }
        return "\(profile.host):\(profile.port)"
    }

    private func ghostIcon(_ symbol: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 14, weight: .medium)).foregroundStyle(KTColor.ink3)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(KTColor.btnBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}
