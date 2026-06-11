import SwiftUI

/// Service / site lifecycle state. Each state carries its own color + SF Symbol so
/// callers never rely on color alone (design-guidelines §3.2, §9 — WCAG 1.4.1).
public enum ServiceStatus: String, CaseIterable, Sendable {
    case running, stopped, starting, warning, error, info

    public var color: Color {
        switch self {
        case .running:  return .KDStatus.running
        case .stopped:  return .KDStatus.stopped
        case .starting: return .KDStatus.starting
        case .warning:  return .KDStatus.warning
        case .error:    return .KDStatus.error
        case .info:     return .KDStatus.info
        }
    }

    public var symbolName: String {
        switch self {
        case .running:  return "circle.fill"
        case .stopped:  return "circle"
        case .starting: return "circle.dotted"
        case .warning:  return "exclamationmark.triangle.fill"
        case .error:    return "xmark.octagon.fill"
        case .info:     return "info.circle"
        }
    }

    public var label: String {
        switch self {
        case .running:  return "Running"
        case .stopped:  return "Stopped"
        case .starting: return "Starting"
        case .warning:  return "Warning"
        case .error:    return "Error"
        case .info:     return "Info"
        }
    }
}

/// A managed long-running service (Nginx, PHP-FPM, a DB, Mailpit, dnsmasq…).
/// Phase 1 ships static samples; real supervision arrives in Phase 6.
public struct Service: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var symbolName: String
    public var detail: String       // port or version, e.g. ":443" / "8.3"
    public var status: ServiceStatus
    public var isOn: Bool

    public init(id: UUID = UUID(),
                name: String,
                symbolName: String,
                detail: String,
                status: ServiceStatus,
                isOn: Bool) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.detail = detail
        self.status = status
        self.isOn = isOn
    }

    /// Deterministic placeholder rows for the menu-bar skeleton.
    public static let sample: [Service] = [
        Service(name: "Nginx",   symbolName: "arrow.triangle.branch", detail: ":443",   status: .running, isOn: true),
        Service(name: "PHP-FPM", symbolName: "chevron.left.forwardslash.chevron.right", detail: "8.3", status: .running, isOn: true),
        Service(name: "MySQL",   symbolName: "cylinder.split.1x2", detail: ":3306", status: .running, isOn: true),
        Service(name: "Redis",   symbolName: "bolt.fill",          detail: ":6379", status: .warning, isOn: true),
        Service(name: "Mailpit", symbolName: "envelope",           detail: "off",   status: .stopped, isOn: false),
        Service(name: "dnsmasq", symbolName: "point.3.connected.trianglepath.dotted", detail: "*.test", status: .running, isOn: true),
    ]
}

/// A manually-registered site served at `<domain>` (default `<dirname>.test`).
/// Stub model — registration + vhost generation land in Phase 3.
public struct Site: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var domain: String
    public var path: String

    public init(id: UUID = UUID(), name: String, domain: String, path: String) {
        self.id = id
        self.name = name
        self.domain = domain
        self.path = path
    }

    public static let sample: [Site] = []
}
