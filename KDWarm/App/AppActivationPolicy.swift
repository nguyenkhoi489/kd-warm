import AppKit

/// Centralizes the `.accessory`↔`.regular` activation dance a menu-bar app needs to
/// show a focusable window or the Settings scene. Opening a window while `.accessory`
/// yields a window that cannot take key focus; promoting to `.regular` (and dropping
/// back once windows close) is the standard workaround. Every window-opening path
/// routes through here so later phases inherit correct behavior.
enum AppActivationPolicy {
    /// Promote to a regular app so a window can take focus (briefly shows in the Dock).
    static func activateRegular() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Return to menu-bar-only accessory once no ordinary windows remain visible.
    /// `closingWindow` is excluded explicitly: on `willClose` the closing window is
    /// still present in `NSApp.windows` and may still report `isVisible == true`, so
    /// counting it would wrongly keep the app in `.regular` after the last window goes.
    static func restoreAccessoryIfNoWindows(excluding closingWindow: NSWindow? = nil) {
        let hasOrdinaryWindow = NSApp.windows.contains { window in
            window !== closingWindow
                && window.isVisible
                && window.canBecomeMain
                && !(window is NSPanel)
        }
        if !hasOrdinaryWindow {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
