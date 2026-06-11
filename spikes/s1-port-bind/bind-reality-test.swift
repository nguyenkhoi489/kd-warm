// S1 — Port-bind reality test (run: `swift bind-reality-test.swift`).
//
// Proves the load-bearing kernel behavior the whole proxy design assumes: a non-root
// user can bind the privileged ports on 0.0.0.0, but binding the SAME privileged port
// on a SPECIFIC interface (127.0.0.1) fails EACCES. If true, every nginx vhost MUST
// emit `listen 0.0.0.0:…` and MUST NEVER emit a loopback `listen 127.0.0.1:80`.
//
// Robust to a co-resident server (e.g. an existing Herd install) holding 80/443: an
// EADDRINUSE on 0.0.0.0 still proves there is no *permission* barrier there, which is
// the fact under test. The authoritative signal is the 127.0.0.1 privileged-port EACCES.

import Darwin
import Foundation

let EACCES_VAL: Int32 = 13      // permission denied — the trap we must avoid
let EADDRINUSE_VAL: Int32 = 48  // already bound by another process (acceptable here)

struct BindOutcome {
    let addr: String
    let port: UInt16
    let rc: Int32
    let err: Int32
    var isEACCES: Bool { rc != 0 && err == EACCES_VAL }
    var isInUse: Bool { rc != 0 && err == EADDRINUSE_VAL }
    var ok: Bool { rc == 0 }
    var note: String {
        if ok { return "bind OK" }
        if isEACCES { return "EACCES (permission denied)" }
        if isInUse { return "EADDRINUSE (port held by another process)" }
        return "errno \(err) (\(String(cString: strerror(err))))"
    }
}

func tryBind(_ addrStr: String, _ port: UInt16) -> BindOutcome {
    let fd = socket(AF_INET, SOCK_STREAM, 0)
    if fd < 0 { return BindOutcome(addr: addrStr, port: port, rc: -1, err: errno) }
    defer { close(fd) }
    var yes: Int32 = 1
    setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))

    var sin = sockaddr_in()
    sin.sin_family = sa_family_t(AF_INET)
    sin.sin_port = port.bigEndian
    sin.sin_addr.s_addr = inet_addr(addrStr)
    let size = socklen_t(MemoryLayout<sockaddr_in>.size)
    let rc = withUnsafePointer(to: &sin) { p in
        p.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(fd, $0, size) }
    }
    return BindOutcome(addr: addrStr, port: port, rc: rc, err: rc == 0 ? 0 : errno)
}

// --- Run the matrix ---------------------------------------------------------
let privilegedPorts: [UInt16] = [80, 443]
var outcomes: [BindOutcome] = []
for port in privilegedPorts {
    outcomes.append(tryBind("0.0.0.0", port))
    outcomes.append(tryBind("127.0.0.1", port))
}
// Sanity: loopback on a high (non-privileged) port must always be fine.
let highLoopback = tryBind("127.0.0.1", 8080)
outcomes.append(highLoopback)

print("S1 — Port-bind reality  (uid \(getuid()), \(getuid() == 0 ? "ROOT — invalid test" : "non-root"))")
print(String(repeating: "-", count: 58))
for o in outcomes {
    print(String(format: "  %-12s : %-5d -> %@", (o.addr as NSString).utf8String!, Int(o.port), o.note))
}
print(String(repeating: "-", count: 58))

// --- Gate assertions --------------------------------------------------------
var failures: [String] = []

// (1) Loopback privileged ports MUST be EACCES — this is the trap we encode against.
for port in privilegedPorts {
    let loop = outcomes.first { $0.addr == "127.0.0.1" && $0.port == port }!
    if !loop.isEACCES {
        failures.append("127.0.0.1:\(port) expected EACCES, got: \(loop.note)")
    }
}
// (2) 0.0.0.0 privileged ports MUST NOT be a permission failure (OK or EADDRINUSE ok).
for port in privilegedPorts {
    let any = outcomes.first { $0.addr == "0.0.0.0" && $0.port == port }!
    if any.isEACCES {
        failures.append("0.0.0.0:\(port) returned EACCES — non-root cannot bind privileged port even on 0.0.0.0; launchd socket-handoff fallback becomes mandatory")
    }
}
// (3) Sanity: high-port loopback must bind.
if !(highLoopback.ok || highLoopback.isInUse) {
    failures.append("127.0.0.1:8080 sanity bind failed: \(highLoopback.note)")
}

if failures.isEmpty {
    print("RESULT: PASS — 0.0.0.0 privileged bind has no permission barrier; 127.0.0.1 privileged bind is EACCES.")
    print("        => nginx vhosts must `listen 0.0.0.0:…`, never a loopback privileged listen.")
    exit(0)
} else {
    print("RESULT: FAIL")
    for f in failures { print("  - \(f)") }
    exit(1)
}
