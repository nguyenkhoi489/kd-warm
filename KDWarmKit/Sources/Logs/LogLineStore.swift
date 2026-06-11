import Foundation

/// Heuristic severity of a log line — drives the gutter color. Advisory only (formats vary), so an
/// unrecognized line defaults to `.info`.
public enum LogSeverity: String, Sendable, CaseIterable {
    case info, warning, error
}

/// One parsed log line. `id` is a monotonic sequence so SwiftUI can diff a virtualized list and the
/// ring buffer can evict the oldest without id reuse within a session.
public struct LogLine: Identifiable, Sendable, Hashable {
    public let id: Int
    public let text: String
    public let severity: LogSeverity
}

/// Bounded ring buffer of severity-tagged log lines + a text filter. Caps memory regardless of file
/// size (the tail reader feeds it incrementally); the oldest lines are evicted past `capacity`.
public final class LogLineStore: @unchecked Sendable {
    public let capacity: Int
    private let lock = NSLock()
    private var lines: [LogLine] = []
    private var nextID = 0

    public init(capacity: Int = 5_000) {
        self.capacity = capacity
        lines.reserveCapacity(capacity)
    }

    /// Append raw lines (parses severity, assigns ids, evicts overflow). Returns the new snapshot.
    @discardableResult
    public func append(_ raw: [String]) -> [LogLine] {
        lock.lock(); defer { lock.unlock() }
        for text in raw {
            lines.append(LogLine(id: nextID, text: text, severity: Self.severity(of: text)))
            nextID += 1
        }
        if lines.count > capacity { lines.removeFirst(lines.count - capacity) }
        return lines
    }

    public func clear() {
        lock.lock(); lines.removeAll(keepingCapacity: true); lock.unlock()
    }

    public func snapshot() -> [LogLine] {
        lock.lock(); defer { lock.unlock() }
        return lines
    }

    /// Lines matching a case-insensitive substring filter (empty = all).
    public func filtered(_ query: String) -> [LogLine] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let all = snapshot()
        guard !q.isEmpty else { return all }
        return all.filter { $0.text.range(of: q, options: .caseInsensitive) != nil }
    }

    /// Classify a line: error keywords win over warn; otherwise info. Matches nginx/php-fpm/db shapes.
    static func severity(of line: String) -> LogSeverity {
        let l = line.lowercased()
        if l.contains("[error]") || l.contains("[emerg]") || l.contains("[crit]") || l.contains("[alert]")
            || l.contains("fatal") || l.contains("error:") || l.contains(" error ") || l.contains("[error:") {
            return .error
        }
        if l.contains("[warn]") || l.contains("warning") || l.contains("[notice]") && l.contains("fail") {
            return .warning
        }
        return .info
    }
}
