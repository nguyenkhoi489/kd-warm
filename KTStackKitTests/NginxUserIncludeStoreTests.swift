import XCTest
@testable import KTStackKit

final class NginxUserIncludeStoreTests: XCTestCase {
    private var root: URL!
    private var paths: AppSupportPaths!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ktstack-nginx-extra-\(UUID().uuidString)")
        paths = AppSupportPaths(root: root)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - A1.1 Path tests

    func testNginxUserConfPathIsInsideNginxConfigDir() {
        XCTAssertEqual(paths.nginxUserConf.lastPathComponent, "nginx-extra.conf")
        XCTAssertTrue(paths.nginxUserConf.path.hasPrefix(paths.nginxConfigDir.path))
    }

    func testNginxUserConfIsNotUnderSitesEnabled() {
        XCTAssertFalse(paths.nginxUserConf.path.hasPrefix(paths.sitesEnabled.path))
    }

    // MARK: - A1.2 Template test

    func testNginxUserIncludeTemplateIsAllCommentsAndContainsMarker() {
        let template = NginxUserIncludeTemplate.default
        let lines = template.components(separatedBy: "\n")
        for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            XCTAssertTrue(
                line.trimmingCharacters(in: .whitespaces).hasPrefix("#"),
                "Expected comment line but got: \(line)"
            )
        }
        XCTAssertTrue(template.contains("# KTStack"), "Template must contain '# KTStack' marker")
    }
}
