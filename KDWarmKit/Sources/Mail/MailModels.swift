import Foundation

/// Mail models mirroring the Mailpit REST API (`/api/v1/...`). Decoded defensively — optional fields
/// tolerate API shape drift across Mailpit versions.

public struct MailAddress: Codable, Sendable, Hashable {
    public let Name: String
    public let Address: String
    /// "Name <addr>" when a display name exists, else the bare address.
    public var display: String { Name.isEmpty ? Address : "\(Name) <\(Address)>" }
}

/// One row in the message list (`GET /api/v1/messages`).
public struct MailSummary: Codable, Sendable, Identifiable, Hashable {
    public let ID: String
    public let Read: Bool
    public let From: MailAddress?
    public let To: [MailAddress]?
    public let Subject: String
    public let Created: String
    public let Snippet: String
    public let Attachments: Int

    public var id: String { self.ID }
    public var date: Date? { MailDateFormat.parse(Created) }
}

/// The list envelope.
public struct MailListResponse: Codable, Sendable {
    public let total: Int
    public let unread: Int
    public let messages: [MailSummary]
}

public struct MailAttachment: Codable, Sendable, Identifiable, Hashable {
    public let PartID: String
    public let FileName: String
    public let ContentType: String
    public let Size: Int
    public var id: String { PartID }
}

/// A full message (`GET /api/v1/message/{id}`).
public struct MailDetail: Codable, Sendable, Identifiable {
    public let ID: String
    public let From: MailAddress?
    public let To: [MailAddress]?
    public let Cc: [MailAddress]?
    public let Subject: String
    public let Date: String
    public let Text: String?
    public let HTML: String?
    public let Attachments: [MailAttachment]?

    public var id: String { self.ID }
    public var date: Date? { MailDateFormat.parse(Date) }
}

/// Mailpit timestamps are RFC3339 with fractional seconds + offset (e.g. 2026-06-11T21:24:34.473+07:00).
enum MailDateFormat {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]; return f
    }()
    private static let plain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter(); f.formatOptions = [.withInternetDateTime]; return f
    }()
    static func parse(_ s: String) -> Date? { withFraction.date(from: s) ?? plain.date(from: s) }
}
