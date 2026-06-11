import XCTest
@testable import KDWarmKit

final class SiteConfigGeneratorTests: XCTestCase {
    private let fm = FileManager.default

    private func makePaths() -> (AppSupportPaths, URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-gen-\(UUID().uuidString)", isDirectory: true)
        let paths = AppSupportPaths(root: root)
        try? paths.ensureDirectoryTree()
        return (paths, root)
    }

    private func site(_ domain: String, type: SiteType, version: String = "8.4") -> Site {
        Site(name: domain, path: "/tmp/\(domain)", docroot: "/tmp/\(domain)/public",
             domain: domain, phpVersion: version, type: type)
    }

    func testPHPVhostRoutesToVersionSocketStaticDoesNot() {
        let (paths, root) = makePaths(); defer { try? fm.removeItem(at: root) }
        let gen = SiteConfigGenerator(paths: paths)

        let php = gen.vhostText(for: site("demo.test", type: .php, version: "8.4"), port: 80)
        XCTAssertTrue(php.contains("fastcgi_pass unix:\(paths.phpFpmSocket("8.4").path);"))
        XCTAssertTrue(php.contains("listen 0.0.0.0:80;"))

        let stat = gen.vhostText(for: site("html.test", type: .staticSite), port: 80)
        XCTAssertFalse(stat.contains("fastcgi_pass"))
        XCTAssertTrue(stat.contains("try_files $uri $uri/ =404;"))

        let node = gen.vhostText(for: site("node.test", type: .node), port: 80)
        XCTAssertFalse(node.contains("fastcgi_pass"))   // node not served through PHP-FPM
    }

    func testRequiredVersionsOnlyCountsPHPSites() {
        let sites = [site("a.test", type: .php, version: "8.4"),
                     site("b.test", type: .php, version: "8.1"),
                     site("c.test", type: .staticSite, version: "8.4")]
        XCTAssertEqual(SiteConfigGenerator.requiredVersions(for: sites), ["8.4", "8.1"])
    }

    func testGenerateWritesIdempotentlyAndRemovesOrphans() throws {
        let (paths, root) = makePaths(); defer { try? fm.removeItem(at: root) }
        let gen = SiteConfigGenerator(paths: paths)

        XCTAssertTrue(try gen.generate(sites: [site("demo.test", type: .php)]))      // first write: changed
        XCTAssertFalse(try gen.generate(sites: [site("demo.test", type: .php)]))     // identical: no change
        XCTAssertTrue(fm.fileExists(atPath: paths.vhost("demo.test").path))

        // Removing the site deletes its vhost (orphan cleanup).
        XCTAssertTrue(try gen.generate(sites: []))
        XCTAssertFalse(fm.fileExists(atPath: paths.vhost("demo.test").path))
    }

    func testSkippedSiteKeepsItsExistingVhost() throws {
        let (paths, root) = makePaths(); defer { try? fm.removeItem(at: root) }
        let gen = SiteConfigGenerator(paths: paths)
        // Write a valid static site, then regenerate with the same site but an UNSAFE docroot
        // (skipped this pass). Its existing vhost must NOT be swept as an orphan.
        var s = site("keep.test", type: .staticSite)
        _ = try gen.generate(sites: [s])
        XCTAssertTrue(fm.fileExists(atPath: paths.vhost("keep.test").path))

        s.docroot = "/tmp/bad;rm -rf"   // fails isSafePath → skipped
        _ = try gen.generate(sites: [s])
        XCTAssertTrue(fm.fileExists(atPath: paths.vhost("keep.test").path),
                      "a registered-but-skipped site must keep its prior vhost (not orphaned)")
    }
}

final class BundledPHPTests: XCTestCase {
    func testDefaultVersionMapsToUnversionedBinary() {
        let bin = URL(fileURLWithPath: "/tmp/bin")
        XCTAssertEqual(BundledPHP.fpmBinary(for: "8.4", in: bin).lastPathComponent, "php-fpm")
        XCTAssertEqual(BundledPHP.fpmBinary(for: "8.1", in: bin).lastPathComponent, "php-fpm-8.1")
    }

    func testAvailableVersionsReflectsBinariesOnDisk() throws {
        let bin = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-bin-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: bin) }
        // Only the unversioned php-fpm exists → only 8.4 available.
        let fpm = bin.appendingPathComponent("php-fpm")
        FileManager.default.createFile(atPath: fpm.path, contents: Data(),
                                       attributes: [.posixPermissions: 0o755])
        XCTAssertEqual(BundledPHP.availableVersions(in: bin), ["8.4"])
    }
}
