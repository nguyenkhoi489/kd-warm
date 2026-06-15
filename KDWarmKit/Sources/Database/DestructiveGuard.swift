import Foundation

/// A UX safety net over raw SQL the user runs in the editor: it flags statements that mutate broadly
/// (a keyless DELETE/UPDATE) or remove data/schema (DROP/TRUNCATE) so the UI can require an explicit
/// confirm before running them. It is deliberately a *net, not a trust boundary* — the real guard is
/// the server-side read-only session (a later phase) and the dialect's keyless-write refusal for
/// generated DML. The keyword scan is heuristic: a WHERE buried in a subquery of an otherwise keyless
/// outer DELETE reads as "scoped" here, which is an acceptable false-negative for a confirm prompt.
public enum DestructiveGuard {

    /// The result of scanning a SQL string. `reason` is a one-line, user-facing explanation when
    /// destructive, nil otherwise.
    public struct Verdict: Equatable {
        public let isDestructive: Bool
        public let reason: String?

        public init(isDestructive: Bool, reason: String?) {
            self.isDestructive = isDestructive
            self.reason = reason
        }
    }

    /// Scan a (possibly multi-statement) SQL string. If any statement is destructive, the whole batch
    /// is — the first such statement's reason is returned.
    public static func evaluate(_ sql: String) -> Verdict {
        for statement in statements(in: sql) {
            if let reason = reason(for: statement) {
                return Verdict(isDestructive: true, reason: reason)
            }
        }
        return Verdict(isDestructive: false, reason: nil)
    }

    /// Split on `;` into non-empty trimmed statements. Naive (a `;` inside a string literal would
    /// over-split), but only ever causes an extra confirm, never a missed one.
    private static func statements(in sql: String) -> [String] {
        sql.split(separator: ";").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func reason(for statement: String) -> String? {
        func matches(_ pattern: String) -> Bool {
            statement.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil
        }
        if matches(#"^\s*(DROP|TRUNCATE)\b"#) {
            return "DROP/TRUNCATE permanently removes data or schema objects."
        }
        let hasWhere = matches(#"\bWHERE\b"#)
        if matches(#"^\s*DELETE\b"#) && !hasWhere {
            return "DELETE without a WHERE clause removes every row in the table."
        }
        if matches(#"^\s*UPDATE\b"#) && !hasWhere {
            return "UPDATE without a WHERE clause changes every row in the table."
        }
        return nil
    }
}
