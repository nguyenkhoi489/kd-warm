import Foundation
import ServiceManagement

enum LoginItemService {
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) { return SMAppService.mainApp.status == .enabled }
        return false
    }

    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            return true
        } catch {
            NSLog("KTStack: login item update failed: \(error.localizedDescription)")
            return false
        }
    }
}
