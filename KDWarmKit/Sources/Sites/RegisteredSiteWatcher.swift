import Foundation

/// Watches each REGISTERED site folder for changes and fires a debounced callback so the site
/// can be re-inspected (docroot/index/type may have shifted). It does NOT scan `~/Sites/WWW` for
/// NEW folders — sites enter the registry only via explicit "Add Site".
///
/// Implementation: a per-folder `DispatchSource` vnode watch (write/rename/delete on the folder
/// inode) with a debounce. This covers the top-level markers inspection relies on (`public/`,
/// `index.php`, `package.json`); FSEvents-style recursion isn't needed for type detection.
public final class RegisteredSiteWatcher: @unchecked Sendable {
    private final class Watch {
        let source: DispatchSourceFileSystemObject
        let fd: Int32
        var pending: DispatchWorkItem?
        init(source: DispatchSourceFileSystemObject, fd: Int32) { self.source = source; self.fd = fd }
    }

    private let debounce: TimeInterval
    private let queue = DispatchQueue(label: "com.kdwarm.site-watcher")
    private var watches: [String: Watch] = [:]   // keyed by folder path

    /// Called (debounced) with the folder URL whose contents changed.
    public var onChange: (@Sendable (URL) -> Void)?

    public init(debounce: TimeInterval = 0.5) {
        self.debounce = debounce
    }

    /// Re-arm the watch set to exactly `folders`: drop watches no longer wanted, add new ones.
    public func watch(_ folders: [URL]) {
        queue.sync {
            let wanted = Set(folders.map(\.path))
            for (path, w) in watches where !wanted.contains(path) {
                w.source.cancel(); watches[path] = nil
            }
            for folder in folders where watches[folder.path] == nil {
                arm(folder)
            }
        }
    }

    public func stop() {
        queue.sync {
            for (_, w) in watches { w.source.cancel() }
            watches.removeAll()
        }
    }

    deinit { stop() }

    // Must be called on `queue`.
    private func arm(_ folder: URL) {
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: queue)
        let watch = Watch(source: source, fd: fd)
        source.setEventHandler { [weak self] in self?.scheduleCallback(folder) }
        source.setCancelHandler { close(fd) }
        watches[folder.path] = watch
        source.resume()
    }

    // On `queue`: debounce per folder, then fire on a background queue.
    private func scheduleCallback(_ folder: URL) {
        guard let watch = watches[folder.path] else { return }
        watch.pending?.cancel()
        let item = DispatchWorkItem { [weak self] in self?.onChange?(folder) }
        watch.pending = item
        queue.asyncAfter(deadline: .now() + debounce, execute: item)
    }
}
