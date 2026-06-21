import Foundation

public struct LaravelSiteProbe: Sendable {
    public init() {}

    public func isLaravel(siteAt folder: URL, fileManager: FileManager = .default) -> Bool {
        fileManager.fileExists(atPath: folder.appendingPathComponent("artisan").path)
    }
}
