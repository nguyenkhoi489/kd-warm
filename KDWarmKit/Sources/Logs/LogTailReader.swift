import Foundation

/// Incrementally tails a log file: backfills the last slice on open, then emits appended lines as the
/// file grows (a `DispatchSource` vnode watch on the fd), and transparently reopens on rotation
/// (rename/delete) or truncation. Never loads the whole file — backfill is capped to a tail window —
/// so a 10k+ line log stays cheap.
public final class LogTailReader: @unchecked Sendable {
    /// Emitted on the reader's private queue. Backfill arrives first (one batch), then live appends.
    public var onLines: (@Sendable ([String]) -> Void)?

    private let url: URL
    private let backfillBytes: Int
    private let queue = DispatchQueue(label: "com.kdwarm.logtail")
    private var handle: FileHandle?
    private var source: DispatchSourceFileSystemObject?
    private var offset: UInt64 = 0
    private var partial = ""
    private var reopenTimer: DispatchSourceTimer?

    public init(url: URL, backfillBytes: Int = 256 * 1024) {
        self.url = url
        self.backfillBytes = backfillBytes
    }

    public func start() { queue.async { [weak self] in self?.open() } }

    public func stop() {
        queue.async { [weak self] in self?.teardown() }
    }

    // MARK: - Private (all on `queue`)

    private func open() {
        teardown()
        // Open the fd manually so a SINGLE owner (the dispatch source's cancel handler) closes it.
        // A `FileHandle(forReadingFrom:)` would also close on dealloc → double-close of the same fd.
        let fd = Darwin.open(url.path, O_RDONLY)
        guard fd >= 0 else {
            scheduleReopen()               // file not created yet (service not started) — poll for it
            return
        }
        let fh = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
        handle = fh
        let size = (try? fh.seekToEnd()) ?? 0
        // Backfill: read only the tail window, drop the leading partial line for alignment.
        let start = size > UInt64(backfillBytes) ? size - UInt64(backfillBytes) : 0
        try? fh.seek(toOffset: start)
        let data = (try? fh.readToEnd()) ?? Data()
        offset = (try? fh.offset()) ?? size
        var text = String(decoding: data, as: UTF8.self)
        if start > 0, let nl = text.firstIndex(of: "\n") { text = String(text[text.index(after: nl)...]) }
        emit(text, isBackfill: true)
        beginMonitoring(fd: fd)            // cancel handler is the sole closer of this fd
    }

    private func beginMonitoring(fd: Int32) {
        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .extend, .delete, .rename, .link], queue: queue)
        src.setEventHandler { [weak self] in self?.handleEvent(src.data) }
        src.setCancelHandler { close(fd) }
        source = src
        src.resume()
    }

    private func handleEvent(_ mask: DispatchSource.FileSystemEvent) {
        if mask.contains(.delete) || mask.contains(.rename) || mask.contains(.link) {
            open()                          // rotated/replaced → reattach to the new file from its start
            return
        }
        guard let fh = handle else { return }
        let size = (try? fh.seekToEnd()) ?? 0
        if size < offset { offset = 0 }     // truncated in place
        try? fh.seek(toOffset: offset)
        let data = (try? fh.readToEnd()) ?? Data()
        offset = (try? fh.offset()) ?? offset
        emit(String(decoding: data, as: UTF8.self), isBackfill: false)
    }

    /// Split into complete lines, carrying any trailing partial line to the next read.
    private func emit(_ chunk: String, isBackfill: Bool) {
        guard !chunk.isEmpty else { return }
        let combined = partial + chunk
        var lines = combined.components(separatedBy: "\n")
        partial = lines.removeLast()        // last element is the (possibly empty) trailing partial
        let complete = lines.filter { !$0.isEmpty }
        guard !complete.isEmpty else { return }
        onLines?(complete)
    }

    private func scheduleReopen() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 1.0)
        t.setEventHandler { [weak self] in self?.reopenTimer = nil; self?.open() }
        reopenTimer = t
        t.resume()
    }

    private func teardown() {
        reopenTimer?.cancel(); reopenTimer = nil
        source?.cancel(); source = nil      // cancel handler closes the fd
        handle = nil
        offset = 0; partial = ""
    }
}
