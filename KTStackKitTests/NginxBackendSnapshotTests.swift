import XCTest
@testable import KTStackKit

final class NginxBackendSnapshotTests: XCTestCase {
    private let backend = NginxBackend()
    private let writer = NginxConfigWriter()
    private let tls = NginxTLSVhostWriter()
    private let paths = AppSupportPaths(root: URL(fileURLWithPath: "/tmp/ktstack-test"))

    private func context(
        site: Site,
        socket: URL?,
        nodeProxyPort: Int?,
        cert: Bool
    ) -> BackendRenderContext {
        BackendRenderContext(
            site: site,
            root: URL(fileURLWithPath: site.docroot),
            phpFpmSocket: socket,
            nodeProxyPort: nodeProxyPort,
            certFile: cert ? paths.siteCert(site.domain) : nil,
            keyFile: cert ? paths.siteKey(site.domain) : nil,
            accessLog: paths.siteAccessLog(site.domain),
            errorLog: paths.siteErrorLog(site.domain),
            port: 80
        )
    }

    func testPHPVhostMatchesWriter() {
        let site = Site(name: "demo", path: "/s", docroot: "/s/public", domain: "demo.test", phpVersion: "8.4", type: .php)
        let socket = paths.phpFpmSocket("8.4")
        let expected = writer.vhost(
            domain: "demo.test",
            root: URL(fileURLWithPath: "/s/public"),
            phpFpmSocket: socket,
            port: 80,
            accessLog: paths.siteAccessLog("demo.test"),
            errorLog: paths.siteErrorLog("demo.test")
        )
        XCTAssertEqual(backend.siteConfig(context: context(site: site, socket: socket, nodeProxyPort: nil, cert: false)), expected)
    }

    func testSecurePHPVhostMatchesTLSWriter() {
        let site = Site(name: "demo", path: "/s", docroot: "/s/public", domain: "demo.test", phpVersion: "8.4", type: .php, secure: true)
        let socket = paths.phpFpmSocket("8.4")
        let expected = tls.redirectVhost(domain: "demo.test") + "\n\n"
            + tls.secureVhost(
                domain: "demo.test",
                root: URL(fileURLWithPath: "/s/public"),
                certFile: paths.siteCert("demo.test"),
                keyFile: paths.siteKey("demo.test"),
                phpFpmSocket: socket,
                nodeProxyPort: nil,
                accessLog: paths.siteAccessLog("demo.test"),
                errorLog: paths.siteErrorLog("demo.test")
            )
        XCTAssertEqual(backend.siteConfig(context: context(site: site, socket: socket, nodeProxyPort: nil, cert: true)), expected)
    }

    func testNodeProxyVhostMatchesWriter() {
        let site = Site(name: "app", path: "/a", docroot: "/a", domain: "app.test", phpVersion: "8.4", type: .node, nodePort: 3001)
        let expected = writer.vhostNodeProxy(
            domain: "app.test",
            nodePort: 3001,
            port: 80,
            accessLog: paths.siteAccessLog("app.test"),
            errorLog: paths.siteErrorLog("app.test")
        )
        XCTAssertEqual(backend.siteConfig(context: context(site: site, socket: nil, nodeProxyPort: 3001, cert: false)), expected)
    }

    func testStaticVhostMatchesWriter() {
        let site = Site(name: "doc", path: "/d", docroot: "/d/public", domain: "doc.test", phpVersion: "8.4", type: .staticSite)
        let expected = writer.vhostStatic(
            domain: "doc.test",
            root: URL(fileURLWithPath: "/d/public"),
            port: 80,
            accessLog: paths.siteAccessLog("doc.test"),
            errorLog: paths.siteErrorLog("doc.test")
        )
        XCTAssertEqual(backend.siteConfig(context: context(site: site, socket: nil, nodeProxyPort: nil, cert: false)), expected)
    }

    func testFactoryReturnsNginxForNginxEngine() {
        XCTAssertEqual(WebServerBackendFactory.backend(for: .nginx).engine, .nginx)
    }
}
