import Foundation

/// Thin async REST client for Mailpit (`/api/v1`). Loopback-only (the bundled Mailpit binds
/// 127.0.0.1), so no auth. Used by the Mail view to list/read/delete caught messages.
public struct MailpitClient: Sendable {
    public struct APIError: LocalizedError {
        public let status: Int
        public var errorDescription: String? { "Mailpit API returned HTTP \(status)." }
    }

    private let baseURL: URL
    private let session: URLSession

    public init(baseURL: URL = MailpitController.apiBaseURL) {
        self.baseURL = baseURL
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 5
        self.session = URLSession(configuration: cfg)
    }

    /// Newest messages first (Mailpit returns them in reverse-chronological order).
    public func list(limit: Int = 200) async throws -> MailListResponse {
        try await get("/messages?limit=\(limit)")
    }

    public func detail(id: String) async throws -> MailDetail {
        try await get("/message/\(id)")
    }

    /// Raw RFC822 source URL (opened in the browser / "view raw").
    public func rawURL(id: String) -> URL { baseURL.appendingPathComponent("message/\(id)/raw") }

    /// Delete specific messages (empty = delete all — Mailpit's documented semantics).
    public func delete(ids: [String]) async throws {
        var req = URLRequest(url: baseURL.appendingPathComponent("messages"))
        req.httpMethod = "DELETE"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["IDs": ids])
        _ = try await send(req)
    }

    public func deleteAll() async throws { try await delete(ids: []) }

    // MARK: - Private

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let data = try await send(URLRequest(url: url(path)))
        return try JSONDecoder().decode(T.self, from: data)
    }

    @discardableResult
    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw APIError(status: http.statusCode)
        }
        return data
    }

    /// Build a URL for an API path that may include a query string (which `appendingPathComponent` escapes).
    private func url(_ path: String) -> URL {
        URL(string: baseURL.absoluteString + path) ?? baseURL
    }
}
