import Foundation

// Minimal privileged-helper stub. Phase 1 performs no privileged work; it only stands
// up an idle Mach-service listener that rejects every connection, so the target builds
// and ships in the app's Contents/MacOS layout. Phase 4 wires SMAppService registration
// and the signature-validated XPC surface (DNS / /etc/resolver / Keychain-CA), at which
// point the shared HelperXPCProtocol from KDWarmKit becomes the exported interface.

final class HelperListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener,
                  shouldAcceptNewConnection connection: NSXPCConnection) -> Bool {
        // No exported interface and no client-signature validation yet — reject all.
        return false
    }
}

let delegate = HelperListenerDelegate()
let listener = NSXPCListener(machServiceName: "com.kdwarm.helper")
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
