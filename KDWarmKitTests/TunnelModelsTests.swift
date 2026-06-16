import XCTest
@testable import KDWarmKit

final class TunnelModelsTests: XCTestCase {
    func testParsesURLFromCloudflaredBannerBox() {
        let banner = """
        2026-06-16T05:34:38Z INF +-----------------------------------------------+
        2026-06-16T05:34:38Z INF |  Your quick Tunnel has been created! Visit it  |
        2026-06-16T05:34:38Z INF |  https://settlement-outdoor-ruth-hill.trycloudflare.com   |
        2026-06-16T05:34:38Z INF +-----------------------------------------------+
        """
        XCTAssertEqual(TrycloudflareURL.first(in: banner)?.absoluteString,
                       "https://settlement-outdoor-ruth-hill.trycloudflare.com")
    }

    func testPartialBufferYieldsNilUntilURLComplete() {
        let partial = "2026 INF |  https://settlement-outdoor-ruth"
        XCTAssertNil(TrycloudflareURL.first(in: partial))
        let complete = partial + "-hill.trycloudflare.com  |"
        XCTAssertEqual(TrycloudflareURL.first(in: complete)?.host, "settlement-outdoor-ruth-hill.trycloudflare.com")
    }

    func testArgumentsUseDedicatedLoopbackOrigin() {
        let args = TunnelOrigin.cloudflaredArguments(port: 45123)
        XCTAssertEqual(args, ["tunnel", "--url", "http://127.0.0.1:45123", "--no-autoupdate"])
        XCTAssertFalse(args.contains("--no-tls-verify"))
    }

    func testArgumentsDoNotOverridePublicHostHeader() {
        let args = TunnelOrigin.cloudflaredArguments(port: 45123)
        XCTAssertFalse(args.contains("--http-host-header"))
        XCTAssertFalse(args.contains("secure.test"))
    }

    func testStatusPublicURLAndBusy() {
        let url = URL(string: "https://x.trycloudflare.com")!
        XCTAssertEqual(TunnelStatus.active(url).publicURL, url)
        XCTAssertNil(TunnelStatus.starting.publicURL)
        XCTAssertTrue(TunnelStatus.starting.isBusy)
        XCTAssertTrue(TunnelStatus.active(url).isBusy)
        XCTAssertFalse(TunnelStatus.idle.isBusy)
        XCTAssertFalse(TunnelStatus.error("x").isBusy)
    }
}
