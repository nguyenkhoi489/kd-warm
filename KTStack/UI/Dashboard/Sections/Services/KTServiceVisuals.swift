import SwiftUI
import KTStackKit

enum KTServiceVisuals {
    static func tint(_ kind: ServiceKind) -> KTTint {
        switch kind {
        case .nginx, .dnsmasq: return KTIconTint.globe
        case .phpFpm: return KTIconTint.code
        case .mysql, .postgres, .mongodb: return KTIconTint.db
        case .redis: return KTIconTint.cube
        case .mailpit: return KTIconTint.mail
        }
    }

    static func subtitle(_ kind: ServiceKind) -> String {
        switch kind {
        case .nginx:    return "Reverse proxy · ports 80, 443"
        case .phpFpm:   return "FastCGI pools · managed with web server"
        case .dnsmasq:  return "*.test resolver · port 53 · privileged helper"
        case .mysql:    return "Database · port 3306"
        case .postgres: return "Database · port 5432"
        case .redis:    return "Cache · port 6379"
        case .mongodb:  return "Document DB · port 27017"
        case .mailpit:  return "Mail catcher · SMTP 1025 · web 8025"
        }
    }
}
