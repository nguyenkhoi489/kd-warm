import SwiftUI
import AppKit

@main
struct KDWarmApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Menu-bar entry. `.window` style gives a real SwiftUI canvas so status pills
        // and toggles render per the design (a plain `.menu` cannot host them).
        MenuBarExtra("KDWarm", image: "MenuBarGlyph") {
            MenuBarContentView()
        }
        .menuBarExtraStyle(.window)

        // Dashboard window, opened on demand from the menu-bar footer.
        Window("KDWarm Dashboard", id: DashboardWindow.windowID) {
            DashboardWindow()
        }
        .defaultSize(width: 920, height: 600)
        .windowResizability(.contentMinSize)

        Settings {
            SettingsView()
        }
    }
}

/// Owns the accessory-app launch posture and restores it as windows close.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Start as a menu-bar-only accessory: no Dock icon, no default window.
        NSApp.setActivationPolicy(.accessory)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil)
    }

    @objc private func windowWillClose(_ note: Notification) {
        // Defer until after the window is gone, then drop back to accessory if no
        // ordinary windows remain — excluding the window that is closing now.
        let closingWindow = note.object as? NSWindow
        DispatchQueue.main.async {
            AppActivationPolicy.restoreAccessoryIfNoWindows(excluding: closingWindow)
        }
    }
}
